//
//  WatchContentView.swift
//  42 Decibels Watch App
//
//  Created by Robin on 2026-01-25.
//  Updated for hybrid mode on 2026-01-28.
//

import SwiftUI
import CoreBluetooth
import Combine

struct WatchContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var watchConnectivity = WatchConnectivityManager()
    
    @State private var showingScanSheet = false
    @State private var currentTime = Date()
    @State private var connectionMode: ConnectionMode = .determining
    
    // Timer to refresh the Last Contact display
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum ConnectionMode {
        case determining           // Initial state, checking iPhone
        case viaPhone             // iPhone is connected, use it as proxy
        case direct               // Connect directly to speaker
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Connection mode indicator
                    connectionModeIndicator
                    
                    if connectionMode == .viaPhone,
                       let phoneConnectionInfo = watchConnectivity.counterpartConnectionState,
                       phoneConnectionInfo.isConnected {
                        // Phone is connected - show proxy controls
                        connectedViaPhoneView(speakerName: phoneConnectionInfo.speakerName ?? "Unknown")
                    } else if case .connected = bluetoothManager.connectionState,
                              let galacticStatus = bluetoothManager.galacticStatus {
                        // Direct connection - show direct controls
                        connectedDirectView(galacticStatus: galacticStatus)
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
        .onAppear {
            setupHybridMode()
        }
        .onChange(of: watchConnectivity.counterpartConnectionState) { newState in
            updateConnectionMode()
        }
        .onChange(of: watchConnectivity.isPhoneReachable) { isReachable in
            if isReachable {
                watchConnectivity.requestConnectionState()
            }
            updateConnectionMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receivedGalacticStatusFromPhone)) { notification in
            // Update UI with status from phone
            // (BluetoothManager will handle this internally)
        }
    }
    
    // MARK: - Setup
    
    private func setupHybridMode() {
        // First, check if iPhone is reachable and connected
        if watchConnectivity.isPhoneReachable {
            watchConnectivity.requestConnectionState()
        }
        
        // After a short delay, if no phone connection, allow direct mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            updateConnectionMode()
        }
    }
    
    private func updateConnectionMode() {
        if let phoneState = watchConnectivity.counterpartConnectionState,
           phoneState.isConnected,
           watchConnectivity.isPhoneReachable {
            // iPhone is connected and reachable
            connectionMode = .viaPhone
            
            // Disconnect direct connection if we have one
            if case .connected = bluetoothManager.connectionState {
                bluetoothManager.disconnect()
            }
        } else if case .connected = bluetoothManager.connectionState {
            // We have a direct connection
            connectionMode = .direct
        } else {
            // No connection
            connectionMode = .direct // Allow direct scanning
        }
    }
    
    // MARK: - Connection Mode Indicator
    
    @ViewBuilder
    private var connectionModeIndicator: some View {
        if connectionMode == .viaPhone {
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                Text("via iPhone")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.cyan.opacity(0.2))
            .cornerRadius(4)
        } else if connectionMode == .direct {
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                Text("direct")
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.2))
            .cornerRadius(4)
        }
    }
    
    // MARK: - Connected Via Phone View
    
    @ViewBuilder
    private func connectedViaPhoneView(speakerName: String) -> some View {
        // Device name
        VStack(spacing: 4) {
            Text(speakerName)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Live indicator (always show as live when via phone)
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                Text("Live")
                    .font(.caption2)
                    .foregroundStyle(.green)
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
                    sendCommandViaPhone(.setPreset, data: preset.commandData)
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Quick Controls (sending commands via phone)
        quickControlsView(
            isMuted: bluetoothManager.galacticStatus?.shieldStatus.isMuted ?? false,
            isPanicMode: bluetoothManager.galacticStatus?.shieldStatus.isPanicMode ?? false,
            isLoudnessOn: bluetoothManager.galacticStatus?.shieldStatus.isLoudnessOn ?? false,
            isLimiterActive: bluetoothManager.galacticStatus?.shieldStatus.isLimiterActive ?? false,
            isBypassActive: bluetoothManager.galacticStatus?.shieldStatus.isBypassActive ?? false,
            isBassBoostActive: bluetoothManager.galacticStatus?.shieldStatus.isBassBoostActive ?? false,
            viaPhone: true
        )
    }
    
    // MARK: - Connected Direct View
    
    @ViewBuilder
    private func connectedDirectView(galacticStatus: BluetoothManager.GalacticStatus) -> some View {
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
        
        // Quick Controls (direct)
        quickControlsView(
            isMuted: galacticStatus.shieldStatus.isMuted,
            isPanicMode: galacticStatus.shieldStatus.isPanicMode,
            isLoudnessOn: galacticStatus.shieldStatus.isLoudnessOn,
            isLimiterActive: galacticStatus.shieldStatus.isLimiterActive,
            isBypassActive: galacticStatus.shieldStatus.isBypassActive,
            isBassBoostActive: galacticStatus.shieldStatus.isBassBoostActive,
            viaPhone: false
        )
        
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
    
    // MARK: - Quick Controls View (Shared)
    
    @ViewBuilder
    private func quickControlsView(
        isMuted: Bool,
        isPanicMode: Bool,
        isLoudnessOn: Bool,
        isLimiterActive: Bool,
        isBypassActive: Bool,
        isBassBoostActive: Bool,
        viaPhone: Bool
    ) -> some View {
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
                    isActive: isMuted,
                    color: .red
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setMute, data: Data([0x04, isMuted ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setMute(!isMuted)
                    }
                }
                
                WatchControlButton(
                    title: "Duck",
                    icon: "waveform.path.badge.minus",
                    isActive: isPanicMode,
                    color: .orange
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setAudioDuck, data: Data([0x05, isPanicMode ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setAudioDuck(!isPanicMode)
                    }
                }
            }
            
            // Loudness & Normalizer
            HStack(spacing: 6) {
                WatchControlButton(
                    title: "Loudness",
                    icon: "speaker.wave.3",
                    isActive: isLoudnessOn,
                    color: .blue
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setLoudness, data: Data([0x02, isLoudnessOn ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setLoudness(enabled: !isLoudnessOn)
                    }
                }
                
                WatchControlButton(
                    title: "Normalize",
                    icon: "waveform.path.ecg",
                    isActive: isLimiterActive,
                    color: .green
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setNormalizer, data: Data([0x06, isLimiterActive ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setNormalizer(!isLimiterActive)
                    }
                }
            }
            
            // Bypass & Bass Boost
            HStack(spacing: 6) {
                WatchControlButton(
                    title: "Bypass",
                    icon: "arrow.triangle.turn.up.right.circle",
                    isActive: isBypassActive,
                    color: .purple
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setBypass, data: Data([0x08, isBypassActive ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setBypass(!isBypassActive)
                    }
                }
                
                WatchControlButton(
                    title: "Bass boost",
                    icon: "waveform.badge.magnifyingglass",
                    isActive: isBassBoostActive,
                    color: .indigo
                ) {
                    if viaPhone {
                        sendCommandViaPhone(.setBassBoost, data: Data([0x09, isBassBoostActive ? 0x00 : 0x01]))
                    } else {
                        bluetoothManager.setBassBoost(!isBassBoostActive)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Disconnected View
    
    @ViewBuilder
    private var disconnectedView: some View {
        VStack(spacing: 12) {
            if connectionMode == .determining {
                ProgressView()
                    .padding(.top, 20)
                Text("Checking iPhone...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                Text("No Speaker")
                    .font(.headline)
                
                if watchConnectivity.isPhoneReachable {
                    Text("iPhone is nearby but not connected to speaker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Connect directly or check iPhone connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    showingScanSheet = true
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .font(.footnote)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding()
    }
    
    // MARK: - Connection Button
    
    @ViewBuilder
    private var connectionButton: some View {
        if connectionMode == .viaPhone {
            // Can't disconnect from watch when using phone
            EmptyView()
        } else if case .connected = bluetoothManager.connectionState {
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
    
    // MARK: - Helper Methods
    
    private func sendCommandViaPhone(_ type: WatchConnectivityManager.CommandType, data: Data) {
        watchConnectivity.sendCommand(type: type, data: data)
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
