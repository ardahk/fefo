import SwiftUI
import Inject
import MapKit
import MapboxMaps
import Combine

// Location search service
class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var selectedLocation: (name: String, coordinate: CLLocationCoordinate2D)?
    @Published var errorMessage: String?
    @Published var isSearching = false
    
    private let completer: MKLocalSearchCompleter
    
    // Berkeley region - expanded to cover the entire city
    let berkeleyRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8715, longitude: -122.2730),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.region = berkeleyRegion
        completer.resultTypes = [.pointOfInterest, .query]
    }
    
    func searchLocation(_ query: String) {
        guard !query.isEmpty else {
            completions = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchQuery = query
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Step 1: Define Berkeley-specific keywords and boundaries
        let berkeleyKeywords = ["Berkeley", "UC Berkeley", "UCB"]
        let nonBerkeleyKeywords = ["Oakland", "Emeryville", "Albany", "El Cerrito", "Richmond"]
        
        // Step 2: Filter out street suffixes and transport terms
        let streetSuffixes = ["St", "Street", "Ave", "Avenue", "Blvd", "Boulevard", 
                            "Rd", "Road", "Ln", "Lane", "Dr", "Drive", "Way", 
                            "Ct", "Court", "Pl", "Place", "Terrace", "Highway", "Hwy"]
        
        let transportTerms = ["BART", "Station", "Transit", "Bus", "Stop", 
                            "Train", "Airport", "Terminal"]
        
        let filteredResults = completer.results.filter { result in
            let title = result.title
            let subtitle = result.subtitle
            
            // Check if it's explicitly in Berkeley
            let isInBerkeley = berkeleyKeywords.contains { keyword in
                subtitle.contains(keyword)
            }
            
            // Check if it's explicitly NOT in Berkeley
            let isNotInBerkeley = nonBerkeleyKeywords.contains { keyword in
                subtitle.contains(keyword) || title.contains(keyword)
            }
            
            // Check if it's a street or transport
            let containsStreetSuffix = streetSuffixes.contains { suffix in
                title.hasSuffix(" \(suffix)") || title == suffix
            }
            
            let containsTransportTerm = transportTerms.contains { term in
                title.contains(term)
            }
            
            // Include only if:
            // 1. It's in Berkeley
            // 2. Not explicitly in another city
            // 3. Not a street or transport location
            return isInBerkeley && !isNotInBerkeley && !containsStreetSuffix && !containsTransportTerm
        }
        
        // Limit to top 3 results
        completions = Array(filteredResults.prefix(3))
        
        // Update error message if no Berkeley results found
        if completer.results.isEmpty {
            errorMessage = "No locations found"
        } else if completions.isEmpty {
            errorMessage = "No locations found in Berkeley"
        } else {
            errorMessage = nil
        }
    }
    
    func selectLocation(_ completion: MKLocalSearchCompletion) {
        // This method is now empty and will be removed in the next refactoring
    }
    
    func clearSelection() {
        selectedLocation = nil
        errorMessage = nil
        completions = []
        isSearching = false
    }
}

