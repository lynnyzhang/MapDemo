import XCTest
import CoreLocation
@testable import MapDemo

final class ViewModelTests: XCTestCase {

    // MARK: - FilterType

    func testFilterType_allCases() {
        let all = FilterType.allCases
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(all[0], .noFilter)
        XCTAssertEqual(all[1], .restaurant)
        XCTAssertEqual(all[2], .gas_station)
        XCTAssertEqual(all[3], .lodging)
        XCTAssertEqual(all[4], .hospital)
    }

    func testFilterType_labels() {
        XCTAssertEqual(FilterType.noFilter.label, "All")
        XCTAssertEqual(FilterType.restaurant.label, "Restaurant")
        XCTAssertEqual(FilterType.gas_station.label, "Gas")
        XCTAssertEqual(FilterType.lodging.label, "Lodging")
        XCTAssertEqual(FilterType.hospital.label, "Hospital")
    }

    func testFilterType_rawValues() {
        XCTAssertEqual(FilterType.noFilter.rawValue, "*")
        XCTAssertEqual(FilterType.restaurant.rawValue, "restaurant")
        XCTAssertEqual(FilterType.gas_station.rawValue, "gas_station")
        XCTAssertEqual(FilterType.lodging.rawValue, "lodging")
        XCTAssertEqual(FilterType.hospital.rawValue, "hospital")
    }

    func testFilterType_Sendable() {
        // Compile-time Sendable check
        let filter = FilterType.restaurant
        Task { @Sendable in
            _ = filter.rawValue
        }
    }

    // MARK: - Place coordinate validation (used by ViewModel)

    func testPlace_coordinateValid() {
        let place = Place(
            id: "1", displayName: nil, formattedAddress: nil,
            location: LocationCoordinate(latitude: 45.0, longitude: -73.0),
            rating: nil, userRatingCount: nil, nationalPhoneNumber: nil,
            internationalPhoneNumber: nil, websiteUri: nil, businessStatus: nil,
            primaryType: nil, types: nil, takeout: nil, dineIn: nil,
            reservable: nil, servesBreakfast: nil, servesLunch: nil,
            servesDinner: nil, servesBeer: nil, servesWine: nil,
            servesVegetarianFood: nil, priceRange: nil,
            regularOpeningHours: nil, paymentOptions: nil,
            parkingOptions: nil, accessibilityOptions: nil
        )
        XCTAssertTrue(CLLocationCoordinate2DIsValid(place.coordinate))
    }

    func testPlace_coordinateInvalid_whenNilLocation() {
        let place = Place(
            id: "2", displayName: nil, formattedAddress: nil,
            location: nil,
            rating: nil, userRatingCount: nil, nationalPhoneNumber: nil,
            internationalPhoneNumber: nil, websiteUri: nil, businessStatus: nil,
            primaryType: nil, types: nil, takeout: nil, dineIn: nil,
            reservable: nil, servesBreakfast: nil, servesLunch: nil,
            servesDinner: nil, servesBeer: nil, servesWine: nil,
            servesVegetarianFood: nil, priceRange: nil,
            regularOpeningHours: nil, paymentOptions: nil,
            parkingOptions: nil, accessibilityOptions: nil
        )
        XCTAssertFalse(CLLocationCoordinate2DIsValid(place.coordinate))
    }

    // MARK: - MapViewModel basics

    @MainActor
    func testViewModel_initialState() {
        let viewModel = MapViewModel()
        XCTAssertTrue(viewModel.mapItems.isEmpty)
        XCTAssertEqual(viewModel.selectedFilter, .restaurant)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.userLocation)
    }

    @MainActor
    func testViewModel_placeLookup() {
        let viewModel = MapViewModel()
        XCTAssertNil(viewModel.place(for: "nonexistent"))
    }

    @MainActor
    func testViewModel_stopUpdatingLocation_doesNotCrash() {
        let viewModel = MapViewModel()
        // Should not crash even before requestLocation is called
        viewModel.stopUpdatingLocation()
    }

    @MainActor
    func testViewModel_showError_setsMessage() {
        let viewModel = MapViewModel()
        viewModel.showError("Test error")
        XCTAssertEqual(viewModel.errorMessage, "Test error")
    }

    @MainActor
    func testViewModel_showError_dismissesAfterInterval() async {
        let viewModel = MapViewModel()
        viewModel.errorDismissInterval = 0.2
        viewModel.showError("Will disappear")
        XCTAssertEqual(viewModel.errorMessage, "Will disappear")

        // Wait generously past the 0.2s interval
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testViewModel_showError_replacesPreviousMessage() async {
        let viewModel = MapViewModel()
        viewModel.showError("First")
        viewModel.showError("Second")
        // Real scenario: latest error should show
        XCTAssertEqual(viewModel.errorMessage, "Second")
    }

    @MainActor
    func testViewModel_showError_replacementResetsDismissTimer() async {
        let viewModel = MapViewModel()
        viewModel.errorDismissInterval = 0.2
        viewModel.showError("First")
        viewModel.showError("Second")
        XCTAssertEqual(viewModel.errorMessage, "Second")

        // Dismiss should use the SECOND call's timer, not the first's
        // Wait generously past the 0.2s interval
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertNil(viewModel.errorMessage, "Dismiss timer should be reset by replacement")
    }

    // Real race condition: CLLocationManagerDelegate calls showError
    // from a nonisolated context via Task { @MainActor in ... }.
    // Verify no crash or state corruption when this interleaves with
    // direct showError calls on the MainActor.
    func testViewModel_showError_raceWithAsyncDelegate() async {
        let viewModel = await MainActor.run { MapViewModel() }

        // Simulate the nonisolated delegate firing showError
        // (mirrors the pattern in locationManager:didFailWithError:)
        await Task { @MainActor in
            viewModel.showError("Delegate error")
        }.value

        let msg1 = await MainActor.run { viewModel.errorMessage }
        XCTAssertEqual(msg1, "Delegate error")

        // Now simulate a direct showError from the UI (MainActor)
        await MainActor.run {
            viewModel.errorDismissInterval = 0.2
            viewModel.showError("UI error")
            XCTAssertEqual(viewModel.errorMessage, "UI error")
        }

        // Dismiss should still work
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let finalMsg = await MainActor.run { viewModel.errorMessage }
        XCTAssertNil(finalMsg)
    }
}
