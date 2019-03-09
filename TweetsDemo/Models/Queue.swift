//
//  Queue.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/7/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

struct Queue<T> {
	var list = [T]()
	var limit = 100
	
	mutating func enqueue(_ element: T) -> T?{
		list.append(element)
		if list.count > limit {
			return list.removeFirst()
		}
		return nil
	}
}
