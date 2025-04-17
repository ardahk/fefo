import SwiftUI
import Inject
import MapKit

struct EventDetailView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    
    let event: FoodEvent
    @State private var newComment = ""
    @State private var selectedAttendance: FoodEvent.AttendanceStatus?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Event Info
                    eventInfoSection
                    
                    // Tags Section
                    if !event.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(event.tags, id: \.self) { tag in
                                    Text(tag.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(tag.color.opacity(0.2))
                                        )
                                        .foregroundColor(tag.color)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                    
                    // Attendance Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Are you going?")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            AttendanceButton(
                                title: "Going",
                                systemImage: "checkmark.circle.fill",
                                color: .green,
                                isSelected: selectedAttendance == .going
                            ) {
                                selectedAttendance = .going
                            }
                            
                            AttendanceButton(
                                title: "Maybe",
                                systemImage: "questionmark.circle.fill",
                                color: .orange,
                                isSelected: selectedAttendance == .maybe
                            ) {
                                selectedAttendance = .maybe
                            }
                            
                            AttendanceButton(
                                title: "Not Going",
                                systemImage: "xmark.circle.fill",
                                color: .red,
                                isSelected: selectedAttendance == .notGoing
                            ) {
                                selectedAttendance = .notGoing
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Location
                    locationSection
                    
                    Divider()
                    
                    // Comments
                    commentsSection
                }
                .padding()
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    statusBadge
                }
            }
        }
        .enableInjection()
    }
    
    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.description)
                .font(.body)
            
            HStack {
                Label {
                    Text(event.startTime, style: .time)
                } icon: {
                    Image(systemName: "clock")
                }
                
                Text("-")
                
                Text(event.endTime, style: .time)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "person.fill")
                Text("Posted by \(event.createdBy)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
            
            HStack {
                Image(systemName: "building.2.fill")
                Text(event.buildingName)
            }
            .font(.subheadline)
            
            // Mini map preview with pin and campus boundaries
            let clampedCenter = CLLocationCoordinate2D(
                latitude: min(max(event.location.latitude, 37.8631), 37.8791),
                longitude: min(max(event.location.longitude, -122.2691), -122.2495)
            )
            let previewRegion = MKCoordinateRegion(
                center: clampedCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            
            Map(position: .constant(.region(previewRegion))) {
                // Add campus boundary polygon
                MapPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2691), // Northwest
                    CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2495), // Northeast
                    CLLocationCoordinate2D(latitude: 37.8631, longitude: -122.2495), // Southeast
                    CLLocationCoordinate2D(latitude: 37.8631, longitude: -122.2691), // Southwest
                    CLLocationCoordinate2D(latitude: 37.8791, longitude: -122.2691)  // Back to start
                ])
                .stroke(.blue.opacity(0.8), lineWidth: 2)
                .foregroundStyle(.blue.opacity(0.1))
                
                // Add marker for event location
                Annotation(event.title, coordinate: event.location) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title)
                }
            }
            .mapStyle(.standard)
            .allowsHitTesting(false)
            .frame(height: 150)
            .cornerRadius(12)
        }
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
            
            if event.comments.isEmpty {
                Text("No comments yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(event.comments) { comment in
                    commentView(for: comment)
                }
            }
            
            // Add comment field
            HStack {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    submitComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func commentView(for comment: FoodEvent.Comment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(comment.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.text)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var statusBadge: some View {
        Text(event.statusInfo.text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(event.statusInfo.color.opacity(0.2))
            .foregroundColor(event.statusInfo.color)
            .cornerRadius(8)
    }
    
    private func submitComment() {
        let trimmedComment = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }
        
        viewModel.addComment(to: event.id, text: trimmedComment)
        newComment = ""
    }
}

// Attendance Button Component
struct AttendanceButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? color : .secondary)
        }
    }
}

#Preview {
    EventDetailView(event: FoodEvent(
        id: UUID(),
        title: "Free Pizza",
        description: "Pizza in the CS building lobby",
        location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        buildingName: "CS Building",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        createdBy: "Anonymous",
        isActive: true,
        comments: [],
        tags: [.freeFood, .social],
        attendees: []
    ))
    .environmentObject(FoodEventsViewModel())
} 