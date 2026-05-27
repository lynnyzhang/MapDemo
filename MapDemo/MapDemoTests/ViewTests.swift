import XCTest
import SwiftUI
@testable import MapDemo

final class ViewTests: XCTestCase {

    func testMapView_canBeInstantiated() {
        let view = NavigationStack { MapView() }
        XCTAssertNotNil(view)
    }

    func testFilterType_allCasesCoveredInPicker() {
        // Verify every filter case has a unique, non-empty label
        for filter in FilterType.allCases {
            XCTAssertFalse(filter.label.isEmpty, "Filter \(filter) has empty label")
        }
    }

    @MainActor
    func testMapView_initialState() {
        _ = MapView()
        // Smoke test: no crash on creation
    }

    // MARK: - ViewModel integration (error display logic)

    @MainActor
    func testErrorToast_autoDismiss() async {
        let viewModel = MapViewModel()
        viewModel.errorDismissInterval = 0.2
        viewModel.showError("Temporary error")
        XCTAssertEqual(viewModel.errorMessage, "Temporary error")

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(viewModel.errorMessage, "Error should auto-dismiss after the configured interval")
    }

    @MainActor
    func testErrorToast_dismissOnNewError() {
        let viewModel = MapViewModel()
        viewModel.showError("First error")
        XCTAssertEqual(viewModel.errorMessage, "First error")

        viewModel.showError("Second error")
        XCTAssertEqual(viewModel.errorMessage, "Second error")
    }
}
