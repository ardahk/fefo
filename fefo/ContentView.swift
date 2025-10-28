//
//  ContentView.swift
//  fefo
//
//  Created by Arda Hoke on 11/19/24.
//

import SwiftUI
import Inject
import MapKit

struct ContentView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = FoodEventsViewModel()
    @State private var showingAddEvent = false
    @State private var selectedTab = 0
    @State private var showingProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map Tab
            MapView(showingProfile: $showingProfile)
                .tag(0)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            // Events Tab
            NavigationView {
                EventListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("FeFo")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorTheme.primary)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingProfile = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(ColorTheme.primary)
                            }
                        }
                    }
            }
            .tag(1)
            .tabItem {
                Label("Events", systemImage: "calendar")
            }
            
            // Add Event Tab (visible only when not on map)
            if selectedTab != 0 {
                Color.clear
                    .tag(2)
                    .tabItem {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
            }
            
            // My Events Tab
            NavigationView {
                MyEventsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("FeFo")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorTheme.primary)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingProfile = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(ColorTheme.primary)
                            }
                        }
                    }
            }
            .tag(3)
            .tabItem {
                Label("My Events", systemImage: "list.bullet")
            }
            
            // Leaderboard Tab
            NavigationView {
                LeaderboardView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("FeFo")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorTheme.primary)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingProfile = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(ColorTheme.primary)
                            }
                        }
                    }
            }
            .tag(4)
            .tabItem {
                Label("Top", systemImage: "trophy")
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                withAnimation {
                    showingAddEvent = true
                    selectedTab = max(0, selectedTab - 1)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == 0 {
                AddEventButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingAddEvent = true
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.1)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8)),
                        removal: .scale(scale: 0.1)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8))
                    )
                )
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
        }
        // Add profile sheet here (to be implemented)
        .sheet(isPresented: $showingProfile) {
            Text("Profile View - Coming Soon")
                .presentationDetents([.medium])
        }
        .environmentObject(viewModel)
        .enableInjection()
    }
}

struct AddEventButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(ColorTheme.primary)
                .background(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
        }
        .padding(.bottom, 64)
        .padding()
        .accessibilityLabel("Add New Event")
    }
}

#Preview {
    ContentView()
        .environmentObject(FoodEventsViewModel())
}
