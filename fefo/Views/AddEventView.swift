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
                                // Render formatted preview instead of raw markdown; tap to edit full-screen
                                ScrollView {
                                    Group {
                                        if let att = try? AttributedString(markdown: description) {
                                            Text(att)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text(description)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .font(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 3)
                                }
                                .frame(height: 160)
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingFullDescriptionEditor = true }
                            } else {
                                TextEditor(text: $description)
                                    .frame(height: 160) // Fixed height: content scrolls, form row stays stable
                                    .scrollContentBackground(.hidden)
                                    .background(Color(.systemBackground)) // Match form cell background
                                    .onChange(of: description) { _, newValue in
                                        if newValue.count > descriptionCharacterLimit {
                                            description = String(newValue.prefix(descriptionCharacterLimit))
                                        }
                                        // Auto-escalate to full-screen editor when long
                                        if newValue.count > 400 && !isShowingFullDescriptionEditor {
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
    // detect **bold** or *italic* or list item "- "
    if text.contains("**") { return true }
    if text.contains("*") { return true }
    if text.contains("\n- ") || text.hasPrefix("- ") { return true }
    return false
}

// MARK: - Full-screen description editor
private struct DescriptionEditorSheet: View {
    @Binding var text: String
    let limit: Int
    @Environment(\.dismiss) private var dismiss
    @State private var action: RichAction? = nil
    @State private var attributed = NSMutableAttributedString(string: "")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                RichTextView(attributedText: $attributed, limit: limit, action: $action)
                    .padding(.horizontal)
                    .padding(.top)
                    .onAppear {
                        attributed = RichTextView.markdownToAttributed(text)
                    }
                HStack {
                    Spacer()
                    Text("\(min(attributed.string.count, limit))/\(limit)")
                        .font(.caption2)
                        .foregroundColor(attributed.string.count >= limit ? .red : .secondary)
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
                        text = RichTextView.attributedToMarkdown(attributed)
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

private enum RichAction { case bold, italic, bullet }

private struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    let limit: Int
    @Binding var action: RichAction?
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextView
        var textView: UITextView?
        var insertBulletOnNextChange = false
        
        init(parent: RichTextView) { self.parent = parent }
        
        func textViewDidChangeSelection(_ textView: UITextView) { self.textView = textView }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Character limit
            let current = textView.attributedText.string as NSString
            let prospective = current.replacingCharacters(in: range, with: text)
            if prospective.count > parent.limit { return false }
            
            if text == "\n" {
                let loc = max(range.location - 1, 0)
                let paraRange = current.paragraphRange(for: NSRange(location: loc, length: 0))
                let para = current.substring(with: paraRange)
                if para.trimmingCharacters(in: .whitespacesAndNewlines) == "-" || para.trimmingCharacters(in: .whitespacesAndNewlines) == "-" {
                    // Double enter on empty bullet -> remove bullet and end list
                    if let start = textView.position(from: textView.beginningOfDocument, offset: paraRange.location),
                       let end = textView.position(from: textView.beginningOfDocument, offset: paraRange.location + paraRange.length) {
                        textView.replace(textView.textRange(from: start, to: end)!, withText: "\n")
                    }
                    return false
                }
                if para.hasPrefix("- ") { insertBulletOnNextChange = true }
            }
            return true
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if insertBulletOnNextChange {
                insertBulletOnNextChange = false
                if let range = textView.selectedTextRange { textView.replace(range, withText: "- ") }
            }
            parent.attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        }

        // MARK: - Keyboard toolbar actions
        @objc func tapBold() {
            guard let tv = textView else { return }
            parent.toggleTrait(.traitBold, in: tv)
        }
        @objc func tapItalic() {
            guard let tv = textView else { return }
            parent.toggleTrait(.traitItalic, in: tv)
        }
        @objc func tapBullet() {
            guard let tv = textView else { return }
            parent.insertBullet(in: tv)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        // Preferred text styling
        let base = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: 17))
        tv.font = UIFont(descriptor: base.fontDescriptor.withSymbolicTraits([]) ?? base.fontDescriptor, size: base.pointSize + 2)
        tv.adjustsFontForContentSizeCategory = true
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        // Ensure initial attributed text has the base font so bold/italic toggles work visibly
        if attributedText.length == 0 {
            tv.attributedText = NSAttributedString(string: "", attributes: [.font: tv.font!])
        } else {
            tv.attributedText = normalizeFonts(in: attributedText, base: tv.font!)
        }
        tv.typingAttributes[.font] = tv.font
        // Keyboard accessory with elevated controls following iOS margins
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let bold = UIBarButtonItem(title: "B", style: .plain, target: context.coordinator, action: #selector(Coordinator.tapBold))
        let italic = UIBarButtonItem(title: "I", style: .plain, target: context.coordinator, action: #selector(Coordinator.tapItalic))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let bullet = UIBarButtonItem(title: "•", style: .plain, target: context.coordinator, action: #selector(Coordinator.tapBullet))
        toolbar.setItems([bold, italic, flex, bullet], animated: false)
        
        let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 64))
        accessory.backgroundColor = .clear
        accessory.addSubview(toolbar)
        
        // Layout: inset horizontally and raise buttons a bit from the bottom for comfortable tapping
        let margins = accessory.layoutMarginsGuide
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -8),
            toolbar.bottomAnchor.constraint(equalTo: accessory.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            toolbar.heightAnchor.constraint(equalToConstant: 36)
        ])
        tv.inputAccessoryView = accessory
        context.coordinator.textView = tv
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Normalize any incoming attributed text so it uses the editor's base size from the first character
        let baseFont = uiView.font ?? UIFont.preferredFont(forTextStyle: .body)
        let normalized = normalizeFonts(in: attributedText, base: baseFont)
        if uiView.attributedText != normalized {
            uiView.attributedText = normalized
        }
        uiView.typingAttributes[.font] = baseFont
        if let action = action {
            switch action {
            case .bold: toggleTrait(.traitBold, in: uiView)
            case .italic: toggleTrait(.traitItalic, in: uiView)
            case .bullet: insertBullet(in: uiView)
            }
            DispatchQueue.main.async { self.action = nil }
        }
    }
    
    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in tv: UITextView) {
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        tv.textStorage.beginEditing()
        tv.textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let current = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            var traits = current.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            if let newDesc = current.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: newDesc, size: current.pointSize)
                tv.textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        tv.textStorage.endEditing()
        attributedText = NSMutableAttributedString(attributedString: tv.attributedText)
    }
    
    
    
    private func insertBullet(in tv: UITextView) {
        if let range = tv.selectedTextRange {
            tv.replace(range, withText: (tv.text.isEmpty || tv.text.last == "\n") ? "- " : "\n- ")
        }
        attributedText = NSMutableAttributedString(attributedString: tv.attributedText)
    }
    
    // Apply the base font size to the whole attributed string while preserving bold/italic traits
    private func normalizeFonts(in incoming: NSAttributedString, base: UIFont) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(attributedString: incoming)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var lastIndex = 0
        mutable.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            let currentFont = (attrs[.font] as? UIFont) ?? base
            let traits = currentFont.fontDescriptor.symbolicTraits
            let desc = base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor
            let newFont = UIFont(descriptor: desc, size: base.pointSize)
            mutable.addAttribute(.font, value: newFont, range: range)
            lastIndex = range.location + range.length
        }
        if lastIndex < mutable.length {
            let desc = base.fontDescriptor
            let newFont = UIFont(descriptor: desc, size: base.pointSize)
            mutable.addAttribute(.font, value: newFont, range: NSRange(location: lastIndex, length: mutable.length - lastIndex))
        }
        return mutable
    }
    
    // Markdown conversion helpers
    static func markdownToAttributed(_ markdown: String) -> NSMutableAttributedString {
        if let att = try? NSAttributedString(AttributedString(markdown: markdown)) {
            return NSMutableAttributedString(attributedString: att)
        }
        return NSMutableAttributedString(string: markdown)
    }
    
    static func attributedToMarkdown(_ attributed: NSAttributedString) -> String {
        var result = ""
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, range, _ in
            let substring = (attributed.string as NSString).substring(with: range)
            var open = "", close = ""
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { open += "**"; close = "**" + close }
                if traits.contains(.traitItalic) { open += "*"; close = "*" + close }
            }
            result += open + substring + close
        }
        return result
    }

}
    
    struct MapPickerView: View {
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
    
    struct LocationSelectionView: View {
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
    
    struct SearchResultsView: View {
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

