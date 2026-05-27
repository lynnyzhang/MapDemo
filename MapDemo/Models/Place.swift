//
//  Place.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - Google Places API response models

struct TextValue: Decodable, Sendable {
    let text: String?
}

struct LocationCoordinate: Decodable, Sendable {
    let latitude: Double?
    let longitude: Double?
}

struct OpeningHours: Decodable, Sendable {
    let openNow: Bool?
    let weekdayDescriptions: [String]?
}

struct PriceRange: Decodable, Sendable {
    let startPrice: Money?
    let endPrice: Money?
}

struct Money: Decodable, Sendable {
    let currencyCode: String?
    let units: String?
}

struct PaymentOptions: Decodable, Sendable {
    let acceptsCreditCards: Bool?
    let acceptsDebitCards: Bool?
    let acceptsNfc: Bool?
    let acceptsCashOnly: Bool?
}

struct ParkingOptions: Decodable, Sendable {
    let paidParkingLot: Bool?
    let freeStreetParking: Bool?
    let paidStreetParking: Bool?
    let paidGarageParking: Bool?
}

struct AccessibilityOptions: Decodable, Sendable {
    let wheelchairAccessibleEntrance: Bool?
    let wheelchairAccessibleRestroom: Bool?
    let wheelchairAccessibleSeating: Bool?
}

struct PlacesSearchResponse: Decodable, Sendable {
    let places: [Place]?
}

struct Place: Identifiable, Decodable, Sendable {
    let id: String?
    let displayName: TextValue?
    let formattedAddress: String?
    let location: LocationCoordinate?
    let rating: Double?
    let userRatingCount: Int?
    let nationalPhoneNumber: String?
    let internationalPhoneNumber: String?
    let websiteUri: String?
    let businessStatus: String?
    let primaryType: String?
    let types: [String]?
    let takeout: Bool?
    let dineIn: Bool?
    let reservable: Bool?
    let servesBreakfast: Bool?
    let servesLunch: Bool?
    let servesDinner: Bool?
    let servesBeer: Bool?
    let servesWine: Bool?
    let servesVegetarianFood: Bool?
    let priceRange: PriceRange?
    let regularOpeningHours: OpeningHours?
    let paymentOptions: PaymentOptions?
    let parkingOptions: ParkingOptions?
    let accessibilityOptions: AccessibilityOptions?

    var coordinate: CLLocationCoordinate2D {
        guard let loc = location, let lat = loc.latitude, let lng = loc.longitude else {
            return CLLocationCoordinate2D(latitude: -180, longitude: -180)
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
