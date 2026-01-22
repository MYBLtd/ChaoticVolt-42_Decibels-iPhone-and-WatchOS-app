//
//  _2_DecibelsApp.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI

@main
struct _2_DecibelsApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
