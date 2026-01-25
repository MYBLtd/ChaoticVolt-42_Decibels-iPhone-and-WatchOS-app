//
//  WatchContentView.swift
//  42 Decibels Watch App
//
//  Created by Robin on 2026-01-25.
//

import SwiftUI
import CoreBluetooth
import Combine

struct WatchContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingScanSheet = false
    @State private var currentTime = Date()
    @State private var isInitialized = false
    
    // Timer to refresh the Last Contact display
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if case .connected = bluetoothManager.connectionState,
                       let galacticStatus = bluetoothManager.galacticStatus {
                        // Connected - show controls
                        connectedView(galacticStatus: galacticStatus)
                    } else {
                        // Not connected
                        disconnectedView
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("42 Decibels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionButton
                }
            }
            .sheet(isPresented: $showingScanSheet) {
                WatchScannerView(bluetoothManager: bluetoothManager, isPresented: $showingScanSheet)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Connected View
    
    @ViewBuilder
    private func connectedView(galacticStatus: BluetoothManager.GalacticStatus) -> some View {
        // Device name
        VStack(spacing: 4) {
            Text(bluetoothManager.connectedSpeaker?.name ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Live indicator
            if galacticStatus.secondsSinceReceived < 3 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                    Text("Live")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.bottom, 4)
        
        // DSP Presets
        VStack(alignment: .leading, spacing: 8) {
            Text("DSP Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            ForEach(BluetoothManager.DSPPreset.allCases, id: \.self) { preset in
                WatchPresetButton(
                    preset: preset,
                    isSelected: bluetoothManager.currentPreset == preset
                ) {
                    bluetoothManager.setPreset(preset)
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Quick Controls
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Controls")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            // Mute & Audio Duck
            HStack(spacing: 6) {
                WatchControlButton(
                    title: "Mute",
                    icon: "speaker.slash.fill",
                    isActive: galacticStatus.shieldStatus.isMuted,
                    color: .red
                ) {
                    bluetoothManager.setMute(!galacticStatus.shieldStatus.isMuted)
                }
                
                WatchControlButton(
                    title: "Duck",
                    icon: "waveform.path.badge.minus",
                    isActive: galacticStatus.shieldStatus.isPanicMode,
                    color: .orange
                ) {
                    bluetoothManager.setAudioDuck(!galacticStatus.shieldStatus.isPanicMode)
                }
            }
            
            // Loudness & Normalizer
            HStack(spacing: 6) {
                WatchControlButton(
                    title: "Loudness",
                    icon: "speaker.wave.3",
                    isActive: galacticStatus.shieldStatus.isLoudnessOn,
                    color: .blue
                ) {
                    bluetoothManager.setLoudness(enabled: !galacticStatus.shieldStatus.isLoudnessOn)
                }
                
                WatchControlButton(
                    title: "Normalize",
                    icon: "waveform.path.ecg",
                    isActive: galacticStatus.shieldStatus.isLimiterActive,
                    color: .green
                ) {
                    bluetoothManager.setNormalizer(!galacticStatus.shieldStatus.isLimiterActive)
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Status Info
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                Text("Volume")
                    .font(.caption2)
                Spacer()
                Text("\(galacticStatus.effectiveVolume)%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            if let capDescription = galacticStatus.volumeCapDescription {
                Text(capDescription)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Disconnected View
    
    @ViewBuilder
    private var disconnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .padding(.top, 20)
            
            Text("No Speaker")
                .font(.headline)
            
            Text("Connect to your Bluetooth speaker")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingScanSheet = true
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
                    .font(.footnote)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Connection Button
    
    @ViewBuilder
    private var connectionButton: some View {
        if case .connected = bluetoothManager.connectionState {
            Button {
                bluetoothManager.disconnect()
            } label: {
                Image(systemName: "xmark.circle")
            }
        } else {
            Button {
                showingScanSheet = true
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }
}

// MARK: - Watch Preset Button

struct WatchPresetButton: View {
    let preset: BluetoothManager.DSPPreset
    let isSelected: Bool
    let action: () -> Void
    
    private var icon: String {
        switch preset {
        case .office: return "building.2"
        case .full: return "speaker.wave.3"
        case .night: return "moon.stars"
        case .speech: return "person.wave.2"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .frame(width: 16)
                
                Text(preset.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watch Control Button

struct WatchControlButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isActive ? color : .secondary)
                
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? color.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? color : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watch Scanner View

struct WatchScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if bluetoothManager.discoveredSpeakers.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(bluetoothManager.discoveredSpeakers, id: \.identifier) { peripheral in
                            Button {
                                bluetoothManager.connect(to: peripheral)
                                isPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peripheral.name ?? "Unknown")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    Text(peripheral.identifier.uuidString.prefix(8))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle("Select Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        bluetoothManager.stopScanning()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                bluetoothManager.startScanning()
            }
            .onDisappear {
                bluetoothManager.stopScanning()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
