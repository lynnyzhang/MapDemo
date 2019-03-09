//
//  ViewController.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

let MapRegionRadius: Int = 20000
class MapViewController: UIViewController {

	fileprivate var mapView: MapView?
	fileprivate var mapManager: MapManager?

	fileprivate var segmentControl: UISegmentedControl?
	// MARK: - View Lifecycle
	fileprivate var label: UILabel?
	override func loadView() {
		self.mapView = MapView(delegate: self)
		view = self.mapView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if let mapView = self.mapView {
			self.mapManager = MapManager(mapView: mapView)
		}
		self.mapManager?.startUpdatingLocationManager()
		
		let items: [String] = ["No Filter", "Keyword", "Hashtag"]
		let searchSC:UISegmentedControl = UISegmentedControl(items: items)
		searchSC.selectedSegmentIndex = 0
		searchSC.backgroundColor = UIColor(white: 1, alpha: 1)
		searchSC.layer.cornerRadius = 1.0
		self.navigationItem.titleView = searchSC
		self.segmentControl = searchSC
		searchSC.addTarget(self, action: #selector(segmentControlChanged), for: .valueChanged)
		
		let label = UILabel()
		self.view.addSubview(label)
		label.anchorToView(self.view, anchors: [.top, .left, .right], insets: [AnchorItem.top.rawValue: 100.0, AnchorItem.left.rawValue:0, AnchorItem.right.rawValue:0.0])
		label.setHeightConstraint(40.0)
		label.textAlignment = .center
		label.textColor = .black
		self.label = label
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	    self.mapManager?.KeepPollingTweets()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.mapManager?.stopPolling()
	}
	
	private func clearFilter() {
		self.label?.text = ""
		self.label?.isHidden = true
		self.mapManager?.clearFilter()
	}
	
	@objc func segmentControlChanged(){
		if self.segmentControl?.selectedSegmentIndex == 0 {
			self.clearFilter()
		} else if self.segmentControl?.selectedSegmentIndex == 1 {
			self.filter(.keyword)
		} else {
			self.filter(.hashtag)
		}
	}
	
	private func filter(_ type: FilterType) {
		var title = "Keyword"
		if case .hashtag = type {
			title = "Hashtag"
		}
		let alert = UIAlertController(title: title, message: nil, preferredStyle: UIAlertController.Style.alert)
		let action = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { [weak self] action in
			guard let self = self else { return }
			self.label?.isHidden = false
			let key = alert.textFields?[0].text
			if let key = key, key.count > 0 {
				self.label?.text = "\(title): \(key)"
				self.mapManager?.applyFilter(of: key, as: type)
			}
		}
		
		alert.addAction(action)
		alert.addTextField(configurationHandler: {(textField) in
			textField.placeholder = "Enter text:"
		})
		self.present(alert, animated: true, completion: nil)
	}

}
extension MapViewController: MKMapViewDelegate {

	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		guard annotation is MapTweetAnnotation else { return nil }
		
		let reuseId = "annotationPoint"
		let annotationPointView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) ?? MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
		annotationPointView.canShowCallout = true
		annotationPointView.annotation = annotation
		
		annotationPointView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
		return annotationPointView
	}
	
	func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		guard let annotation = view.annotation as? MapTweetAnnotation  else {
			return
		}
		
		let viewController = WebViewController(embedded: annotation.tweet.embeddedHtml, tweetId: annotation.tweet.id_str)
		self.navigationController?.pushViewController(viewController, animated: true)
		
	}
}

