//
//  MapView.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = MapViewModel()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selection: MKMapItem?

    var body: some View {
        ZStack(alignment: .top) {
            mapContent
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 100)
            }
            VStack {
                Spacer()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
            }
        }
        .onAppear {
            viewModel.requestLocation()
        }
        .onChange(of: viewModel.userLocation) { _, newLocation in
            guard newLocation != nil else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.requestLocation()
            } else {
                viewModel.stopUpdatingLocation()
            }
        }
    }

    var mapContent: some View {
        Map(position: $cameraPosition, selection: $selection) {
            UserAnnotation()
            ForEach(viewModel.mapItems, id: \.self) { mapItem in
                Marker(item: mapItem)
                    .tag(mapItem)
            }
        }
        .mapItemDetailSheet(item: $selection)
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.mapCameraDidChange(cameraCenterCoordinate: context.region.center)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.requestLocation()
                withAnimation(.easeInOut(duration: 0.3)) {
                    cameraPosition = .userLocation(fallback: .automatic)
                }
            } label: {
                Image(systemName: "location.fill")
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(SwiftUI.Circle())
                    .shadow(radius: 2)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 100)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
}
