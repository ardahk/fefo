//test

import SwiftUI
import MapKit
import CoreLocation
import Inject

struct MapView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @Binding var selectedEvent: FoodEvent?
    @State private var searchText = ""
    @State private var is3DMode = false
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition
    @State private var lastUpdateTime: Date = Date()
    private let updateThreshold: TimeInterval = 0.1

    // Define campus boundary coordinates with 1 mile extension (approximately 0.0145 degrees)
    private let northWest = CLLocationCoordinate2D(latitude: 37.8791 + 0.0145, longitude: -122.2691 - 0.0145)
    private let northEast = CLLocationCoordinate2D(latitude: 37.8791 + 0.0145, longitude: -122.2495 + 0.0145)
    private let southEast = CLLocationCoordinate2D(latitude: 37.8631 - 0.0145, longitude: -122.2495 + 0.0145)
    private let southWest = CLLocationCoordinate2D(latitude: 37.8631 - 0.0145, longitude: -122.2691 - 0.0145)

    // Define campus center and span
    private let campusCenter = CLLocationCoordinate2D(
        latitude: (37.8791 + 37.8631) / 2,
        longitude: (-122.2691 + -122.2495) / 2
    )
    private let initialSpan = MKCoordinateSpan(
        latitudeDelta: 0.016,
        longitudeDelta: 0.0196
    )
    // Remove minSpan to allow unlimited zoom in
    private let maxSpan = MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.03) // Slightly larger than initial span

    // Define camera bounds using the correct initializer
    private var cameraBounds: MapCameraBounds {
        // Define the bounding region using the widest allowed span
        let boundingRegion = MKCoordinateRegion(center: campusCenter, span: maxSpan)
        return MapCameraBounds(centerCoordinateBounds: boundingRegion)
    }

    // Initialize cameraPosition
    init(selectedEvent: Binding<FoodEvent?>) {
        self._selectedEvent = selectedEvent
        let initialRegion = MKCoordinateRegion(center: campusCenter, span: initialSpan)
        self._cameraPosition = State(initialValue: .region(initialRegion))
    }

    // Search results computed property
    var searchResults: [FoodEvent] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.foodEvents.filter { event in
            let searchQuery = searchText.lowercased()
            return event.title.localizedCaseInsensitiveContains(searchQuery) ||
                   event.description.localizedCaseInsensitiveContains(searchQuery) ||
                   event.buildingName.localizedCaseInsensitiveContains(searchQuery) ||
                   event.tags.contains { $0.rawValue.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Add markers for events
                ForEach(filteredEvents) { event in
                    Annotation(event.title, coordinate: event.location) {
                        EventMapMarker(event: event, isSelected: selectedEvent?.id == event.id)
                            .onTapGesture {
                                selectedEvent = event
                                withAnimation {
                                    cameraPosition = .region(MKCoordinateRegion(center: event.location, span: cameraPosition.region?.span ?? initialSpan))
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .including([
                .university,
                .library,
                .museum,
                .stadium,
                .theater
            ])))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { context in
                // Prevent too frequent updates
                let now = Date()
                guard now.timeIntervalSince(lastUpdateTime) >= updateThreshold else { return }
                
                let currentRegion = context.region
                
                // Check if we're outside bounds
                let centerLat = currentRegion.center.latitude
                let centerLon = currentRegion.center.longitude
                
                let isOutsideBounds =
                    centerLat < southWest.latitude ||
                    centerLat > northWest.latitude ||
                    centerLon < northWest.longitude ||
                    centerLon > northEast.longitude
                
                // Check only maximum zoom (allow unlimited zoom in)
                let spanLatDelta = currentRegion.span.latitudeDelta
                let spanLonDelta = currentRegion.span.longitudeDelta
                
                let isOutsideZoom =
                    spanLatDelta > maxSpan.latitudeDelta ||
                    spanLonDelta > maxSpan.longitudeDelta
                
                if isOutsideBounds || isOutsideZoom {
                    // Create a new region that preserves the current zoom level if it's valid
                    let newRegion = MKCoordinateRegion(
                        center: isOutsideBounds ? campusCenter : currentRegion.center,
                        span: isOutsideZoom ? initialSpan : currentRegion.span
                    )
                    
                    // Update the last update time
                    lastUpdateTime = now
                    
                    // Remove the delay and use main thread directly with weak self
                    withAnimation(.easeOut(duration: 0.5)) {
                        cameraPosition = .region(newRegion)
                    }
                }
            }

            VStack(spacing: 0) {
                SearchBar(searchText: $searchText, isSearching: $isSearching)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 2D/3D Toggle Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            is3DMode.toggle()
                            let newCamera = is3DMode ?
                                MapCamera(centerCoordinate: cameraPosition.region?.center ?? campusCenter,
                                        distance: 1000,
                                        heading: 0,
                                        pitch: 45) :
                                MapCamera(centerCoordinate: cameraPosition.region?.center ?? campusCenter,
                                        distance: 1000,
                                        heading: 0,
                                        pitch: 0)
                            cameraPosition = .camera(newCamera)
                        }
                    }) {
                        Text(is3DMode ? "2D" : "3D")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(.thickMaterial)
                            }
                    }
                    .padding(.trailing)
                }
                .padding(.top, 8)

                if !searchText.isEmpty && isSearching {
                    // Search Results List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { event in
                                SearchResultRow(event: event) {
                                    selectedEvent = event
                                    isSearching = false
                                    searchText = ""
                                    withAnimation {
                                        cameraPosition = .region(MKCoordinateRegion(center: event.location, span: cameraPosition.region?.span ?? initialSpan))
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                
                                if event.id != searchResults.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    .frame(maxHeight: 300)
                }
                
                if let selectedEvent = selectedEvent {
                    EventPreviewCard(event: selectedEvent) {
                        self.selectedEvent = nil
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .enableInjection()
    }
    
    // Computed property to filter events based on search text
    var filteredEvents: [FoodEvent] {
        if searchText.isEmpty {
            return viewModel.foodEvents
        }
        return viewModel.foodEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.buildingName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// Enhanced Event Map Marker
struct EventMapMarker: View {
    let event: FoodEvent
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if isSelected {
                Text(event.title)
                    .font(.caption)
                    .padding(6)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            
            ZStack {
                Circle()
                    .fill(event.isActive ? Color.blue : Color.gray)
                    .frame(width: 40, height: 40)
                    .shadow(radius: isSelected ? 4 : 2)
                
                Image(systemName: "fork.knife")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// Preview card when pin is selected
struct EventPreviewCard: View {
    let event: FoodEvent
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            if !event.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text(tag.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(tag.color.opacity(0.2))
                                )
                                .foregroundColor(tag.color)
                        }
                    }
                }
            }
            
            Text(event.buildingName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock")
                Text(event.startTime, style: .time)
                Text("-")
                Text(event.endTime, style: .time)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            StatusBadge(isActive: event.isActive)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// Search Result Row
struct SearchResultRow: View {
    let event: FoodEvent
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(event.buildingName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if event.isActive {
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Tag icons
                HStack(spacing: 4) {
                    ForEach(Array(event.tags.prefix(3)), id: \.self) { tag in
                        Circle()
                            .fill(tag.color)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// Tag Icon
struct TagIcon: View {
    let tag: FoodEvent.EventTag
    
    var iconName: String {
        switch tag {
        case .freeFood: return "fork.knife"
        case .snacks: return "cup.and.saucer.fill"
        case .drinks: return "cup.and.saucer.fill"
        case .club: return "person.3.fill"
        case .seminar: return "person.fill.viewfinder"
        case .workshop: return "hammer.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .academic: return "book.fill"
        case .sports: return "figure.run"
        case .cultural: return "globe.americas.fill"
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(tag.color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Updated SearchBar
struct SearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search events or buildings...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onTapGesture {
                    isSearching = true
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isSearching = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
}

// Add a struct for landmarks
struct MapLandmark: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: BuildingType
    let visibilityRange: Double // Distance in meters when the landmark becomes visible
    
    enum BuildingType {
        case academic    // Classrooms, lecture halls
        case library
        case landmark   // Gates, monuments
        case athletics  // Gyms, stadiums
        case student    // Student unions, services
        case dining
        
        var icon: String {
            switch self {
            case .academic: return "building.columns.fill"
            case .library: return "books.vertical.fill"
            case .landmark: return "mappin.circle.fill"
            case .athletics: return "sportscourt.fill"
            case .student: return "person.2.fill"
            case .dining: return "fork.knife.circle.fill"
            }
        }
    }
}

// Add this extension for smooth interpolation
extension Double {
    static func interpolate(from: Double, to: Double, in value: Double, fromLow: Double, fromHigh: Double) -> Double {
        let percentage = (value - fromLow) / (fromHigh - fromLow)
        return from + (to - from) * percentage
    }
}

// Preview
#Preview {
    MapView(selectedEvent: .constant(nil))
        .environmentObject(FoodEventsViewModel())
} 
