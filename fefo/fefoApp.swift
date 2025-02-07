//
//  fefoApp.swift
//  fefo
//
//  Created by Arda Hoke on 11/19/24.
//

import SwiftUI
import Inject

@main
struct fefoApp: App {
    @ObserveInjection var inject
    @StateObject private var viewModel = FoodEventsViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.loadSampleData()
                }
                .enableInjection()
        }
    }
}