struct AddEventView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @StateObject private var searchService = LocationSearchService()
    
    @State private var title = ""
    @State private var description = ""
    @State private var buildingName = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var selectedTags: [FoodEvent.EventTag] = []
    
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
                        // Combined search and selection view
                        LocationSelectionView(
                            locationName: searchService.selectedLocation?.name ?? "",
                            onClear: {
                                searchService.clearSelection()
                                    selectedLocation = nil
                                buildingName = ""
                                    searchText = ""
                            },
                            isSelected: searchService.selectedLocation != nil
                        )
                        .overlay(
                            TextField("Search for a location", text: $searchText)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 36)
                                .padding(.vertical, 8)
                                .opacity(searchService.selectedLocation == nil ? 1 : 0)
                                .onChange(of: searchText) { _, newValue in
                                    if newValue.isEmpty {
                                        searchService.clearSelection()
                                    } else {
                                        searchService.searchLocation(newValue)
                                    }
                                }
                        )
                        
                        if let errorMessage = searchService.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 4)
                        }
                        
                        if searchService.isSearching && !searchText.isEmpty && !searchService.completions.isEmpty && searchService.selectedLocation == nil {
                            SearchResultsView(
                                completions: searchService.completions,
                                onSelect: { selectedCompletion in
                                    // Create immutable copies of the selection data to ensure consistency
                                    let selectedTitle = String(selectedCompletion.title)
                                    let selectedSubtitle = String(selectedCompletion.subtitle)
                                    
                                    // Debug print to verify which completion was selected
                                    print("Selected: \(selectedTitle)")
                                    
                                    // Update UI state first
                                    searchService.isSearching = false
                                    searchText = selectedTitle
                                    
                                    // Use the exact selected completion to search, not relying on UI updates
                                    Task {
                                        // Use our immutable copies for the search
                                        let searchRequest = MKLocalSearch.Request()
                                        
                                        // Special case for UC Berkeley academic buildings (like Wheeler Hall)
                                        if selectedTitle.contains("Hall") || selectedTitle.contains("Building") || selectedTitle == "Wheeler Hall" {
                                            // Specifically for Wheeler Hall or other academic buildings, add more context to the search
                                            searchRequest.naturalLanguageQuery = "\(selectedTitle) UC Berkeley Campus"
                                            print("Searching for academic building: \(selectedTitle) UC Berkeley Campus")
                                        } else {
                                            // Normal search for other locations
                                            searchRequest.naturalLanguageQuery = "\(selectedTitle) \(selectedSubtitle)"
                                        }
                                        searchRequest.region = searchService.berkeleyRegion
                                        
                                        // Prioritize point of interest results for university buildings
                                        searchRequest.resultTypes = [.pointOfInterest]
                                        
                                        do {
                                            let response = try await MKLocalSearch(request: searchRequest).start()
                                            
                                            // Debug print all results to help in debugging
                                            for (index, item) in response.mapItems.enumerated() {
                                                print("Result \(index): \(item.name ?? "Unknown") at \(item.placemark.coordinate)")
                                            }
                                            
                                            // For university buildings, look through all results for the best match
                                            if selectedTitle.contains("Hall") || selectedTitle.contains("Building") {
                                                // Find the best academic building match - prioritize results with "Hall" in the name
                                                let academicMatches = response.mapItems.filter { item in
                                                    return (item.name?.contains("Hall") ?? false) || 
                                                           (item.name?.contains("Building") ?? false) ||
                                                           (item.placemark.areasOfInterest?.contains(where: { $0.contains("University") || $0.contains("UC Berkeley") }) ?? false)
                                                }
                                                
                                                // Use the first academic match if available, otherwise fall back to first result
                                                let bestMatch = academicMatches.first ?? response.mapItems.first
                                                print("Selected best academic match: \(bestMatch?.name ?? "Unknown")")
                                                
                                                if let bestMatch = bestMatch {
                                                    await MainActor.run {
                                                        // Always use our immutable copy for the name
                                                        searchService.selectedLocation = (
                                                            name: selectedTitle,
                                                            coordinate: bestMatch.placemark.coordinate
                                                        )
                                                        
                                                        selectedLocation = bestMatch.placemark.coordinate
                                                        buildingName = selectedTitle
                                                        
                                                        withAnimation {
                                                            region.center = bestMatch.placemark.coordinate
                                                            region.span = MKCoordinateSpan(
                                                                latitudeDelta: 0.005,
                                                                longitudeDelta: 0.005
                                                            )
                                                        }
                                                    }
                                                }
                                            } else {
                                                // Normal processing for non-academic buildings
                                                if let bestMatch = response.mapItems.first {
                                                    // Debug print to verify coordinates
                                                    print("Found: \(bestMatch.name ?? "Unknown") at \(bestMatch.placemark.coordinate)")
                                                    
                                                    await MainActor.run {
                                                        // Always use our immutable copy for the name
                                                        searchService.selectedLocation = (
                                                            name: selectedTitle,
                                                            coordinate: bestMatch.placemark.coordinate
                                                        )
                                                        
                                                        selectedLocation = bestMatch.placemark.coordinate
                                                        buildingName = selectedTitle
                                                        
                                                        withAnimation {
                                                            region.center = bestMatch.placemark.coordinate
                                                            region.span = MKCoordinateSpan(
                                                                latitudeDelta: 0.005,
                                                                longitudeDelta: 0.005
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                        } catch {
                                            print("Error finding location: \(error)")
                                        }
                                    }
                                }
                            )
                        }
                        
                        if let location = searchService.selectedLocation {
                            MapPickerView(region: $region, selectedLocation: $selectedLocation, onLocationPicked: { coordinate in
                                selectedLocation = coordinate
                            })
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.vertical, 8)
                            
                            // Add a hint text for location adjustment
                            Text("Tap anywhere on the map to adjust the pin location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
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
                                            selectedTags.removeAll { $0 == tag }
                                        } else if selectedTags.count < 4 {
                                            selectedTags.append(tag)
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
        guard let location = selectedLocation else { return }
        
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
            tags: selectedTags,
            attendees: []
        )
        
        viewModel.addFoodEvent(newEvent)
        dismiss()
    }
}

struct MapPickerView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    var onLocationPicked: ((CLLocationCoordinate2D) -> Void)?
    
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
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: [.university]))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .onTapGesture { location in
            guard let onLocationPicked = onLocationPicked else { return }
            
            // Convert tap to coordinate using advanced technique
            let tapPoint = location
            
            // Get the map's frame size
            let mapFrame = UIScreen.main.bounds
            
            // Calculate relative position within frame (0-1)
            let relX = Double(tapPoint.x / mapFrame.width)
            let relY = Double(tapPoint.y / mapFrame.height)
            
            // Calculate the tap location as a coordinate
            let spanHalfLat = region.span.latitudeDelta / 2.0
            let spanHalfLon = region.span.longitudeDelta / 2.0
            
            let newLat = region.center.latitude + (2 * relY - 1) * spanHalfLat
            let newLon = region.center.longitude - (2 * relX - 1) * spanHalfLon
            
            let newCoordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
            onLocationPicked(newCoordinate)
        }
    }
    
    private struct Location: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
}

struct LocationSelectionView: View {
    let locationName: String
    let onClear: () -> Void
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "mappin.circle.fill" : "magnifyingglass")
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 24)
            
            if isSelected {
                Text(locationName)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if isSelected {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SearchResultsView: View {
    let completions: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Use indices to ensure exact selection
            ForEach(Array(completions.enumerated()), id: \.element) { index, completion in
                // Create a new variable for each button to avoid reference issues
                let thisCompletion = completion
                
                Button {
                    // Use the exact completion object that belongs to this button
                    onSelect(thisCompletion)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(completion.title)
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                        Text(completion.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle()) // Ensure the entire area is tappable
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style to avoid conflicts
                
                if index < completions.count - 1 {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
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
