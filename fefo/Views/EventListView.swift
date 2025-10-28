import SwiftUI
import Inject

struct EventListView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @State private var selectedEvent: FoodEvent?
    
    var groupedEvents: [String: [FoodEvent]] {
        Dictionary(grouping: viewModel.foodEvents) { event in
            formatDate(event.startTime)
        }
    }
    
    var sortedDates: [String] {
        groupedEvents.keys.sorted { date1, date2 in
            // Convert string dates back to Date for comparison
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, EEEE"
            let d1 = formatter.date(from: date1) ?? Date()
            let d2 = formatter.date(from: date2) ?? Date()
            return d1 < d2
        }
    }
    
    var body: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                Section(header: 
                    Text(date == formatDate(Date()) ? "Today" : date)
                        .font(.headline)
                        .foregroundColor(ColorTheme.primary)
                        .textCase(nil)
                ) {
                    ForEach(groupedEvents[date]?.sorted { $0.startTime < $1.startTime } ?? []) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Events")
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .enableInjection()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, EEEE"
        return formatter.string(from: date)
    }
}

struct EventRow: View {
    let event: FoodEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.startTime, style: .time)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                    Text(event.endTime, style: .time)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(width: 70, alignment: .leading)
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 8)
                
                VStack(alignment: .leading, spacing: 6) {
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
                    }
                    
                    Text(event.buildingName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !event.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
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
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        EventListView()
            .environmentObject(FoodEventsViewModel())
    }
} 