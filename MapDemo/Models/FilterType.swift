//
//  FilterType.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation

enum FilterType: String, CaseIterable, Sendable {
    case noFilter = "*"
    case restaurant = "restaurant"
    // gas_station is a Google Places API type name, not our naming
    // swiftlint:disable:next identifier_name
    case gas_station = "gas_station"
    case lodging = "lodging"
    case hospital = "hospital"

    var label: String {
        switch self {
        case .noFilter: return "All"
        case .restaurant: return "Restaurant"
        case .gas_station: return "Gas"
        case .lodging: return "Lodging"
        case .hospital: return "Hospital"
        }
    }
}
