//
//  TweetPost.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import Foundation
import CoreLocation
import ObjectiveC.NSObjCRuntime

class TweetPost : NSObject {
	var id_str : String?
	var text: String?
	var created_at: Date?
	var user: User?
	var place: Place?
	var coordinates: Coordinates?
	var hashtags: [String] = [String]()
	var embeddedHtml: String?
	
	override init() {
		super.init()
	}
	init(json: Any) {
		super.init()
		if let dict = json as? Dictionary<String,Any> {
			//This could be done with objc runtime property list generically for all object models
			for (key, value) in dict {
				let keyName = key as String
				if keyName == "user", let userDict = value as? Dictionary<String, Any> {
					self.user = User(dict: userDict)
				} else if keyName == "created_at", let stringValue = value as? String {
					let formatter = DateFormatter()
					formatter.locale = Locale.current
					formatter.timeZone = TimeZone(abbreviation: "UTC")
					formatter.dateFormat = "EEE MMM dd HH:mm:ss zzz yyyy"
					self.created_at = formatter.date(from: stringValue) ?? Date()
				} else if keyName == "place", let placeDict = value as? Dictionary<String, Any> {
					self.place = Place(dict: placeDict)
				} else if keyName == "coordinates",  let coordiantesDict = value as? [String:Any] {
					self.coordinates = Coordinates(dict: coordiantesDict)
				} else if keyName == "text" {
					let keyValue: String? = value as? String
					self.text = keyValue
				} else if keyName == "id_str" {
					let keyValue: String? = value as? String
					self.id_str = keyValue
				} else if keyName == "entities" {
					if let keyValue = value as? [String : Any], let hashtags = keyValue["hashtags"] as? [[String:Any]]{
						self.hashtags = hashtags.map({$0["text"] as? String}).compactMap{$0}
					}
				}
			}
		}
	}
	
	func getCoordinates() -> CLLocationCoordinate2D? {
		if self.coordinates != nil {
			return self.coordinates?.coordinates
		} else {
			return self.place?.bounding_box?.coordinates
		}
	}
}

class User : NSObject {
	var id_str : String?
	var screen_name: String?
	
	override init() {
		super.init()
	}
	init(dict: [String: Any]) {
		super.init()
		for (key, value) in dict {
			let keyName = key as String
			if keyName == "id_str" {
				let keyValue: String? = value as? String
				self.id_str = keyValue
			} else if keyName == "screen_name" {
				let keyValue: String? = value as? String
				self.screen_name = keyValue
			}
		}
	}
}

class Place: NSObject {
	var  bounding_box : BoundingBox?
	override init() {
		super.init()
	}
	init(dict: [String: Any]) {
		super.init()
		for (key, value) in dict {
			let keyName = key as String
			if keyName == "bounding_box" {
				if let keyValue = value as? [String: Any] {
					self.bounding_box = BoundingBox(dict: keyValue)
				}
			}
		}
	}
}

class BoundingBox: NSObject {
	var  coordinates : CLLocationCoordinate2D?
	override init() {
		super.init()
	}
	init(dict: [String: Any]) {
		super.init()
		for (key, value) in dict {
			let keyName = key as String
			if keyName == "coordinates" {
				if let keyValue = value as? [[[Double]]], keyValue.count > 0, keyValue[0].count > 0, keyValue[0][0].count > 1 {
					//TODO: taking shortcut here, should get the center of the four coordinates. will change it if I have time.
					self.coordinates = CLLocationCoordinate2DMake(keyValue[0][0][1], keyValue[0][0][0])
				}
			}
		}
	}
}

class Coordinates: NSObject {
	var  coordinates : CLLocationCoordinate2D?
	override init() {
		super.init()
	}
	init(dict: [String: Any]) {
		super.init()
		for (key, value) in dict {
			let keyName = key as String
			if keyName == "coordinates" {
				if let keyValue = value as? [Double], keyValue.count > 1 {
					self.coordinates = CLLocationCoordinate2DMake(keyValue[1], keyValue[0])
				}
			}
		}
	}
}
