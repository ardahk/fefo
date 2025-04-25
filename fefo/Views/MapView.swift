//test

import SwiftUI
import MapKit
import CoreLocation
import Inject

// Add this struct before MapView
private struct LocationKey: Hashable {
    let latitude: Double
    let longitude: Double
    
    init(coordinate: CLLocationCoordinate2D) {
        // Round to 4 decimal places (approximately 11 meters of precision)
        self.latitude = round(coordinate.latitude * 10000) / 10000
        self.longitude = round(coordinate.longitude * 10000) / 10000
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct GroupedEvents: Identifiable {
    let id = UUID()
    let location: CLLocationCoordinate2D
    let events: [FoodEvent]
    
    var isMultiple: Bool {
        events.count > 1
    }
}

struct MapView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @State private var selectedEvents: [FoodEvent]?
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
    
    // Replace the groupedEvents computed property with this:
    private var groupedEvents: [GroupedEvents] {
        Dictionary(grouping: filteredEvents) { event in
            LocationKey(coordinate: event.location)
        }.map { key, events in
            GroupedEvents(location: key.coordinate, events: events)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Replace the existing ForEach with this:
                ForEach(groupedEvents) { group in
                    Annotation(group.events[0].title, coordinate: group.location) {
                        EventMapMarker(events: group.events, isSelected: selectedEvents?.contains(where: { $0.id == group.events[0].id }) ?? false)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    // Reset search state when tapping a pin
                                    isSearching = false
                                    searchText = ""
                                    
                                    selectedEvents = group.events
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: group.location,
                                        span: cameraPosition.region?.span ?? initialSpan
                                    ))
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .including([
                .university,
                .library,
                .museum,
                .stadium,
                .theater
            ])))
            .mapControls { }
            // Add gesture recognizer to dismiss search
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        if isSearching {
                            withAnimation(.spring(response: 0.3)) {
                                isSearching = false
                                searchText = ""
                            }
                        }
                    }
            )
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
                        if let currentEvents = selectedEvents { // Use selectedEvents directly
                            // Approximate height check (adjust if necessary)
                            let previewAreaHeight = currentEvents.count < 3 ? CGFloat(currentEvents.count) * 100 + 16 + 50 : 350
                            let isInPreviewArea = value.location.y > UIScreen.main.bounds.height - previewAreaHeight
                            if !isInPreviewArea {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedEvents = nil
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
                                selectedEvents = nil
                            }
                        }
                    }
                    .onChange(of: searchText) { _, newValue in
                        // If search text is cleared and not actively searching, allow preview cards
                        if newValue.isEmpty {
                            isSearching = false
                        }
                    }
                
                // Display preview cards using the helper method
                previewCardView

                // 2D/3D Toggle Button - Only show when no preview card and not searching
                if selectedEvents == nil && !isSearching {
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
                                withAnimation(.spring(response: 0.3)) {
                                    isSearching = false
                                    searchText = ""
                                }
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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
                
                Spacer()
            }
        }
        .sheet(item: $viewModel.selectedEventForDetail) { event in
            EventDetailView(event: event)
                .onDisappear {
                    // Keep the preview cards visible when dismissing detail view
                    if selectedEvents == nil {
                        selectedEvents = [event]
                    }
                }
        }
        .enableInjection()
    }
    
    // Extracted ViewBuilder for Preview Cards
    @ViewBuilder
    private var previewCardView: some View {
        if let events = selectedEvents, !isSearching {
            if events.count < 3 {
                // Simple VStack for 1-2 events (non-scrollable)
                VStack(spacing: 6) {
                    ForEach(events) { event in
                        EventPreviewCard(event: event, onDismiss: {
                            withAnimation(.spring(response: 0.3)) {
                                self.selectedEvents = nil
                            }
                        })
                        .onTapGesture {
                            viewModel.selectedEventForDetail = event
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color(.systemBackground)
                        .opacity(0.01)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
            } else {
                // ScrollView with fades for 3+ events
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        GeometryReader { scrollGeometry in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                value: scrollGeometry.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)
                        // Moved preference change handler here
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                             scrollOffset = value
                        }

                        VStack(spacing: 6) {
                            ForEach(events) { event in
                                EventPreviewCard(event: event, onDismiss: {
                                    withAnimation(.spring(response: 0.3)) {
                                        self.selectedEvents = nil
                                    }
                                })
                                .onTapGesture {
                                    viewModel.selectedEventForDetail = event
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .coordinateSpace(name: "scroll")
                    .frame(maxHeight: 300)
                    .background(
                        Color(.systemBackground)
                            .opacity(0.01)
                    )
                    .mask(
                        VStack(spacing: 0) {
                            // Top fade
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                            .opacity(scrollOffset < 0 ? 1 : 0)
                            
                            // Main content area
                            Rectangle().fill(Color.black)
                            
                            // Bottom fade
                            LinearGradient(
                                gradient: Gradient(colors: [.black, .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                        }
                    )
                    .disabled(events.count < 3)
                }
                .frame(maxHeight: 300)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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

    // Add this preference key at the bottom of the MapView struct
    @State private var scrollOffset: CGFloat = 0
}

// Replace the existing EventMapMarker with this updated version
struct EventMapMarker: View {
    let events: [FoodEvent]
    let isSelected: Bool
    
    private var isMultiple: Bool {
        events.count > 1
    }
    
    var body: some View {
        ZStack {
            // Background cards for multiple events
            if isMultiple {
                // Right card
                Circle()
                    .fill(events[0].isActive ? Color.blue : Color.gray)
                    .frame(width: 32, height: 32)
                    .offset(x: 16)
                    .shadow(radius: isSelected ? 3 : 1)
                
                // Middle card
                Circle()
                    .fill(events[0].isActive ? Color.blue : Color.gray)
                    .frame(width: 32, height: 32)
                    .offset(x: 8)
                    .shadow(radius: isSelected ? 3 : 1)
            }
            
            // Main card
            Circle()
                .fill(events[0].isActive ? Color.blue : Color.gray)
                .frame(width: 32, height: 32)
                .shadow(radius: isSelected ? 3 : 1)
            
            if isMultiple {
                Text("\(events.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "fork.knife")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .overlay(alignment: .top) {
            if isSelected {
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

// Updated EventPreviewCard with optimized spacing
struct EventPreviewCard: View {
    let event: FoodEvent
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
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
                        .frame(width: 44, height: 44)
                }
            }
            
            HStack(spacing: 4) {
                // Location
                Text(event.buildingName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                // Time
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
                    ForEach(Array(event.tags.prefix(2)), id: \.self) { tag in
                        Text(tag.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(tag.color.opacity(0.2))
                            .foregroundColor(tag.color)
                            .cornerRadius(6)
                    }
                    
                    if event.tags.count > 2 {
                        Text("+\(event.tags.count - 2)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Text("Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
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
            return ("Today", .blue)
        }
        
        // If event is tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        if calendar.isDate(startTime, inSameDayAs: tomorrow) {
            return ("Tomorrow", Color(red: 0.2, green: 0.5, blue: 0.9)) // Lighter, more vibrant blue
        }
        
        // Future event - show date
        return (dateFormatter.string(from: startTime), .blue.opacity(0.7)) // Slightly muted blue for future dates
    }
}

// Add this preference key definition before the EventMapMarker struct
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Preview
#Preview {
    MapView()
        .environmentObject(FoodEventsViewModel())
} 
