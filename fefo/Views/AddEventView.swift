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
    
    @State private var isCustomLocation = false
    @State private var customLocationName = ""
    @State private var showingCustomLocationPrompt = false
    @State private var isPinDraggable = false
    
    // Limits
    private let descriptionCharacterLimit = 2000
    @State private var isShowingFullDescriptionEditor = false
    
    private func handleLocationSelection(_ completion: MKLocalSearchCompletion) {
        let title = completion.title
        let subtitle = completion.subtitle
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            searchService.isSearching = false
            searchText = title
        }
        
        Task {
            let searchRequest = MKLocalSearch.Request()
            
            if title.contains("Hall") || title.contains("Building") || title == "Wheeler Hall" {
                searchRequest.naturalLanguageQuery = "\(title) UC Berkeley Campus"
            } else {
                searchRequest.naturalLanguageQuery = "\(title) \(subtitle)"
            }
            searchRequest.region = searchService.berkeleyRegion
            searchRequest.resultTypes = [.pointOfInterest]
            
            do {
                let response = try await MKLocalSearch(request: searchRequest).start()
                
                if title.contains("Hall") || title.contains("Building") {
                    let academicMatches = response.mapItems.filter { item in
                        return (item.name?.contains("Hall") ?? false) || 
                               (item.name?.contains("Building") ?? false) ||
                               (item.placemark.areasOfInterest?.contains(where: { $0.contains("University") || $0.contains("UC Berkeley") }) ?? false)
                    }
                    
                    let bestMatch = academicMatches.first ?? response.mapItems.first
                    
                    if let bestMatch = bestMatch {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                searchService.selectedLocation = (
                                    name: title,
                                    coordinate: bestMatch.placemark.coordinate
                                )
                                
                                selectedLocation = bestMatch.placemark.coordinate
                                buildingName = title
                                
                                region.center = bestMatch.placemark.coordinate
                                region.span = MKCoordinateSpan(
                                    latitudeDelta: 0.005,
                                    longitudeDelta: 0.005
                                )
                            }
                        }
                    }
                } else {
                    if let bestMatch = response.mapItems.first {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                searchService.selectedLocation = (
                                    name: title,
                                    coordinate: bestMatch.placemark.coordinate
                                )
                                
                                selectedLocation = bestMatch.placemark.coordinate
                                buildingName = title
                                
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
    
    var locationSection: some View {
        Section("Location") {
            VStack(alignment: .leading, spacing: 12) {
                LocationSelectionView(
                    locationName: isCustomLocation ? customLocationName : (searchService.selectedLocation?.name ?? ""),
                    onClear: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            searchService.clearSelection()
                            selectedLocation = nil
                            buildingName = ""
                            searchText = ""
                            isCustomLocation = false
                            customLocationName = ""
                            isPinDraggable = false
                        }
                    },
                    isSelected: selectedLocation != nil
                )
                .overlay(
                    TextField("Search for a location", text: $searchText)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 36)
                        .padding(.vertical, 8)
                        .opacity(selectedLocation == nil ? 1 : 0)
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
                
                ZStack(alignment: .top) {
                    MapPickerView(
                        region: $region,
                        selectedLocation: $selectedLocation,
                        isPinDraggable: $isPinDraggable,
                        onLocationPicked: { coordinate in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedLocation = coordinate
                                if isPinDraggable {
                                    showingCustomLocationPrompt = true
                                    isCustomLocation = true
                                }
                            }
                        }
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                    
                    if searchService.isSearching && !searchText.isEmpty && !searchService.completions.isEmpty && searchService.selectedLocation == nil {
                        SearchResultsView(
                            completions: searchService.completions,
                            onSelect: { completion in
                                isPinDraggable = false
                                isCustomLocation = false
                                handleLocationSelection(completion)
                            }
                        )
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomLocationPrompt) {
            NavigationView {
                Form {
                    Section(header: Text("Location Details")) {
                        TextField("Location Name", text: $customLocationName)
                            .autocapitalization(.words)
                    }
                    
                    Section(header: Text("Help others find this location"),
                            footer: Text("Enter a descriptive name for this location to help others find it easily.")) {
                        Text("Examples:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• North Side Soda Hall")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Memorial Glade Picnic Area")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Name This Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingCustomLocationPrompt = false
                            selectedLocation = nil
                            isCustomLocation = false
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            buildingName = customLocationName
                            showingCustomLocationPrompt = false
                        }
                        .disabled(customLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    // Scrolling description field with hard character cap
                    VStack(alignment: .leading, spacing: 6) {
                        let showsFormattedPreview = containsMarkdown(description)
                        ZStack(alignment: .topLeading) {
                            if showsFormattedPreview {
                                // Show plain text preview with proper line breaks
                                ScrollView {
                                    Text(description)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.body)
                                        .padding(.top, 8)
                                        .padding(.leading, 3)
                                }
                                .frame(height: 160)
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingFullDescriptionEditor = true }
                            } else {
                                TextEditor(text: $description)
                                    .frame(height: 160)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(.systemBackground))
                                    .onChange(of: description) { _, newValue in
                                        if newValue.count > descriptionCharacterLimit {
                                            description = String(newValue.prefix(descriptionCharacterLimit))
                                        }
                                        if newValue.count > 10 && !isShowingFullDescriptionEditor {
                                            isShowingFullDescriptionEditor = true
                                        }
                                    }
                            }
                            if description.isEmpty {
                                Text("Event Description")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        // Counter appears when approaching limit; turns red at max
                        let count = description.count
                        let showCounter = count >= Int(Double(descriptionCharacterLimit) * 0.8) || count == descriptionCharacterLimit
                        if showCounter {
                            HStack {
                                Spacer()
                                Text("\(min(count, descriptionCharacterLimit))/\(descriptionCharacterLimit)")
                                    .font(.caption2)
                                    .foregroundColor(count >= descriptionCharacterLimit ? .red : .secondary)
                            }
                        }
                        
                        if description.count >= 10 {
                            Button("Open editor…") {
                                isShowingFullDescriptionEditor = true
                            }
                            .font(.caption)
                        }
                    }
                }
                
                locationSection
                
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
        .sheet(isPresented: $isShowingFullDescriptionEditor) {
            DescriptionEditorSheet(text: $description, limit: descriptionCharacterLimit)
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

// Lightweight markdown detection to decide whether to show formatted preview
private func containsMarkdown(_ text: String) -> Bool {
    // Just check if text has content and newlines
    return text.contains("\n") || text.count > 80
}

// Lightweight markdown sanitizer and line-break normalizer
private func sanitizeMarkdownForDisplay(_ text: String) -> String {
    var t = text
    // Neutralize invalid anchor links which may cause parser issues
    t = t.replacingOccurrences(of: "](#)", with: "](about:blank)")
    // Replace common horizontal rule with an em-dash line
    t = t.replacingOccurrences(of: "\n---\n", with: "\n—\n")
    return t
}

private func normalizeLineBreaksForDisplay(_ text: String) -> String {
    // Keep as-is if likely contains block markdown (lists, code blocks etc.)
    let hasBlocks = text.hasPrefix("- ") || text.contains("\n- ") || text.hasPrefix("* ") || text.contains("\n* ")
    if hasBlocks { return text }
    let placeholder = "§§PARA§§"
    let step1 = text.replacingOccurrences(of: "\n\n", with: placeholder)
    let step2 = step1.replacingOccurrences(of: "\n", with: "  \n")
    return step2.replacingOccurrences(of: placeholder, with: "\n\n")
}

// MARK: - Full-screen description editor
private struct DescriptionEditorSheet: View {
    @Binding var text: String
    let limit: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .padding()
                    .onChange(of: text) { _, newValue in
                        if newValue.count > limit {
                            text = String(newValue.prefix(limit))
                        }
                    }
                HStack {
                    Spacer()
                    Text("\(min(text.count, limit))/\(limit)")
                        .font(.caption2)
                        .foregroundColor(text.count >= limit ? .red : .secondary)
                        .padding(.trailing)
                        .padding(.bottom, 26)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("Edit Description")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}

private enum RichAction { }

private struct RichTextView: UIViewRepresentable {
    @Binding var text: String
    let limit: Int
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextView
        var textView: UITextView?
        
        init(parent: RichTextView) { self.parent = parent }
        
        func textViewDidChangeSelection(_ textView: UITextView) { self.textView = textView }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = textView.text as NSString
            let prospective = current.replacingCharacters(in: range, with: text)
            if prospective.count > parent.limit { return false }
            return true
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        let base = UIFont.preferredFont(forTextStyle: .body)
        tv.font = base
        tv.adjustsFontForContentSizeCategory = true
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.text = text
        context.coordinator.textView = tv
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}

private struct MapPickerView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var isPinDraggable: Bool
    var onLocationPicked: ((CLLocationCoordinate2D) -> Void)?
    
    var body: some View {
        Map(position: .constant(MapCameraPosition.region(region))) {
            if let location = selectedLocation {
                Marker("Selected Location", coordinate: location)
                    .tint(.red)
            }
        }
        .onMapCameraChange { context in
            DispatchQueue.main.async {
                self.region = context.region
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: [.university]))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .overlay(
            Group {
                if selectedLocation == nil {
                    Color(.systemBackground)
                        .opacity(0.7)
                        .overlay(
                            VStack(spacing: 8) {
                                Text("Search for a location above")
                                    .foregroundColor(.secondary)
                                Text("or tap here to drop a pin")
                                    .foregroundColor(.blue)
                            }
                        )
                        .onTapGesture {
                            isPinDraggable = true
                            onLocationPicked?(region.center)
                        }
                }
            }
        )
        .onTapGesture { location in
            guard let onLocationPicked = onLocationPicked,
                  isPinDraggable else { return }
            
            let tapPoint = location
            let mapFrame = UIScreen.main.bounds
            let relX = Double(tapPoint.x / mapFrame.width)
            let relY = Double(tapPoint.y / mapFrame.height)
            let spanHalfLat = region.span.latitudeDelta / 2.0
            let spanHalfLon = region.span.longitudeDelta / 2.0
            let newLat = region.center.latitude + (2 * relY - 1) * spanHalfLat
            let newLon = region.center.longitude - (2 * relX - 1) * spanHalfLon
            let newCoordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
            onLocationPicked(newCoordinate)
        }
    }
}

private struct LocationSelectionView: View {
    let locationName: String
    let onClear: () -> Void
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "mappin.circle.fill" : "magnifyingglass")
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 24)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            
            if isSelected {
                Text(locationName)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Spacer()
            
            if isSelected {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

private struct SearchResultsView: View {
    let completions: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void
    
    private let minTouchTargetSize: CGFloat = 44 // Apple's minimum touch target size
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(completions.enumerated()), id: \.element) { index, completion in
                let thisCompletion = completion
                
                Button {
                    onSelect(thisCompletion)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(completion.title)
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                        Text(completion.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: minTouchTargetSize) // Ensure minimum touch target size
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                if index < completions.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

private struct TagButton: View {
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

