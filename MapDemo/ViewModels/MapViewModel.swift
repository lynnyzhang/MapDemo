//
//  MapViewModel.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class MapViewModel: NSObject {
    var mapItems: [MKMapItem] = []
    var selectedFilter: FilterType = .restaurant {
        didSet { fetchForCurrentFilter() }
    }
    var isLoading = false
    var errorMessage: String?
    var userLocation: CLLocation?
    private let locationManager = CLLocationManager()
    private var fetchTask: Task<Void, Never>?
    private var lastFetchLocation: CLLocationCoordinate2D?
    private let fetchMinDistance: CLLocationDistance = 100

    private var placeLookup: [String: Place] = [:]
    private var errorDismissTask: Task<Void, Never>?

    /// How long before `showError` auto-clears the message (seconds). Tests can override this.
    var errorDismissInterval: TimeInterval = 3.0
    /// Debounce delay for map camera change fetches (nanoseconds). Tests can override this.
    var fetchDebounceInterval: UInt64 = 300_000_000

    func place(for id: String) -> Place? {
        placeLookup[id]
    }

    func showError(_ message: String) {
        errorMessage = message
        #if DEBUG
        print("[MapDemo] Error: \(message)")
        #endif
        errorDismissTask?.cancel()
        errorDismissTask = Task { [weak self] in
            let interval = self?.errorDismissInterval ?? 3.0
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            self?.errorMessage = nil
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 200
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func mapCameraDidChange(cameraCenterCoordinate: CLLocationCoordinate2D) {
        fetchIfNeeded(isFilterUpdated: false, centerCoordinate: cameraCenterCoordinate)
    }

    func fetchForCurrentFilter() {
        guard let coordinate = lastFetchLocation else { return }
        fetchIfNeeded(isFilterUpdated: true, centerCoordinate: coordinate)
    }

    private func fetchIfNeeded(isFilterUpdated: Bool, centerCoordinate: CLLocationCoordinate2D) {
        let fireNewFetch: Bool = isFilterUpdated || lastFetchLocation == nil
        if !fireNewFetch, let last = lastFetchLocation {
            let loc1 = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let loc2 = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
            guard loc1.distance(from: loc2) > fetchMinDistance else { return }
        }

        fetchTask?.cancel()
        fetchTask = Task {
            do {
                guard !Task.isCancelled else { return }

                // Debounce: Wait for 0.3 seconds of inactivity before firing
                try await Task.sleep(nanoseconds: 300_000_000)
                // Check for cancellation right before the API call
                try Task.checkCancellation()
                // Clear to fire
                await fetchPlaces(coordinate: centerCoordinate)

            } catch is CancellationError {
                // Task was canceled because map moved again; safely ignore
                #if DEBUG
                print("Request canceled: Map moved before finishing.")
                #endif
            } catch {
                // Handle actual network or decoding errors
                #if DEBUG
                print("API Error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func fetchPlaces(coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        do {
            let places = try await NearBySearchAPI.searchNearBy(types: [selectedFilter.rawValue],
                                                                latitude: coordinate.latitude,
                                                                longitude: coordinate.longitude)
            lastFetchLocation = coordinate
            processPlaces(places)
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    private func processPlaces(_ places: [Place]) {
        var newItems: [MKMapItem] = []
        var newLookup: [String: Place] = [:]
        newLookup.reserveCapacity(places.count)
        for place in places {
            guard place.location != nil, CLLocationCoordinate2DIsValid(place.coordinate) else { continue }
            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
            item.name = place.displayName?.text
            item.phoneNumber = place.nationalPhoneNumber
            if let urlString = place.websiteUri {
                item.url = URL(string: urlString)
            }
            newItems.append(item)
            if let id = place.id {
                newLookup[id] = place
            }
        }
        mapItems = newItems
        placeLookup = newLookup
    }
}

extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, CLLocationCoordinate2DIsValid(location.coordinate) else { return }
        Task { @MainActor in
            self.userLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        guard clError?.code == .denied else { return }
        manager.stopUpdatingLocation()
        Task { @MainActor in
            self.showError(error.localizedDescription)
        }
    }
}
