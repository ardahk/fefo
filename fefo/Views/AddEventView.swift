import SwiftUI
import Inject
import MapKit
import MapboxMaps
import Combine

struct AddEventView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var buildingName = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var showingLocationSearch = false
    @State private var selectedLocationName: String = ""
    @State private var selectedTags: Set<FoodEvent.EventTag> = []
    
    // UC Berkeley's campus region
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 37.8719,
            longitude: -122.2585
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.01,
            longitudeDelta: 0.01
        )
    )
    
    var filteredLocations: [MapLandmark] {
        if searchText.isEmpty {
            return []
        }
        return Constants.berkeleyLandmarks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Location") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Search Location", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: searchText) { _, _ in
                                showingLocationSearch = !searchText.isEmpty
                            }
                        
                        if !selectedLocationName.isEmpty {
                            HStack {
                                Text("Selected: ")
                                    .foregroundColor(.secondary)
                                Text(selectedLocationName)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button {
                                    selectedLocationName = ""
                                    selectedLocation = nil
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if showingLocationSearch && !filteredLocations.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(filteredLocations) { location in
                                        Button {
                                            selectLocation(location)
                                        } label: {
                                            HStack {
                                                Image(systemName: location.type.icon)
                                                    .foregroundColor(.secondary)
                                                Text(location.name)
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        Divider()
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .frame(maxHeight: 200)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
                    
                    MapPickerView(region: $region, selectedLocation: $selectedLocation)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.vertical, 8)
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, in: Date()...)
                    DatePicker("End Time", selection: $endTime, in: startTime...)
                }
                
                Section("Tags (Max 4)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FoodEvent.EventTag.allCases, id: \.self) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else if selectedTags.count < 4 {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        addEvent()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
        .enableInjection()
    }
    
    private var isValidForm: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !buildingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation != nil &&
        endTime > startTime
    }
    
    private func addEvent() {
        // Use the map's center if no location is selected
        let location = selectedLocation ?? region.center
        
        let newEvent = FoodEvent(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location,
            buildingName: buildingName.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startTime,
            endTime: endTime,
            createdBy: "Anonymous",
            isActive: true,
            comments: [],
            tags: [],
            attendees: []
        )
        
        viewModel.addFoodEvent(newEvent)
        dismiss()
    }
    
    private func selectLocation(_ landmark: MapLandmark) {
        buildingName = landmark.name
        selectedLocationName = landmark.name
        selectedLocation = landmark.coordinate
        region.center = landmark.coordinate
        searchText = ""
        showingLocationSearch = false
    }
}

struct MapPickerView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @State private var is3DMode = true
    
    // Create a Location struct that conforms to Identifiable
    private struct Location: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
    
    // Convert optional location to array of Location
    private var annotations: [Location] {
        if let location = selectedLocation {
            return [Location(coordinate: location)]
        }
        return []
    }
    
    var body: some View {
        Map(coordinateRegion: $region,
            interactionModes: .all,
            showsUserLocation: false,
            userTrackingMode: .none,
            annotationItems: annotations
        ) { location in
            MapMarker(coordinate: location.coordinate, tint: .red)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: {
                withAnimation {
                    is3DMode.toggle()
                    if is3DMode {
                        region.span = MKCoordinateSpan(
                            latitudeDelta: 0.01,
                            longitudeDelta: 0.01
                        )
                    } else {
                        region.span = MKCoordinateSpan(
                            latitudeDelta: 0.005,
                            longitudeDelta: 0.005
                        )
                    }
                }
            }) {
                Image(systemName: is3DMode ? "view.2d" : "view.3d")
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .padding()
        }
        .onTapGesture { location in
            let coordinate = convertTapToCoordinate(location)
            selectedLocation = coordinate
            withAnimation {
                region.center = coordinate
            }
        }
    }
    
    private func convertTapToCoordinate(_ location: CGPoint) -> CLLocationCoordinate2D {
        // This is a simplified conversion - in real usage you'd want to use proper conversion
        let span = region.span
        let center = region.center
        
        let deltaLat = span.latitudeDelta
        let deltaLon = span.longitudeDelta
        
        let lat = center.latitude + (deltaLat * 0.5)
        let lon = center.longitude + (deltaLon * 0.5)
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct TagButton: View {
    let tag: FoodEvent.EventTag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? tag.color.opacity(0.2) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? tag.color : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? tag.color : .secondary)
        }
    }
}

#Preview {
    AddEventView()
        .environmentObject(FoodEventsViewModel())
} 