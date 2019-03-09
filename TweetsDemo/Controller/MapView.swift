//
//  MapView.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit
import MapKit

enum FilterType {
	case noFilter
	case keyword
	case hashtag
}
final class MapView: UIView {
	
	//MARK: Properties
	var curLocation: MKUserLocation {
		return self.mapView.userLocation
	}
	private(set) var mapView =  MKMapView()
	weak var  delegate: MKMapViewDelegate? = nil

	convenience init(delegate: MKMapViewDelegate) {
		self.init()
		self.delegate  = delegate
		initializeUI()
		createConstraints()
		self.mapView.showsUserLocation = true
		self.mapView.userTrackingMode = .followWithHeading
		
	}
	
	// MARK: UI
	
	func initializeUI() {
		self.addSubview(mapView)
		mapView.delegate = self.delegate
	}
	
	func createConstraints() {
		self.mapView.anchorEdgesToView(self)
	}
	
	@objc func didPressPin() {
		
	}
	
	func addAnnotations(annotations: [MKAnnotation]) {
		mapView.addAnnotations(annotations)
	}
	
	func removeAnnotation(annotations: [MKAnnotation]) {
		mapView.removeAnnotations(annotations)
	}
	
	func setRegion(location: CLLocationCoordinate2D) {
		let regionRadius: CLLocationDistance = Double(MapRegionRadius)
		let coordinateRegion = MKCoordinateRegion(center: location,
			latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
		mapView.setRegion(coordinateRegion, animated: true)
	}

	func getUserLocation() -> CLLocationCoordinate2D? {
		return mapView.userLocation.location?.coordinate
	}
	
	func filterAnnotations(by: String, as type: FilterType) {
		let all = self.mapView.annotations

		if case .keyword = type {
			for each in all {
				if let annot = each as? MapTweetAnnotation {
					self.mapView.view(for: each)?.isHidden = !(annot.tweet.text ?? "").contains(by)
				}
			}
		} else {
			for each in all {
				if let annot = each as? MapTweetAnnotation {
					self.mapView.view(for: each)?.isHidden = !annot.tweet.hashtags.contains(by)
				}
			}
		}
	}
	
	func filterAnnotation(annotation: MKAnnotation, by: String, as type: FilterType) {
		if case .keyword = type {
			if let annot = annotation as? MapTweetAnnotation {
				self.mapView.view(for: annotation)?.isHidden = !(annot.tweet.text ?? "").contains(by)
			}
		} else {
			if let annot = annotation as? MapTweetAnnotation {
				self.mapView.view(for: annotation)?.isHidden = !annot.tweet.hashtags.contains(by)
			}
		}
	}
	func clearFilter() {
		let all = self.mapView.annotations
		for each in all {
			self.mapView.view(for: each)?.isHidden = false
		}
	}
}
