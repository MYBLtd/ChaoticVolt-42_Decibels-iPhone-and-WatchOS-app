//
//  SplashScreenView.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var towelOffset: CGFloat = 0
    @State private var towelRotation: Double = 0
    @State private var bluetoothOpacity: Double = 0
    @State private var towelOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient - space theme
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Stars
            StarsView()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Main logo area
                ZStack {
                    // Bluetooth symbol
                    Image(systemName: "bluetoothlogo")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(bluetoothOpacity)
                        .scaleEffect(bluetoothOpacity)
                    
                    // Floating towel
                    TowelView()
                        .offset(y: towelOffset)
                        .rotationEffect(.degrees(towelRotation))
                        .opacity(towelOpacity)
                }
                .frame(height: 200)
                
                // Title
                VStack(spacing: 12) {
                    Text("42 Decibels")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)
                    
                    Text("Don't Panic")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                
                // Footer text
                Text("A towel is about the most massively useful thing...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(subtitleOpacity)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Bluetooth logo appears
        withAnimation(.easeOut(duration: 0.8)) {
            bluetoothOpacity = 1
        }
        
        // Towel appears and starts floating
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            towelOpacity = 1
        }
        
        // Continuous floating animation
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            towelOffset = -15
        }
        
        // Gentle rotation
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            towelRotation = 5
        }
        
        // Title appears
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            titleOpacity = 1
        }
        
        // Subtitle appears
        withAnimation(.easeOut(duration: 0.8).delay(1.3)) {
            subtitleOpacity = 1
        }
        
        // Dismiss splash screen after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                onComplete()
            }
        }
    }
}

// MARK: - Towel View

struct TowelView: View {
    var body: some View {
        ZStack {
            // Towel shape with texture
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.3, blue: 0.3),
                            Color(red: 0.8, green: 0.2, blue: 0.2),
                            Color(red: 0.9, green: 0.3, blue: 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 120)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 5)
            
            // Towel stripes for texture
            VStack(spacing: 10) {
                ForEach(0..<4) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 70, height: 3)
                }
            }
            
            // Fold line
            Path { path in
                path.move(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 120))
            }
            .stroke(Color.black.opacity(0.2), lineWidth: 2)
        }
        .rotation3DEffect(
            .degrees(10),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
    }
}

// MARK: - Stars Background

struct StarsView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(
                        width: CGFloat.random(in: 1...3),
                        height: CGFloat.random(in: 1...3)
                    )
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView {
        print("Splash screen complete")
    }
}
