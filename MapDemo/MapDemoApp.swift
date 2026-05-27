//
//  MapDemoApp.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import SwiftUI

@main
struct MapDemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MapView()
            }
        }
    }
}
