//
//  ContentView.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingScanSheet = false
    @State private var dontPanicMode = false
    @State private var panicModeTimer: Timer?
    @State private var currentTime = Date()  // For updating Last Contact display
    @State private var isDetailedStatusExpanded = true  // Expanded by default
    
    // ChaoticVolt brand color
    private let brandPurple = Color(hex: "6F4CFF")
    
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
            VStack(spacing: 0) {
                // Branded Header with Logo and Device Info
                brandedHeader
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Galactic Status (when connected and available)
                        if case .connected = bluetoothManager.connectionState,
                           let galacticStatus = bluetoothManager.galacticStatus {
                        
                        // Interactive Shield Status Pills (TOP ROW)
                        shieldStatusPills(status: galacticStatus)
                            .padding(.horizontal)
                        
                        // DSP Preset Selection (SECOND ROW)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("DSP Mode", systemImage: "waveform")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(BluetoothManager.DSPPreset.allCases, id: \.self) { preset in
                                    PresetButton(
                                        preset: preset,
                                        isSelected: bluetoothManager.currentPreset == preset,
                                        brandColor: brandPurple
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
                                
                                Divider()
                                
                                // System Volume (informational only - per FSD 10.1)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.title3)
                                            .foregroundStyle(.cyan)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("System Volume")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("\(galacticStatus.effectiveVolume)%")
                                                .font(.headline)
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    // Show volume cap information if applicable
                                    if let capDescription = galacticStatus.volumeCapDescription {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                            
                                            Text(capDescription)
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                        .padding(.leading, 38)
                                    }
                                    
                                    // Show "Safe headroom active" if normalizer is limiting
                                    if galacticStatus.shieldStatus.isLimiterActive {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.shield")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                            
                                            Text("Safe headroom active")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.leading, 38)
                                    }
                                    
                                    Text("Control volume with iPhone buttons")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 38)
                                }
                                
                                // Optional: Energy/Volume/Battery
                                if galacticStatus.energyCoreLevel > 0 || galacticStatus.energyCore > 0 {
                                    Divider()
                                    
                                    if galacticStatus.energyCoreLevel > 0 {
                                        compactMeter(title: "Energy Core", value: galacticStatus.energyCoreLevel, color: .yellow, icon: "bolt.fill")
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
                        .tint(brandPurple)
                        
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
                        
                        // OTA Firmware Update Section
                        OTASettingsView(bluetoothManager: bluetoothManager, brandColor: brandPurple)
                        
                        }  // Close the if case .connected, let galacticStatus block
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
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar is now empty - buttons moved to header
            }
            .sheet(isPresented: $showingScanSheet) {
                ScannerView(bluetoothManager: bluetoothManager, isPresented: $showingScanSheet)
            }
        }
    }
    
    // MARK: - Branded Header
    
    @ViewBuilder
    private var brandedHeader: some View {
        HStack(spacing: 16) {
            // ChaoticVolt Logo (spans both rows)
            Image("ChaoticVoltLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                // Top row: App title
                HStack(spacing: 0) {
                    Text("42 decibels ")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("by ChaoticVolt")
                        .font(.headline)
                }
                
                // Bottom row: Connection status
                HStack(spacing: 12) {
                    // Only show status and controls when Live (recent communication)
                    if let galacticStatus = bluetoothManager.galacticStatus,
                       galacticStatus.secondsSinceReceived < 3 {
                        // Connection indicator with device name
                        HStack(spacing: 8) {
                            Text("connected to:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(bluetoothManager.connectedSpeaker?.name ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // Disconnect button
                        Button {
                            bluetoothManager.disconnect()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemBackground))
                        )
                    } else if case .connected = bluetoothManager.connectionState {
                        // Connected but not Live - show status
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text("Not responding")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Disconnect button
                        Button {
                            bluetoothManager.disconnect()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemBackground))
                        )
                    } else {
                        // Not connected
                        Text("Not connected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Connect button
                        Button {
                            showingScanSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemBackground))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: brandPurple.opacity(0.3), radius: 20, x: 0, y: 0)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
                StatusPillCompact(
                    title: "Mute",
                    isActive: status.shieldStatus.isMuted,
                    icon: "speaker.slash.fill",
                    activeColor: .red,
                    infoText: "No sound for a moment. Nobody say a word."
                ) {
                    bluetoothManager.setMute(!status.shieldStatus.isMuted)
                }
                
                // Audio Duck pill (Panic Mode) - interactive!
                StatusPillCompact(
                    title: "Duck",
                    isActive: status.shieldStatus.isPanicMode,
                    icon: "waveform.path.badge.minus",
                    activeColor: .orange,
                    infoText: "Instantly drops volume to 25% (−12 dB)."
                ) {
                    bluetoothManager.setAudioDuck(!status.shieldStatus.isPanicMode)
                }
                
                // Loudness pill - interactive!
                StatusPillCompact(
                    title: "Loudness",
                    isActive: status.shieldStatus.isLoudnessOn,
                    icon: "speaker.wave.3",
                    activeColor: .blue,
                    infoText: "Fuller sound at lower volume."
                ) {
                    bluetoothManager.setLoudness(enabled: !status.shieldStatus.isLoudnessOn)
                }
                
                // Normalizer pill (Limiter) - interactive!
                StatusPillCompact(
                    title: "Normalize",
                    isActive: status.shieldStatus.isLimiterActive,
                    icon: "waveform.path.ecg",
                    activeColor: .green,
                    infoText: "Makes speech clearer at lower volume."
                ) {
                    bluetoothManager.setNormalizer(!status.shieldStatus.isLimiterActive)
                }
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
    let brandColor: Color
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
                        .foregroundStyle(brandColor)
                }
            }
            .padding()
            .background(isSelected ? brandColor.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? brandColor : Color.clear, lineWidth: 2)
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
    var infoText: String? = nil
    var onTap: (() -> Void)? = nil
    
    @State private var showingInfo = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isActive ? activeColor : .secondary)
                    
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(isActive ? activeColor : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Info button (if infoText is provided)
                if let _ = infoText {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: 4)
                    .popover(isPresented: $showingInfo) {
                        if let infoText = infoText {
                            Text(infoText)
                                .font(.caption)
                                .padding()
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? activeColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? activeColor : Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            // Visual feedback
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Call the action
            onTap?()
            
            // Reset after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
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

