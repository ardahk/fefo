//test

import SwiftUI
import MapKit
import CoreLocation
import Inject

struct MapView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @State private var selectedEvent: FoodEvent?
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

    // Cache computed values
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

    // Cache the initial region for reuse
    private let initialRegion: MKCoordinateRegion

    // Define camera bounds using the correct initializer
    private var cameraBounds: MapCameraBounds {
        // Define the bounding region using the widest allowed span
        let boundingRegion = MKCoordinateRegion(center: campusCenter, span: maxSpan)
        return MapCameraBounds(centerCoordinateBounds: boundingRegion)
    }

    // Initialize cameraPosition and cached regions
    init() {
        let initRegion = MKCoordinateRegion(center: campusCenter, span: initialSpan)
        self.initialRegion = initRegion
        self._cameraPosition = State(initialValue: .region(initRegion))
    }

    // Optimized search results computed property
    var searchResults: [FoodEvent] {
        guard !searchText.isEmpty else { return [] }
        let searchQuery = searchText.lowercased()
        let results = viewModel.foodEvents.filter { event in
            return event.title.localizedCaseInsensitiveContains(searchQuery) ||
                   event.description.localizedCaseInsensitiveContains(searchQuery) ||
                   event.buildingName.localizedCaseInsensitiveContains(searchQuery) ||
                   event.tags.contains { $0.rawValue.localizedCaseInsensitiveContains(searchQuery) }
        }
        // Limit to top 3 matches
        return Array(results.prefix(3))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Add markers only for visible events to improve performance
                ForEach(filteredEvents) { event in
                    Annotation(event.title, coordinate: event.location) {
                        EventMapMarker(event: event, isSelected: selectedEvent?.id == event.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedEvent = event
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: event.location,
                                        span: cameraPosition.region?.span ?? initialSpan
                                    ))
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
            .onMapCameraChange { [lastUpdateTime] context in
                // Using the captured value to avoid capturing self
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

                // Update 3D mode state based on camera pitch
                let newIs3DMode = context.camera.pitch > 0
                if newIs3DMode != is3DMode {
                    withAnimation(.easeOut(duration: 0.2)) {
                        is3DMode = newIs3DMode
                    }
                }
                
                if isOutsideBounds || isOutsideZoom {
                    // Create a new region that preserves the current zoom level if it's valid
                    let newRegion = isOutsideBounds ? 
                        MKCoordinateRegion(center: campusCenter, span: isOutsideZoom ? initialSpan : currentRegion.span) :
                        MKCoordinateRegion(center: currentRegion.center, span: initialSpan)
                    
                    // Update the last update time
                    self.lastUpdateTime = now
                    
                    // Use animation with lower precision on background thread
                    withAnimation(.easeOut(duration: 0.5)) {
                        cameraPosition = .region(newRegion)
                    }
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        // Only dismiss if tap is not on a pin or preview card
                        if selectedEvent != nil {
                            // Check if tap is in the preview card area
                            let isInPreviewCard = value.location.y > UIScreen.main.bounds.height - 150 // Approximate preview card height
                            if !isInPreviewCard {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedEvent = nil
                                }
                            }
                        }
                    }
            )

            VStack(spacing: 0) {
                SearchBar(searchText: $searchText, isSearching: $isSearching)
                    .padding(.horizontal)
                    .padding(.top)
                    .onChange(of: isSearching) { _, newValue in
                        if newValue {
                            // Dismiss the preview card when starting to search
                            withAnimation(.spring(response: 0.3)) {
                                selectedEvent = nil
                            }
                        }
                    }
                
                // Update the preview card section to use exclusive touch
                if let selectedEvent = selectedEvent, !isSearching && searchText.isEmpty {
                    EventPreviewCard(event: selectedEvent, onDismiss: {
                        withAnimation(.spring(response: 0.3)) {
                            self.selectedEvent = nil
                        }
                    })
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        // Only show detail view when explicitly tapping the preview card
                        viewModel.selectedEventForDetail = selectedEvent
                    }
                    .allowsHitTesting(true) // Ensure the preview card can receive touches
                    .contentShape(Rectangle()) // Maintain tappable area
                }

                // 2D/3D Toggle Button - Only show when no preview card and not searching
                if selectedEvent == nil && !isSearching {
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
                                .frame(width: 44, height: 44)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.thinMaterial)
                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
                }

                if !searchText.isEmpty && isSearching {
                    // Search Results List
                    VStack(spacing: 8) {
                        ForEach(searchResults) { event in
                            SearchResultRow(event: event) {
                                // Go directly to EventDetailView instead of showing preview
                                viewModel.selectedEventForDetail = event
                                isSearching = false
                                searchText = ""
                                withAnimation {
                                    cameraPosition = .region(MKCoordinateRegion(center: event.location, span: cameraPosition.region?.span ?? initialSpan))
                                }
                            }
                        }
                        
                        if searchResults.isEmpty {
                            Text("No matching events found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .zIndex(1)
                }
                
                Spacer()
            }
        }
        .sheet(item: $viewModel.selectedEventForDetail) { event in
            EventDetailView(event: event)
                .onDisappear {
                    // Keep the preview card visible when dismissing detail view
                    if selectedEvent == nil {
                        selectedEvent = event
                    }
                }
        }
        .enableInjection()
    }
    
    // Computed property to filter events based on search text and date
    var filteredEvents: [FoodEvent] {
        let calendar = Calendar.current
        let today = Date()
        
        if searchText.isEmpty {
            // When not searching, only show today's events
            return viewModel.foodEvents.filter { event in
                calendar.isDate(event.startTime, inSameDayAs: today)
            }
        } else {
            // When searching, show all matching events
            return viewModel.foodEvents.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.buildingName.localizedCaseInsensitiveContains(searchText) ||
                event.tags.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}

// Enhanced Event Map Marker
struct EventMapMarker: View {
    let event: FoodEvent
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(event.isActive ? Color.blue : Color.gray)
                .frame(width: 32, height: 32)
                .shadow(radius: isSelected ? 3 : 1)
            
            Image(systemName: "fork.knife")
                .foregroundColor(.white)
                .font(.system(size: 16))
        }
        .overlay(alignment: .top) {
            if isSelected {
                // Small dot indicator for selected state
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.bottom, 4)
                    .offset(y: -12)
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
                
                Text(event.statusInfo.text)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.statusInfo.color.opacity(0.2))
                    .foregroundColor(event.statusInfo.color)
                    .cornerRadius(8)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .imageScale(.medium)
                }
            }
            
            // Location
            Text(event.buildingName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Time
            HStack {
                Image(systemName: "clock")
                    .imageScale(.small)
                Text(event.startTime, style: .time)
                Text("•")
                Text(event.endTime, style: .time)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            // Tags and Details
            HStack(spacing: 6) {
                if !event.tags.isEmpty {
                    // Show first 2 tags in their original order
                    ForEach(Array(event.tags.prefix(2)), id: \.self) { tag in
                        Text(tag.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.color.opacity(0.2))
                            .foregroundColor(tag.color)
                            .cornerRadius(8)
                    }
                    
                    if event.tags.count > 2 {
                        Text("+\(event.tags.count - 2)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Text("Details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}

// Updated Search Result Row
struct SearchResultRow: View {
    let event: FoodEvent
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                        
                        Text(event.buildingName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(event.statusInfo.text)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(event.statusInfo.color.opacity(0.2))
                        .foregroundColor(event.statusInfo.color)
                        .cornerRadius(8)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .imageScale(.small)
                    Text(event.startTime, style: .time)
                    Text("•")
                    Text(event.endTime, style: .time)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                if !event.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text(tag.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tag.color.opacity(0.2))
                                .foregroundColor(tag.color)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
                .onChange(of: searchText) { _, newValue in
                    // Ensure search state is active if there's text
                    if !newValue.isEmpty {
                        isSearching = true
                    }
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
        .onTapGesture {
            // Ensure the search becomes active when tapping anywhere in the search bar
            isSearching = true
        }
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

// Add this extension at the bottom of the file
extension FoodEvent {
    var statusInfo: (text: String, color: Color) {
        let now = Date()
        let calendar = Calendar.current
        
        // If event has ended
        if now > endTime {
            return ("Ended", .red)
        }
        
        // If event is today
        if calendar.isDate(startTime, inSameDayAs: now) {
            // If event is in last 15 minutes
            if now > endTime.addingTimeInterval(-15 * 60) {
                return ("Ending", .orange)
            }
            
            // If event has started
            if now >= startTime {
                return ("Now", .green)
            }
            
            // If event is today but hasn't started
            return ("Soon", .blue)
        }
        
        // Future event
        return ("Upcoming", .gray)
    }
}

// Preview
#Preview {
    MapView()
        .environmentObject(FoodEventsViewModel())
} 
