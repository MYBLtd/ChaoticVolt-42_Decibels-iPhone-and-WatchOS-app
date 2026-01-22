//
//  ContentView.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI
import CoreBluetooth
import Combine

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingScanSheet = false
    @State private var dontPanicMode = false
    @State private var panicModeTimer: Timer?
    @State private var currentTime = Date()  // For updating Last Contact display
    @State private var isDetailedStatusExpanded = true  // Expanded by default
    
    // Timer to refresh the Last Contact display every second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Orange overlay when in Audio Duck mode
            if dontPanicMode {
                Color.orange.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            navigationContent
        }
        .animation(.easeInOut(duration: 0.3), value: dontPanicMode)
        .onReceive(timer) { _ in
            // Update currentTime to trigger UI refresh for Last Contact
            currentTime = Date()
        }
    }
    
    // MARK: - Navigation Content
    
    private var navigationContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Galactic Status (when connected and available)
                    if case .connected = bluetoothManager.connectionState,
                       let galacticStatus = bluetoothManager.galacticStatus {
                        
                        // Interactive Shield Status Pills (TOP ROW)
                        shieldStatusPills(status: galacticStatus)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // DSP Preset Selection (SECOND ROW)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("DSP Mode", systemImage: "waveform")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(BluetoothManager.DSPPreset.allCases, id: \.self) { preset in
                                    PresetButton(
                                        preset: preset,
                                        isSelected: bluetoothManager.currentPreset == preset
                                    ) {
                                        bluetoothManager.setPreset(preset)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Collapsible detailed status (THIRD ROW)
                        DisclosureGroup(isExpanded: $isDetailedStatusExpanded) {
                            VStack(spacing: 12) {
                                // Quantum Flavor (Preset) + Last Contact - Combined Row
                                HStack(spacing: 16) {
                                    // Quantum Flavor (Left side)
                                    HStack(spacing: 8) {
                                        Image(systemName: presetIcon(galacticStatus.preset))
                                            .font(.title3)
                                            .foregroundStyle(.purple)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Quantum Flavor")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text(galacticStatus.preset?.rawValue ?? "UNKNOWN")
                                                .font(.headline)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Divider()
                                        .frame(height: 40)
                                    
                                    // Last Contact (Right side)
                                    HStack(spacing: 8) {
                                        Image(systemName: lastContactIcon(galacticStatus))
                                            .font(.title3)
                                            .foregroundStyle(lastContactColor(galacticStatus))
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Last Contact")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text(lastContactText(galacticStatus))
                                                .font(.headline)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                // Optional: Energy/Volume/Battery
                                if galacticStatus.energyCoreLevel > 0 || galacticStatus.distortionFieldStrength > 0 || galacticStatus.energyCore > 0 {
                                    Divider()
                                    
                                    if galacticStatus.energyCoreLevel > 0 {
                                        compactMeter(title: "Energy Core", value: galacticStatus.energyCoreLevel, color: .yellow, icon: "bolt.fill")
                                    }
                                    
                                    if galacticStatus.distortionFieldStrength > 0 {
                                        compactMeter(title: "Distortion Field", value: galacticStatus.distortionFieldStrength, color: .orange, icon: "waveform")
                                    }
                                    
                                    if galacticStatus.energyCore > 0 {
                                        compactMeter(title: "Battery", value: galacticStatus.energyCore, color: .green, icon: "battery.100")
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.cyan)
                                Text("Detailed Status")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)
                        .tint(.cyan)
                        
                        // Audio Duck Mode Indicator (when active)
                        if dontPanicMode {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.path.badge.minus")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AUDIO DUCK MODE")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                    
                                    Text("Volume reduced to 25%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    toggleDontPanicMode()
                                } label: {
                                    Text("Disable")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Connection Status (BOTTOM ROW)
                        connectionStatusView
                    }
                    
                    if case .connected = bluetoothManager.connectionState {
                        // Empty - all controls are now above
                    } else {
                        // Not connected message
                        VStack(spacing: 16) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            
                            Text("No Speaker Connected")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Connect to your Bluetooth speaker to control DSP settings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if case .connected = bluetoothManager.connectionState {
                            bluetoothManager.disconnect()
                        } else {
                            showingScanSheet = true
                        }
                    } label: {
                        if case .connected = bluetoothManager.connectionState {
                            Label("Disconnect", systemImage: "xmark.circle")
                        } else {
                            Label("Connect", systemImage: "plus.circle")
                        }
                    }
                }
                
                // Quick Duck button (only visible when connected)
                if case .connected = bluetoothManager.connectionState {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            toggleDontPanicMode()
                        } label: {
                            Label("Quick Duck", systemImage: dontPanicMode ? "speaker.wave.1" : "waveform.path.badge.minus")
                        }
                        .tint(dontPanicMode ? .orange : .primary)
                    }
                }
            }
            .sheet(isPresented: $showingScanSheet) {
                ScannerView(bluetoothManager: bluetoothManager, isPresented: $showingScanSheet)
            }
        }
    }
    
    // MARK: - Don't Panic Mode
    
    private func toggleDontPanicMode() {
        dontPanicMode.toggle()
        
        // Cancel existing timer if any
        panicModeTimer?.invalidate()
        
        if dontPanicMode {
            // Activate audio duck mode: reduce volume temporarily
            bluetoothManager.setAudioDuck(true)
        } else {
            // Deactivate audio duck mode: restore normal volume
            bluetoothManager.setAudioDuck(false)
        }
    }
    
    // MARK: - Connection Status View
    
    @ViewBuilder
    private var connectionStatusView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                
                if let speakerName = bluetoothManager.connectedSpeaker?.name {
                    Text(speakerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var statusColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
    
    private var statusTitle: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .scanning:
            return "Scanning..."
        case .error(let message):
            return message
        case .disconnected:
            return "Disconnected"
        }
    }
    
    // MARK: - Shield Status Pills
    
    @ViewBuilder
    private func shieldStatusPills(status: BluetoothManager.GalacticStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.cyan)
                Text("Shield Status")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Live indicator when status is fresh
                if status.secondsSinceReceived < 3 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                }
            }
            
            HStack(spacing: 12) {
                // Mute pill - interactive!
                Button {
                    bluetoothManager.setMute(!status.shieldStatus.isMuted)
                } label: {
                    StatusPillCompact(
                        title: "Mute",
                        isActive: status.shieldStatus.isMuted,
                        icon: "speaker.slash.fill",
                        activeColor: .red
                    )
                }
                .buttonStyle(.plain)
                
                // Audio Duck pill (Panic Mode) - interactive!
                Button {
                    bluetoothManager.setAudioDuck(!status.shieldStatus.isPanicMode)
                } label: {
                    StatusPillCompact(
                        title: "Duck",
                        isActive: status.shieldStatus.isPanicMode,
                        icon: "waveform.path.badge.minus",
                        activeColor: .orange
                    )
                }
                .buttonStyle(.plain)
                
                // Loudness pill - interactive!
                Button {
                    bluetoothManager.setLoudness(enabled: !status.shieldStatus.isLoudnessOn)
                } label: {
                    StatusPillCompact(
                        title: "Loudness",
                        isActive: status.shieldStatus.isLoudnessOn,
                        icon: "speaker.wave.3",
                        activeColor: .blue
                    )
                }
                .buttonStyle(.plain)
                
                // Normalizer pill (Limiter) - interactive!
                Button {
                    bluetoothManager.setNormalizer(!status.shieldStatus.isLimiterActive)
                } label: {
                    StatusPillCompact(
                        title: "Normalize",
                        isActive: status.shieldStatus.isLimiterActive,
                        icon: "waveform.path.ecg",
                        activeColor: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions for Galactic Status
    
    private func presetIcon(_ preset: BluetoothManager.DSPPreset?) -> String {
        switch preset {
        case .office: return "building.2"
        case .full: return "speaker.wave.3"
        case .night: return "moon.stars"
        case .speech: return "person.wave.2"
        case .none: return "questionmark.circle"
        }
    }
    
    private func lastContactText(_ galacticStatus: BluetoothManager.GalacticStatus) -> String {
        // Use iOS-side timestamp for more accurate tracking
        let sec = galacticStatus.secondsSinceReceived
        
        if sec == 0 {
            return "Just now"
        } else if sec == 1 {
            return "1 second ago"
        } else if sec < 60 {
            return "\(sec) seconds ago"
        } else if sec >= 240 {
            return ">4 minutes ago"
        } else {
            let minutes = sec / 60
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
    }
    
    private func lastContactIcon(_ galacticStatus: BluetoothManager.GalacticStatus) -> String {
        let sec = galacticStatus.secondsSinceReceived
        
        if sec == 0 {
            return "checkmark.circle.fill"
        } else if sec < 5 {
            return "clock.fill"
        } else if sec < 30 {
            return "clock"
        } else {
            return "clock.badge.exclamationmark"
        }
    }
    
    private func lastContactColor(_ galacticStatus: BluetoothManager.GalacticStatus) -> Color {
        let sec = galacticStatus.secondsSinceReceived
        
        if sec == 0 {
            return .green
        } else if sec < 5 {
            return .blue
        } else if sec < 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    @ViewBuilder
    private func compactMeter(title: String, value: UInt8, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .font(.caption)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100.0, height: 4)
                }
            }
            .frame(height: 4)
            
            Text("\(value)%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
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
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 30)
                
                Text(preset.rawValue)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Pill Compact

struct StatusPillCompact: View {
    let title: String
    let isActive: Bool
    let icon: String
    let activeColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isActive ? activeColor : .secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(isActive ? activeColor : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? activeColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? activeColor : Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Scanner View

struct ScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if bluetoothManager.discoveredSpeakers.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Scanning for Bluetooth devices...")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Make sure your speaker is powered on and in pairing mode")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(bluetoothManager.discoveredSpeakers, id: \.identifier) { peripheral in
                        Button {
                            bluetoothManager.connect(to: peripheral)
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    
                                    Text(peripheral.identifier.uuidString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        bluetoothManager.stopScanning()
                        isPresented = false
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
    ContentView()
}
