//
//  MapManager.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/7/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit
import CoreLocation

let serialQueue = DispatchQueue(label: "com.tweetdemo.queue", qos: .utility)
class MapManager : NSObject {
	fileprivate weak var mapView: MapView?
	fileprivate var queue = Queue<MapTweetAnnotation>()
	fileprivate let locationManager = CLLocationManager()
	fileprivate var timer: Timer? = nil
	fileprivate var lastLocation : CLLocationCoordinate2D? = nil
	fileprivate var keyforFilter : String? = nil
	fileprivate var filterApplied: FilterType = .noFilter
	init(mapView: MapView) {
		self.mapView = mapView
		super.init()
		locationManager.delegate = self
	}
	
	func KeepPollingTweets() {
		if timer == nil {
			timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(pollingTweets), userInfo: nil, repeats: true)
		}
	}
	
	@objc func pollingTweets() {
		if let location = self.lastLocation {
			serialQueue.async { [weak self] in
				guard let self = self else { return }
				let ret = TwitterAPI.searchNearBy(geoLocation: location.toString())
				if ret.error == nil {
					let tweets = ret.result.filter{ $0.getCoordinates() != nil }
					for tweet in tweets {
						if let id_str = tweet.id_str, id_str.count > 0 {
							let ret = TwitterAPI.getEmbeddedHtmlString(id_str: id_str)
							if ret.result != nil {
								tweet.embeddedHtml = ret.result
							}
						}
					}
					let curTweets = self.queue.list.map({ $0.tweet })
					let curTweetIds = curTweets.map { return $0.id_str }
					let newTweets = tweets.filter { !curTweetIds.contains($0.id_str) && $0.getCoordinates() != nil }
					let newAnnotations = newTweets.map({ return MapTweetAnnotation(tweet: $0)})
					var annotsToRemove = [MapTweetAnnotation] ()
					for each in newAnnotations {
						if let dequeued = self.queue.enqueue(each) {
							annotsToRemove.append(dequeued)
						}
					}
					DispatchQueue.main.async {
						self.mapView?.addAnnotations(annotations: newAnnotations)
						self.mapView?.removeAnnotation(annotations: annotsToRemove)
						for each in newAnnotations {
							if let key = self.keyforFilter {
								self.mapView?.filterAnnotation(annotation: each, by: key, as: self.filterApplied)
							}
						}
					}
				}
			}
		}
		locationManager.startUpdatingLocation()
	}
	
	func startUpdatingLocationManager() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		locationManager.distanceFilter = 200
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
	func stopPolling() {
		if timer != nil {
			timer?.invalidate()
			self.timer = nil
		}
	}
	
	func applyFilter(of: String, as type: FilterType) {
		self.keyforFilter = of
		self.filterApplied = type
		self.mapView?.clearFilter()
		self.mapView?.filterAnnotations(by: of, as: type)
	}
	
	func clearFilter() {
		self.keyforFilter = nil
		self.filterApplied = .noFilter
		self.mapView?.clearFilter()
	}
}
  
extension MapManager: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let lastLocation = locations.last {
			if CLLocationCoordinate2DIsValid(lastLocation.coordinate) {
				locationManager.stopUpdatingLocation()
				self.mapView?.setRegion(location: lastLocation.coordinate)
				let previousLocation = self.lastLocation
				self.lastLocation = lastLocation.coordinate
				if previousLocation == nil {
					pollingTweets()
				}
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		locationManager.stopUpdatingLocation()
	}
}

extension CLLocationCoordinate2D {
	func toString() -> String {
		return "\(self.latitude),\(self.longitude)"
	}
}
