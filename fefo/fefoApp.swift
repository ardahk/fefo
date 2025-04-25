//
//  fefoApp.swift
//  fefo
//
//  Created by Arda Hoke on 11/19/24.
//

import SwiftUI
import Inject

// Add orientation lock class
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait // This forces portrait orientation
    }
}

@main
struct fefoApp: App {
    @ObserveInjection var inject
    @StateObject private var viewModel = FoodEventsViewModel()
    
    // Add the delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
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
