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
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    // Campus boundary coordinates with extra padding
    private let campusBoundary: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2691), // Northwest
        CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2495), // Northeast
        CLLocationCoordinate2D(latitude: 37.8631, longitude: -122.2495), // Southeast
        CLLocationCoordinate2D(latitude: 37.8631, longitude: -122.2691), // Southwest
        CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2691)  // Back to start
    ]
    
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
            Map(coordinateRegion: Binding(
                get: { region },
                set: { newRegion in
                    // Limit the map region to stay within campus bounds with padding
                    var limitedRegion = newRegion
                    limitedRegion.center.latitude = min(max(limitedRegion.center.latitude, 37.8631), 37.8791)
                    limitedRegion.center.longitude = min(max(limitedRegion.center.longitude, -122.2691), -122.2495)
                    region = limitedRegion
                }
            ), showsUserLocation: false, annotationItems: filteredEvents) { event in
                MapAnnotation(coordinate: event.location) {
                    EventMapMarker(event: event, isSelected: selectedEvent?.id == event.id)
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            
            VStack(spacing: 0) {
                SearchBar(searchText: $searchText, isSearching: $isSearching)
                    .padding(.horizontal)
                    .padding(.top)
                
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
                                        region.center = event.location
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
                
                // 2D/3D Toggle Button
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            is3DMode.toggle()
                            updateMapPerspective()
                        }
                    } label: {
                        Image(systemName: is3DMode ? "view.2d" : "view.3d")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .accessibilityLabel(is3DMode ? "Switch to 2D view" : "Switch to 3D view")
                    .padding(.trailing)
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
        .onAppear {
            drawCampusBoundary()
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
    
    // Function to update map perspective (2D/3D)
    private func updateMapPerspective() {
        let camera = MKMapCamera(
            lookingAtCenter: region.center,
            fromDistance: is3DMode ? 1000 : 2000,
            pitch: is3DMode ? 45 : 0,
            heading: 0
        )
        
        if let mapView = findMapView() {
            mapView.setCamera(camera, animated: true)
        }
    }
    
    // Helper function to find the MKMapView
    private func findMapView() -> MKMapView? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return findMapViewInView(window)
    }
    
    private func findMapViewInView(_ view: UIView?) -> MKMapView? {
        guard let view = view else { return nil }
        if let mapView = view as? MKMapView {
            return mapView
        }
        for subview in view.subviews {
            if let mapView = findMapViewInView(subview) {
                return mapView
            }
        }
        return nil
    }
    
    // Function to draw campus boundary
    private func drawCampusBoundary() {
        if let mapView = findMapView() {
            // Remove existing overlays
            mapView.removeOverlays(mapView.overlays)
            
            // Create polygon for campus boundary
            let polygon = MKPolygon(coordinates: campusBoundary, count: campusBoundary.count)
            mapView.addOverlay(polygon)
            
            // Set delegate to style the polygon
            mapView.delegate = MapViewDelegate.shared
        }
    }
}

// Map View Delegate to handle overlay styling
class MapViewDelegate: NSObject, MKMapViewDelegate {
    static let shared = MapViewDelegate()
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 2
            renderer.fillColor = .systemBlue.withAlphaComponent(0.1)
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
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
