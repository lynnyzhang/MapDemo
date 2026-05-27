//
//  NearBySearchAPI.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation
import CoreLocation

private let apiKey: String = {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
          !key.isEmpty,
          !key.hasPrefix("$(") else {
        fatalError("Missing GooglePlacesAPIKey in Info.plist — add GOOGLE_PLACES_API_KEY to Xcode build settings")
    }
    return key
}()
private let baseURL = "https://places.googleapis.com/v1/"

struct NearbySearchBody: Encodable, Sendable {
    let includedTypes: [String]
    let maxResultCount = 10
    let locationRestriction: LocationRestriction
}

struct LocationRestriction: Encodable, Sendable {
    let circle: Circle
}

struct Circle: Encodable, Sendable {
    let center: Center
    let radius: Double
}

struct Center: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
}

enum NearBySearchAPI {
    static func searchNearBy(
        types: [String],
        latitude: Double,
        longitude: Double,
        radius: Double = 500
    ) async throws -> [Place] {
        let body = NearbySearchBody(includedTypes: types,
                                    locationRestriction: LocationRestriction(
                                        circle: Circle(
                                            center: Center(latitude: latitude, longitude: longitude),
                                            radius: radius
                                        )
                                    )
        )

        let jsonBody = try JSONEncoder().encode(body)

        let data = try await sendRequest(
            urlPath: baseURL + "places:searchNearby",
            verb: "POST",
            headers: [
                "X-Goog-Api-Key": apiKey,
                "X-Goog-FieldMask": "places.id,places.displayName,places.formattedAddress," +
                                    "places.location,places.rating,places.userRatingCount," +
                                    "places.nationalPhoneNumber,places.websiteUri",
                "Content-Type": "application/json"
            ],
            body: jsonBody
        )

        let response = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)
        return response.places ?? []
    }
}
