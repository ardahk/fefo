import SwiftUI
import Inject

struct MyEventsView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    @State private var selectedEvent: FoodEvent?
    
    var eventsGoing: [FoodEvent] {
        viewModel.foodEvents.filter { event in
            event.attendees.contains { attendee in
                attendee.userId == viewModel.currentUser.id &&
                attendee.status == .going
            }
        }
        .sorted { $0.startTime > $1.startTime }
    }

    var eventsPosted: [FoodEvent] {
        viewModel.foodEvents.filter { $0.createdBy == viewModel.currentUser.username }
            .sorted { $0.startTime > $1.startTime }
    }
    
    var body: some View {
        List {
            if !eventsGoing.isEmpty {
                Section("Events You're Going") {
                    ForEach(eventsGoing) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }
            
            if !eventsPosted.isEmpty {
                Section("Events You've Posted") {
                    ForEach(eventsPosted) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }
            
            if eventsGoing.isEmpty && eventsPosted.isEmpty {
                Text("No events to show")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Events")
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .enableInjection()
    }
}

#Preview {
    NavigationView {
        MyEventsView()
            .environmentObject(FoodEventsViewModel())
    }
} 
