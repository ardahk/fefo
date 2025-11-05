import SwiftUI
import Inject
import PhotosUI

struct ProfileView: View {
    @ObserveInjection var inject
    @EnvironmentObject var viewModel: FoodEventsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isEditMode = false
    @State private var editedUsername = ""
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var scrollOffset: CGFloat = 0
    @State private var isExpanded = false
    @State private var stats = FoodEventsViewModel.UserStats(
        eventsPosted: 0,
        eventsAttended: 0,
        commentsMade: 0,
        leaderboardRank: 0,
        points: 0,
        impactScore: 0
    )
    @State private var formattedMemberSince = ""
    @Binding var presentationDetent: PresentationDetent

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section (Always visible)
                    headerSection
                        .padding(.top, 20)
                        .padding(.bottom, 30)

                    // Stats Grid
                    statsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // Expanded Content (visible when scrolled/expanded)
                    if isExpanded {
                        expandedSection
                            .padding(.horizontal, 20)
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                // Auto-expand to large when scrolling up
                if value < -50 && !isExpanded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = true
                        presentationDetent = .large
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primaryGreen)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isExpanded {
                        Button(isEditMode ? "Done" : "Edit") {
                            if isEditMode {
                                saveProfile()
                            }
                            withAnimation {
                                isEditMode.toggle()
                            }
                        }
                        .foregroundColor(ColorTheme.primaryGreen)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            editedUsername = viewModel.currentUser.username
            isExpanded = (presentationDetent == .large)
            stats = viewModel.getUserStats()
            updateFormattedDate()
        }
        .onChange(of: presentationDetent) { oldValue, newValue in
            isExpanded = (newValue == .large)
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    viewModel.updateProfileImage(data)
                }
            }
        }
        .enableInjection()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Profile Picture
            Button(action: {
                if isEditMode {
                    showingImagePicker = true
                }
            }) {
                ZStack {
                    if let imageData = viewModel.currentUser.profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        // Color-coded avatar with initials
                        Circle()
                            .fill(viewModel.currentUser.avatarColor.gradient)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Text(viewModel.currentUser.initials)
                                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                    }

                    if isEditMode {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 100, height: 100)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
            .disabled(!isEditMode)

            // Username
            if isEditMode {
                TextField("Username", text: $editedUsername)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .textFieldStyle(.plain)
            } else {
                Text(viewModel.currentUser.username)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.darkGray)
            }

            // Member Since Badge
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                Text("Member since \(formattedMemberSince)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(ColorTheme.softGray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.darkGray)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                StatCard(
                    icon: "calendar.badge.plus",
                    title: "Events Posted",
                    value: "\(stats.eventsPosted)",
                    color: ColorTheme.primaryGreen
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    title: "Events Attended",
                    value: "\(stats.eventsAttended)",
                    color: .blue
                )

                StatCard(
                    icon: "bubble.left.fill",
                    title: "Comments",
                    value: "\(stats.commentsMade)",
                    color: .purple
                )

                StatCard(
                    icon: "trophy.fill",
                    title: "Leaderboard Rank",
                    value: stats.leaderboardRank > 0 ? "#\(stats.leaderboardRank)" : "-",
                    color: .orange
                )

                StatCard(
                    icon: "star.fill",
                    title: "Points",
                    value: "\(stats.points)",
                    color: .yellow
                )

                StatCard(
                    icon: "person.3.fill",
                    title: "Impact Score",
                    value: "\(stats.impactScore)",
                    color: .pink
                )
            }
        }
    }

    // MARK: - Expanded Section
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.vertical, 8)

            // Recent Activity
            Text("Recent Activity")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.darkGray)
                .padding(.horizontal, 4)

            if viewModel.userRecentEvents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(ColorTheme.softGray)
                        Text("No recent events")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorTheme.softGray)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.userRecentEvents.prefix(5)) { event in
                        RecentEventRow(event: event)
                    }
                }
            }

            // Account Section
            if isEditMode {
                Divider()
                    .padding(.vertical, 8)

                Text("Account")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(ColorTheme.darkGray)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    HStack {
                        Text("Email")
                            .foregroundColor(ColorTheme.softGray)
                        Spacer()
                        Text(viewModel.currentUser.email)
                            .foregroundColor(ColorTheme.darkGray)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))

                    Divider()
                        .padding(.leading, 16)

                    HStack {
                        Text("User ID")
                            .foregroundColor(ColorTheme.softGray)
                        Spacer()
                        Text(viewModel.currentUser.id.uuidString.prefix(8).uppercased())
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ColorTheme.darkGray)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                }
                .cornerRadius(12)
            }

            Spacer(minLength: 40)
        }
    }

    // MARK: - Actions
    private func updateFormattedDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formattedMemberSince = formatter.string(from: viewModel.currentUser.memberSince)
    }
    
    private func saveProfile() {
        viewModel.updateUsername(editedUsername)
        // Refresh stats after username update
        stats = viewModel.getUserStats()
    }
    
    private func refreshStats() {
        stats = viewModel.getUserStats()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.darkGray)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTheme.softGray)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct RecentEventRow: View {
    let event: FoodEvent

    var body: some View {
        HStack(spacing: 12) {
            // Event icon based on first tag
            Circle()
                .fill(event.tags.first?.color.gradient ?? ColorTheme.primaryGreen.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: event.tags.first?.icon ?? "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTheme.darkGray)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(event.buildingName, systemImage: "mappin.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.softGray)
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(ColorTheme.softGray)

                    Text(formattedDate(event.startTime))
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.softGray)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTheme.softGray)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


// MARK: - Preview
#Preview {
    ProfileView(presentationDetent: .constant(.medium))
        .environmentObject(FoodEventsViewModel())
}
