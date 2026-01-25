//
//  OTAViews.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-23.
//

import SwiftUI
// import NetworkExtension  // Commented out until paid developer account is active

// MARK: - WiFi Credentials Sheet

struct WiFiCredentialsSheet: View {
    @State private var ssid: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var firmwareURL: String = "https://chaoticvolt.eu/firmware/speaker_latest.bin"
    // WiFi auto-detection disabled until paid Apple Developer account is active
    // @State private var isLoadingCurrentNetwork: Bool = false
    // @State private var currentNetworkError: String?
    
    var onSubmit: (String, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Quick Setup section removed until paid developer account is active
                // Will be re-enabled after enrollment approval
                
                Section("WiFi Network") {
                    TextField("SSID (Network Name)", text: $ssid)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                    }
                }
                
                Section("Firmware") {
                    TextField("Firmware URL", text: $firmwareURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    Text("Default: ChaoticVolt latest firmware")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button("Start Update") {
                        onSubmit(ssid, password, firmwareURL)
                        dismiss()
                    }
                    .disabled(ssid.isEmpty || firmwareURL.isEmpty)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Update Process", systemImage: "info.circle")
                            .font(.headline)
                        
                        Text("1. Device connects to WiFi")
                        Text("2. Downloads firmware over internet")
                        Text("3. Installs and verifies")
                        Text("4. Reboots with new firmware")
                        
                        Text("\nThis process takes 2-5 minutes. Do not disconnect or turn off the speaker.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("WiFi Requirements", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("• Network must be 2.4GHz (ESP32 limitation)")
                        Text("• Network must have internet access")
                        Text("• You'll need to enter the password manually")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Firmware Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            // Auto-detection disabled until paid developer account
            // .onAppear {
            //     if ssid.isEmpty {
            //         fetchCurrentWiFiNetwork()
            //     }
            // }
        }
    }
    
    // MARK: - WiFi Network Detection (Disabled - Requires Paid Apple Developer Account)
    
    // This feature will be enabled once your Apple Developer Program enrollment is approved
    // Uncomment the code below and add the entitlement when ready
    
    /*
    private func fetchCurrentWiFiNetwork() {
        isLoadingCurrentNetwork = true
        currentNetworkError = nil
        
        Task {
            // Fetch current WiFi network (returns optional NEHotspotNetwork)
            if let network = try? await NEHotspotNetwork.fetchCurrent() {
                await MainActor.run {
                    ssid = network.ssid
                    currentNetworkError = nil
                    print("✅ Auto-filled WiFi SSID: \(network.ssid)")
                    isLoadingCurrentNetwork = false
                }
            } else {
                await MainActor.run {
                    currentNetworkError = "Not connected to WiFi"
                    print("⚠️ No WiFi network detected")
                    isLoadingCurrentNetwork = false
                }
            }
        }
    }
    */
}

// MARK: - OTA Progress View

struct OTAProgressView: View {
    @ObservedObject var otaManager: OTAManager
    let brandColor: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // State header with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: stateIcon)
                        .font(.title2)
                        .foregroundStyle(stateColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Firmware Update")
                        .font(.headline)
                    
                    Text(otaManager.status.state.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar (visible during download)
            if otaManager.status.state == .downloading {
                VStack(spacing: 8) {
                    ProgressView(value: Double(otaManager.status.progress) / 100.0)
                        .tint(brandColor)
                    
                    HStack {
                        Text("\(otaManager.status.progress)%")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(otaManager.status.downloadedKB) / \(otaManager.status.totalKB) KB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // WiFi signal indicator
                    HStack(spacing: 6) {
                        Image(systemName: wifiIcon)
                            .foregroundStyle(wifiColor)
                        Text("\(otaManager.status.rssi) dBm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Error message
            if otaManager.status.state == .error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    
                    Text(otaManager.status.error.userMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons based on state
            actionButtons
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Cancel button (visible during update)
            if otaManager.isUpdating {
                Button {
                    otaManager.cancelOTA()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            // Reboot button (visible after success)
            if otaManager.status.state == .success {
                Button {
                    otaManager.rebootToNewFirmware()
                } label: {
                    Label("Reboot Now", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
            }
            
            // Retry button (visible on retryable errors)
            if otaManager.status.state == .error && otaManager.status.error.isRetryable {
                Button {
                    // Show credentials sheet again
                    otaManager.showingCredentialsSheet = true
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
    
    private var stateColor: Color {
        switch otaManager.status.state {
        case .idle:
            return .gray
        case .credsReceived, .urlReceived:
            return .blue
        case .wifiConnecting, .wifiConnected:
            return .cyan
        case .downloading:
            return brandColor
        case .verifying:
            return .purple
        case .success:
            return .green
        case .pendingVerify:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var stateIcon: String {
        switch otaManager.status.state {
        case .idle:
            return "checkmark.circle"
        case .credsReceived, .urlReceived:
            return "checkmark.circle.fill"
        case .wifiConnecting, .wifiConnected:
            return "wifi"
        case .downloading:
            return "arrow.down.circle.fill"
        case .verifying:
            return "checkmark.shield.fill"
        case .success:
            return "checkmark.circle.fill"
        case .pendingVerify:
            return "exclamationmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private var wifiIcon: String {
        let rssi = otaManager.status.rssi
        if rssi >= -50 {
            return "wifi"
        } else if rssi >= -70 {
            return "wifi"
        } else {
            return "wifi.slash"
        }
    }
    
    private var wifiColor: Color {
        let rssi = otaManager.status.rssi
        if rssi >= -50 {
            return .green
        } else if rssi >= -70 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Validation Dialog

struct ValidationDialog: View {
    let onValidate: () -> Void
    let onRollback: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Validate New Firmware")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your speaker is running new firmware. Is everything working correctly?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    onValidate()
                    dismiss()
                } label: {
                    Label("Keep New Firmware", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button {
                    onRollback()
                    dismiss()
                } label: {
                    Label("Rollback to Previous", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)
            
            Text("If you don't choose, the device will automatically rollback after reboot.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - OTA Settings View

struct OTASettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let brandColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Firmware Update", systemImage: "arrow.down.circle")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // OTA Progress (if updating)
                if bluetoothManager.otaManager.isUpdating || 
                   bluetoothManager.otaManager.status.state == .success ||
                   bluetoothManager.otaManager.status.state == .error {
                    OTAProgressView(otaManager: bluetoothManager.otaManager, brandColor: brandColor)
                } else {
                    // Start update button
                    Button {
                        bluetoothManager.otaManager.showingCredentialsSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Update Firmware")
                                    .font(.headline)
                                
                                Text("Install latest software over WiFi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $bluetoothManager.otaManager.showingCredentialsSheet) {
            WiFiCredentialsSheet { ssid, password, url in
                bluetoothManager.otaManager.startOTA(
                    ssid: ssid,
                    password: password,
                    firmwareURL: url
                )
            }
        }
        .alert("Validate New Firmware", isPresented: $bluetoothManager.otaManager.showingValidationDialog) {
            Button("Keep New Firmware", role: .none) {
                bluetoothManager.otaManager.validateFirmware()
            }
            Button("Rollback to Previous", role: .destructive) {
                bluetoothManager.otaManager.rollbackFirmware()
            }
        } message: {
            Text("Your speaker is running new firmware. Is everything working correctly?")
        }
    }
}

// MARK: - Preview

#Preview {
    WiFiCredentialsSheet { ssid, password, url in
        print("SSID: \(ssid), Password: \(password), URL: \(url)")
    }
}
