//
//  OTAManager.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-23.
//

import Foundation
import CoreBluetooth
import Combine

/// Manages Over-The-Air firmware updates via BLE+WiFi
@MainActor
class OTAManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var status: OTAStatus = OTAStatus(state: .idle, error: .none, progress: 0, downloadedKB: 0, totalKB: 0, rssi: 0)
    @Published var isUpdating: Bool = false
    @Published var showingCredentialsSheet: Bool = false
    @Published var showingValidationDialog: Bool = false
    
    // MARK: - OTA Characteristics UUIDs
    
    struct OTACharacteristics {
        nonisolated(unsafe) static let credentials = CBUUID(string: "00000005-1234-5678-9ABC-DEF012345678")
        nonisolated(unsafe) static let url = CBUUID(string: "00000006-1234-5678-9ABC-DEF012345678")
        nonisolated(unsafe) static let control = CBUUID(string: "00000007-1234-5678-9ABC-DEF012345678")
        nonisolated(unsafe) static let status = CBUUID(string: "00000008-1234-5678-9ABC-DEF012345678")
    }
    
    // MARK: - OTA State
    
    enum OTAState: UInt8 {
        case idle = 0x00              // Ready for OTA
        case credsReceived = 0x01     // WiFi credentials received
        case urlReceived = 0x02       // Firmware URL received
        case wifiConnecting = 0x03    // Connecting to WiFi
        case wifiConnected = 0x04     // WiFi connected
        case downloading = 0x05       // Downloading firmware
        case verifying = 0x06         // Verifying firmware
        case success = 0x07           // OTA complete, ready for reboot
        case pendingVerify = 0x08     // New firmware running, needs validation
        case error = 0xFF             // Error occurred
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .credsReceived: return "WiFi credentials set"
            case .urlReceived: return "Firmware URL set"
            case .wifiConnecting: return "Connecting to WiFi..."
            case .wifiConnected: return "WiFi connected"
            case .downloading: return "Downloading..."
            case .verifying: return "Verifying firmware..."
            case .success: return "Update complete! Ready to reboot."
            case .pendingVerify: return "New firmware running - validate or rollback"
            case .error: return "Error occurred"
            }
        }
    }
    
    // MARK: - OTA Error
    
    enum OTAError: UInt8 {
        case none = 0x00              // No error
        case wifiConnect = 0x01       // WiFi connection failed
        case httpConnect = 0x02       // HTTP connection failed
        case httpResponse = 0x03      // HTTP error response
        case download = 0x04          // Download failed
        case verify = 0x05            // Verification failed
        case write = 0x06             // Flash write failed
        case noCredentials = 0x07     // No WiFi credentials
        case noUrl = 0x08             // No firmware URL
        case invalidImage = 0x09      // Invalid firmware image
        case cancelled = 0x0A         // OTA cancelled by user
        case rollbackFailed = 0x0B    // Rollback failed
        
        var userMessage: String {
            switch self {
            case .none:
                return "No error"
            case .wifiConnect:
                return "Could not connect to WiFi. Check credentials."
            case .httpConnect:
                return "Could not reach firmware server."
            case .httpResponse:
                return "Server returned an error."
            case .download:
                return "Download failed. Check internet connection."
            case .verify:
                return "Firmware verification failed."
            case .write:
                return "Could not write firmware to device."
            case .noCredentials:
                return "WiFi credentials not provided."
            case .noUrl:
                return "Firmware URL not provided."
            case .invalidImage:
                return "Invalid firmware file."
            case .cancelled:
                return "Update cancelled."
            case .rollbackFailed:
                return "Could not rollback to previous firmware."
            }
        }
        
        var isRetryable: Bool {
            switch self {
            case .wifiConnect, .httpConnect, .download:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - OTA Command
    
    enum OTACommand: UInt8 {
        case start = 0x10       // Start OTA download
        case cancel = 0x11      // Cancel ongoing OTA
        case reboot = 0x12      // Reboot to new firmware
        case getVersion = 0x13  // Request firmware version
        case rollback = 0x14    // Rollback to previous firmware
        case validate = 0x15    // Mark new firmware as valid
    }
    
    // MARK: - OTA Status
    
    struct OTAStatus {
        let state: OTAState
        let error: OTAError
        let progress: UInt8
        let downloadedKB: UInt16
        let totalKB: UInt16
        let rssi: Int8
        
        init(state: OTAState, error: OTAError, progress: UInt8, downloadedKB: UInt16, totalKB: UInt16, rssi: Int8) {
            self.state = state
            self.error = error
            self.progress = progress
            self.downloadedKB = downloadedKB
            self.totalKB = totalKB
            self.rssi = rssi
        }
        
        init(data: Data) {
            guard data.count >= 8 else {
                self.state = .idle
                self.error = .none
                self.progress = 0
                self.downloadedKB = 0
                self.totalKB = 0
                self.rssi = 0
                return
            }
            
            self.state = OTAState(rawValue: data[0]) ?? .idle
            self.error = OTAError(rawValue: data[1]) ?? .none
            self.progress = data[2]
            self.downloadedKB = UInt16(data[3]) | (UInt16(data[4]) << 8)
            self.totalKB = UInt16(data[5]) | (UInt16(data[6]) << 8)
            self.rssi = Int8(bitPattern: data[7])
        }
    }
    
    // MARK: - Private Properties
    
    private weak var peripheral: CBPeripheral?
    private var credentialsChar: CBCharacteristic?
    private var urlChar: CBCharacteristic?
    private var controlChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?
    
    // Callbacks
    var onStatusUpdate: ((OTAStatus) -> Void)?
    var onError: ((OTAError) -> Void)?
    var onComplete: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Set the peripheral to use for OTA operations
    func setPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
    
    /// Discover OTA characteristics (call after connecting)
    func discoverOTACharacteristics(for service: CBService) {
        guard let peripheral = peripheral else { return }
        
        print("🔍 Discovering OTA characteristics...")
        peripheral.discoverCharacteristics([
            OTACharacteristics.credentials,
            OTACharacteristics.url,
            OTACharacteristics.control,
            OTACharacteristics.status
        ], for: service)
    }
    
    /// Handle discovered characteristics
    func handleDiscoveredCharacteristics(_ characteristics: [CBCharacteristic], for peripheral: CBPeripheral) {
        print("🔍 OTAManager: Checking \(characteristics.count) characteristics for OTA UUIDs")
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case OTACharacteristics.credentials:
                credentialsChar = characteristic
                print("✅ OTA Credentials characteristic found and stored!")
            case OTACharacteristics.url:
                urlChar = characteristic
                print("✅ OTA URL characteristic found and stored!")
            case OTACharacteristics.control:
                controlChar = characteristic
                print("✅ OTA Control characteristic found and stored!")
            case OTACharacteristics.status:
                statusChar = characteristic
                print("✅ OTA Status characteristic found and stored!")
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
                print("📢 Subscribed to OTA Status notifications")
            default:
                break
            }
        }
        
        // Summary
        print("📊 OTA Characteristics Summary:")
        print("   Credentials: \(credentialsChar != nil ? "✅" : "❌")")
        print("   URL: \(urlChar != nil ? "✅" : "❌")")
        print("   Control: \(controlChar != nil ? "✅" : "❌")")
        print("   Status: \(statusChar != nil ? "✅" : "❌")")
    }
    
    /// Handle status updates from the device
    func handleStatusUpdate(_ data: Data) {
        let newStatus = OTAStatus(data: data)
        status = newStatus
        
        print("📊 OTA Status Update:")
        print("   State: \(newStatus.state.description)")
        print("   Progress: \(newStatus.progress)%")
        print("   Downloaded: \(newStatus.downloadedKB) / \(newStatus.totalKB) KB")
        print("   RSSI: \(newStatus.rssi) dBm")
        
        if newStatus.error != .none {
            print("   ❌ Error: \(newStatus.error.userMessage)")
        }
        
        onStatusUpdate?(newStatus)
        
        // Handle state changes
        switch newStatus.state {
        case .success:
            // Ready for reboot - user can tap reboot button
            isUpdating = false
        case .pendingVerify:
            // New firmware running, needs validation
            showingValidationDialog = true
            isUpdating = false
        case .error:
            onError?(newStatus.error)
            isUpdating = false
        case .idle:
            if newStatus.error == .none && isUpdating {
                // OTA completed successfully
                onComplete?()
            }
            isUpdating = false
        case .downloading:
            isUpdating = true
        default:
            break
        }
    }
    
    /// Start OTA update process
    func startOTA(ssid: String, password: String, firmwareURL: String) {
        // Debug: Print what we have
        print("🔧 OTA Start Debug:")
        print("   Peripheral: \(peripheral != nil ? "✅" : "❌")")
        print("   Credentials Char: \(credentialsChar != nil ? "✅" : "❌")")
        print("   URL Char: \(urlChar != nil ? "✅" : "❌")")
        print("   Control Char: \(controlChar != nil ? "✅" : "❌")")
        print("   Status Char: \(statusChar != nil ? "✅" : "❌")")
        
        guard let peripheral = peripheral,
              let credentialsChar = credentialsChar,
              let urlChar = urlChar,
              let controlChar = controlChar else {
            print("❌ OTA characteristics not available - cannot start OTA")
            onError?(.noCredentials)
            return
        }
        
        isUpdating = true
        
        // Step 1: Send WiFi credentials
        let credData = encodeCredentials(ssid: ssid, password: password)
        peripheral.writeValue(credData, for: credentialsChar, type: .withResponse)
        print("📤 Sent WiFi credentials (SSID: \(ssid))")
        
        // Step 2: Send firmware URL (after small delay)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard let urlData = encodeURL(firmwareURL) else {
                onError?(.noUrl)
                isUpdating = false
                return
            }
            peripheral.writeValue(urlData, for: urlChar, type: .withResponse)
            print("📤 Sent firmware URL: \(firmwareURL)")
            
            // Step 3: Send START command (after another delay)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let startCmd = encodeCommand(.start)
            peripheral.writeValue(startCmd, for: controlChar, type: .withResponse)
            print("📤 Sent START command")
        }
    }
    
    /// Cancel ongoing OTA
    func cancelOTA() {
        guard let peripheral = peripheral,
              let controlChar = controlChar else { return }
        
        let cancelCmd = encodeCommand(.cancel)
        peripheral.writeValue(cancelCmd, for: controlChar, type: .withResponse)
        print("📤 Sent CANCEL command")
        isUpdating = false
    }
    
    /// Reboot to new firmware
    func rebootToNewFirmware() {
        guard let peripheral = peripheral,
              let controlChar = controlChar else { return }
        
        let rebootCmd = encodeCommand(.reboot)
        peripheral.writeValue(rebootCmd, for: controlChar, type: .withResponse)
        print("📤 Sent REBOOT command")
    }
    
    /// Validate the new firmware
    func validateFirmware() {
        guard let peripheral = peripheral,
              let controlChar = controlChar else { return }
        
        let validateCmd = encodeCommand(.validate)
        peripheral.writeValue(validateCmd, for: controlChar, type: .withResponse)
        print("📤 Sent VALIDATE command")
        showingValidationDialog = false
    }
    
    /// Rollback to previous firmware
    func rollbackFirmware() {
        guard let peripheral = peripheral,
              let controlChar = controlChar else { return }
        
        let rollbackCmd = encodeCommand(.rollback)
        peripheral.writeValue(rollbackCmd, for: controlChar, type: .withResponse)
        print("📤 Sent ROLLBACK command")
        showingValidationDialog = false
    }
    
    /// Get firmware version
    func getVersion() {
        guard let peripheral = peripheral,
              let controlChar = controlChar else { return }
        
        let versionCmd = encodeCommand(.getVersion)
        peripheral.writeValue(versionCmd, for: controlChar, type: .withResponse)
        print("📤 Sent GET_VERSION command")
    }
    
    // MARK: - Private Methods - Data Encoding
    
    private func encodeCredentials(ssid: String, password: String) -> Data {
        var data = Data()
        
        // SSID (max 32 bytes)
        if let ssidData = ssid.data(using: .utf8) {
            data.append(ssidData.prefix(32))
        }
        
        // Separator (null byte)
        data.append(0x00)
        
        // Password (max 64 bytes)
        if let pwdData = password.data(using: .utf8) {
            data.append(pwdData.prefix(64))
        }
        
        return data
    }
    
    private func encodeURL(_ urlString: String) -> Data? {
        guard let data = urlString.data(using: .utf8) else { return nil }
        return data.prefix(256)
    }
    
    private func encodeCommand(_ command: OTACommand, parameter: UInt8 = 0x00) -> Data {
        return Data([command.rawValue, parameter])
    }
}

// MARK: - OTA Reconnection Handler

@MainActor
class OTAReconnectionHandler: ObservableObject {
    @Published var isReconnecting: Bool = false
    @Published var reconnectAttempts: Int = 0
    
    private var reconnectTimer: Timer?
    private let maxAttempts = 10
    
    var onReconnected: (() -> Void)?
    var onFailed: (() -> Void)?
    
    func startReconnection() {
        reconnectAttempts = 0
        isReconnecting = true
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.reconnectAttempts += 1
                
                if self.reconnectAttempts > self.maxAttempts {
                    self.stopReconnection()
                    self.onFailed?()
                }
            }
        }
    }
    
    func stopReconnection() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        isReconnecting = false
    }
    
    func handleReconnected() {
        stopReconnection()
        onReconnected?()
    }
}
