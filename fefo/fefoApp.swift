//
//  fefoApp.swift
//  fefo
//
//  Created by Arda Hoke on 11/19/24.
//

import SwiftUI
import Inject
// Firebase imports commented out for demo
// import FirebaseCore
// import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase configuration commented out for demo
        // FirebaseApp.configure()
        // 
        // #if DEBUG
        // Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        // print("🔥 Firebase Auth Emulator enabled - Testing mode!")
        // print("🔗 Emulator UI: http://localhost:4000")
        // #else
        // print("🔥 Using production Firebase")
        // #endif
        
        print("🚀 Running in Demo Mode (Firebase disabled)")
        return true
    }
    
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
                    // Load sample data for demo
                    print("🚀 Loading demo data...")
                    viewModel.loadSampleData()
                }
                .enableInjection()
        }
    }
}
