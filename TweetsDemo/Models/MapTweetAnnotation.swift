//
//  MKTweetAnnotation.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/7/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit
import MapKit

class MapTweetAnnotation: MKPointAnnotation {
	
	let tweet: TweetPost

	init(tweet: TweetPost) {
		self.tweet = tweet
		super.init()
		self.title = "@\(tweet.user?.screen_name ?? "Anonymous")"
		self.subtitle = tweet.text
		self.coordinate = tweet.getCoordinates() ?? CLLocationCoordinate2DMake(0.0, 0.0)
	}
}
