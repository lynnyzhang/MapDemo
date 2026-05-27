import XCTest
import CoreLocation
@testable import MapDemo

final class APITests: XCTestCase {

    // MARK: - Place Model Decoding

    func testPlaceDecoding_full() throws {
        let json = """
        {
            "id": "abc123",
            "displayName": { "text": "Cafe Paris" },
            "formattedAddress": "123 Main St, Paris, FR",
            "location": { "latitude": 48.8566, "longitude": 2.3522 },
            "rating": 4.5,
            "userRatingCount": 100,
            "nationalPhoneNumber": "+33 1 23 45 67 89",
            "websiteUri": "https://example.com",
            "businessStatus": "OPERATIONAL",
            "primaryType": "cafe",
            "types": ["cafe", "restaurant"]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let place = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(place.id, "abc123")
        XCTAssertEqual(place.displayName?.text, "Cafe Paris")
        XCTAssertEqual(place.formattedAddress, "123 Main St, Paris, FR")
        XCTAssertEqual(place.location?.latitude, 48.8566)
        XCTAssertEqual(place.location?.longitude, 2.3522)
        XCTAssertEqual(place.rating, 4.5)
        XCTAssertEqual(place.userRatingCount, 100)
        XCTAssertEqual(place.nationalPhoneNumber, "+33 1 23 45 67 89")
        XCTAssertEqual(place.websiteUri, "https://example.com")
        XCTAssertEqual(place.businessStatus, "OPERATIONAL")
        XCTAssertEqual(place.primaryType, "cafe")
        XCTAssertEqual(place.types, ["cafe", "restaurant"])
    }

    func testPlaceDecoding_minimal() throws {
        let json = """
        {
            "id": "minimal",
            "displayName": { "text": "Minimal" },
            "location": { "latitude": 40.0, "longitude": -74.0 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let place = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(place.id, "minimal")
        XCTAssertEqual(place.displayName?.text, "Minimal")
        XCTAssertNil(place.formattedAddress)
        XCTAssertNil(place.rating)
        XCTAssertNil(place.nationalPhoneNumber)
    }

    // MARK: - Coordinate Sentinel

    func testPlaceCoordinate_withLocation() throws {
        let json = """
        {
            "id": "1",
            "location": { "latitude": 45.0, "longitude": -73.0 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let place = try JSONDecoder().decode(Place.self, from: data)
        let coord = place.coordinate

        XCTAssertEqual(coord.latitude, 45.0)
        XCTAssertEqual(coord.longitude, -73.0)
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coord))
    }

    func testPlaceCoordinate_nilLocation() throws {
        let json = """
        {
            "id": "2",
            "displayName": { "text": "No Location" }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let place = try JSONDecoder().decode(Place.self, from: data)
        let coord = place.coordinate

        XCTAssertEqual(coord.latitude, -180)
        XCTAssertEqual(coord.longitude, -180)
        XCTAssertFalse(CLLocationCoordinate2DIsValid(coord))
    }

    func testPlaceCoordinate_partialLocation() throws {
        let json = """
        {
            "id": "3",
            "location": { "latitude": 45.0 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let place = try JSONDecoder().decode(Place.self, from: data)
        let coord = place.coordinate

        XCTAssertEqual(coord.latitude, -180)
        XCTAssertEqual(coord.longitude, -180)
        XCTAssertFalse(CLLocationCoordinate2DIsValid(coord))
    }

    // MARK: - PlacesSearchResponse

    func testPlacesSearchResponseDecoding() throws {
        let json = """
        {
            "places": [
                { "id": "1", "displayName": { "text": "A" }, "location": { "latitude": 1, "longitude": 1 } },
                { "id": "2", "displayName": { "text": "B" }, "location": { "latitude": 2, "longitude": 2 } }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)

        XCTAssertEqual(response.places?.count, 2)
    }

    func testPlacesSearchResponse_empty() throws {
        let json = """
        { "places": [] }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)

        XCTAssertEqual(response.places?.count, 0)
    }

    func testPlacesSearchResponse_missingPlaces() throws {
        let json = """
        {}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)

        XCTAssertNil(response.places)
    }

    // MARK: - NearbySearchBody Encoding

    func testNearbySearchBodyEncoding() throws {
        let body = NearbySearchBody(
            includedTypes: ["restaurant"],
            locationRestriction: LocationRestriction(
                circle: Circle(
                    center: Center(latitude: 45.0, longitude: -73.0),
                    radius: 500
                )
            )
        )

        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual((json["includedTypes"] as? [String])?.first, "restaurant")
        XCTAssertEqual(json["maxResultCount"] as? Int, 10)

        let restriction = try XCTUnwrap(json["locationRestriction"] as? [String: Any])
        let circle = try XCTUnwrap(restriction["circle"] as? [String: Any])
        let center = try XCTUnwrap(circle["center"] as? [String: Any])
        XCTAssertEqual(center["latitude"] as? Double, 45.0)
        XCTAssertEqual(center["longitude"] as? Double, -73.0)
        XCTAssertEqual(circle["radius"] as? Double, 500)
    }

    // MARK: - APIError

    func testAPIError_httpError_withMessage() {
        let error = APIError.httpError(statusCode: 400, message: "Bad request body")
        XCTAssertEqual(error.errorDescription, "HTTP 400: Bad request body")
    }

    func testAPIError_httpError_429_message() {
        let error = APIError.httpError(statusCode: 429, message: "You have exceeded your rate limit.")
        XCTAssertEqual(error.errorDescription, "HTTP 429: You have exceeded your rate limit.")
    }

    func testAPIError_httpError_noMessage() {
        let error = APIError.httpError(statusCode: 500, message: nil)
        XCTAssertEqual(error.errorDescription, "HTTP error 500.")
    }

    func testAPIError_invalidURL() {
        let error = APIError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid URL.")
    }

    func testAPIError_decodingFailed() {
        let error = APIError.decodingFailed(
            NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad data"])
        )
        XCTAssertTrue(error.errorDescription?.contains("Bad data") == true)
    }

    func testAPIError_Sendable() {
        let error = APIError.httpError(statusCode: 429, message: "rate limit")
        // Verify it can be passed across concurrency boundaries (compile-time Sendable check)
        Task { @Sendable in
            _ = error.errorDescription
        }
    }
}
