//
//  UIViewControllerExtension.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

extension UIViewController {
	var topBorderAnchor: NSLayoutYAxisAnchor {
		return view.safeAreaLayoutGuide.topAnchor
	}
	
	var bottomBorderAnchor: NSLayoutYAxisAnchor {
		return view.safeAreaLayoutGuide.bottomAnchor
	}
}

 
