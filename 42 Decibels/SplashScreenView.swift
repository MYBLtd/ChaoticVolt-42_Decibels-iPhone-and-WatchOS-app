//
//  SplashScreenView.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            // ChaoticVolt Logo
            Image("ChaoticVoltLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Logo fade in and scale up
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
        }
        
        // Dismiss splash screen after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash screen complete")
    }
}
