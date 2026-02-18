//
//  BluetoothManager.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import Foundation
import CoreBluetooth
import Combine

/// Manages Bluetooth Low Energy connection and communication with the speaker
@MainActor
class BluetoothManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var discoveredSpeakers: [CBPeripheral] = []
    @Published var connectedSpeaker: CBPeripheral?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentPreset: DSPPreset?
    @Published var loudnessEnabled: Bool?
    @Published var galacticStatus: GalacticStatus?
    
    // MARK: - Connection State
    
    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - DSP Presets
    
    enum DSPPreset: String, CaseIterable {
        case office = "OFFICE"
        case full = "FULL"
        case night = "NIGHT"
        case speech = "SPEECH"
        
        var commandData: Data {
            switch self {
            case .office: return Data([0x01, 0x00])
            case .full: return Data([0x01, 0x01])
            case .night: return Data([0x01, 0x02])
            case .speech: return Data([0x01, 0x03])
            }
        }
    }
    
    // MARK: - Galactic Status
    
    struct GalacticStatus {
        let protocolVersion: UInt8          // Byte 0: 0x42
        let currentQuantumFlavor: UInt8     // Byte 1: 0-3 (preset ID)
        let shieldStatus: ShieldStatus      // Byte 2: bitfield
        let energyCoreLevel: UInt8          // Byte 3: 0-100 (reserved)
        let distortionFieldStrength: UInt8  // Byte 4: 0-100 (volume placeholder)
        let energyCore: UInt8               // Byte 5: 0-100 (battery placeholder)
        let lastContact: UInt8              // Byte 6: seconds since last BLE interaction (from device)
        let receivedAt: Date                // iOS-side timestamp when we received this update
        
        struct ShieldStatus {
            let isMuted: Bool          // bit 0
            let isPanicMode: Bool      // bit 1
            let isLoudnessOn: Bool     // bit 2
            let isLimiterActive: Bool  // bit 3
            let isBypassActive: Bool   // bit 4
            let isBassBoostActive: Bool // bit 5
            
            init(byte: UInt8) {
                self.isMuted = (byte & 0x01) != 0
                self.isPanicMode = (byte & 0x02) != 0
                self.isLoudnessOn = (byte & 0x04) != 0
                self.isLimiterActive = (byte & 0x08) != 0
                self.isBypassActive = (byte & 0x10) != 0
                self.isBassBoostActive = (byte & 0x20) != 0
            }
        }
        
        var preset: DSPPreset? {
            switch currentQuantumFlavor {
            case 0: return .office
            case 1: return .full
            case 2: return .night
            case 3: return .speech
            default: return nil
            }
        }
        
        /// Effective volume level (0-100) after all caps and processing
        var effectiveVolume: UInt8 {
            return distortionFieldStrength
        }
        
        /// Description of volume cap based on current preset
        var volumeCapDescription: String? {
            guard let preset = preset else { return nil }
            
            switch preset {
            case .night:
                return "Night max 60%"
            case .office, .full, .speech:
                // These presets have 100% cap, only show if normalizer is limiting
                if shieldStatus.isLimiterActive {
                    return "Normalizer reducing ~20%"
                }
                return nil
            }
        }
        
        /// Returns seconds since iOS received this status update (more reliable than device's lastContact)
        var secondsSinceReceived: Int {
            return Int(Date().timeIntervalSince(receivedAt))
        }
    }
    
    // MARK: - Control Commands
    
    private enum Command {
        case setPreset(DSPPreset)
        case setLoudness(Bool)
        case requestStatus
        case mute(Bool)
        case audioDuck(Bool)      // Panic button -> Audio Duck (reduce volume temporarily)
        case normalizer(Bool)     // Limiter button -> Normalizer/DRC
        case setVolume(UInt8)     // Set volume trim (0-100)
        case bypass(Bool)         // DSP Bypass mode
        case bassBoost(Bool)      // Bass boost
        case sineTest(Bool)       // TEST: Sine wave test mode (1kHz tone)
        
        var data: Data {
            switch self {
            case .setPreset(let preset):
                return preset.commandData
            case .setLoudness(let enabled):
                return enabled ? Data([0x02, 0x01]) : Data([0x02, 0x00])
            case .requestStatus:
                return Data([0x03, 0x00])
            case .mute(let enabled):
                return enabled ? Data([0x04, 0x01]) : Data([0x04, 0x00])
            case .audioDuck(let enabled):
                return enabled ? Data([0x05, 0x01]) : Data([0x05, 0x00])
            case .normalizer(let enabled):
                return enabled ? Data([0x06, 0x01]) : Data([0x06, 0x00])
            case .setVolume(let level):
                // Clamp to 0-100 range
                let clampedLevel = min(100, max(0, level))
                return Data([0x07, clampedLevel])
            case .bypass(let enabled):
                return enabled ? Data([0x08, 0x01]) : Data([0x08, 0x00])
            case .bassBoost(let enabled):
                return enabled ? Data([0x09, 0x01]) : Data([0x09, 0x00])
            case .sineTest(let enabled):
                return enabled ? Data([0x0A, 0x01]) : Data([0x0A, 0x00])
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var galacticStatusCharacteristic: CBCharacteristic?
    private var connectionTimeoutTask: Task<Void, Never>?
    
    // Speaker UUIDs
    nonisolated(unsafe) private let serviceUUID = CBUUID(string: "00000001-1234-5678-9ABC-DEF012345678")
    nonisolated(unsafe) private let controlWriteUUID = CBUUID(string: "00000002-1234-5678-9ABC-DEF012345678")
    nonisolated(unsafe) private let statusNotifyUUID = CBUUID(string: "00000003-1234-5678-9ABC-DEF012345678")
    nonisolated(unsafe) private let galacticStatusUUID = CBUUID(string: "00000004-1234-5678-9ABC-DEF012345678")
    
    // Device name prefixes for fallback filtering
    // If your devices don't advertise the service UUID, filter by name instead
    private let validDeviceNamePrefixes = [
        "42 Decibels",
        "42DB",
        "ChaoticVolt"
        // Add more prefixes as needed for your device naming scheme
    ]
    
    // OTA Manager (iOS/iPadOS only)
    #if !os(watchOS)
    @Published var otaManager = OTAManager()
    var watchConnectivityManager: WatchConnectivityManager?
    #endif
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        #if !os(watchOS)
        // iOS: Set up WatchConnectivity and observers
        setupWatchConnectivity()
        #endif
    }
    
    #if !os(watchOS)
    // MARK: - WatchConnectivity Setup (iOS Only)
    
    private func setupWatchConnectivity() {
        watchConnectivityManager = WatchConnectivityManager()
        
        // Observe commands from watch
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCommandFromWatch(_:)),
            name: .executeCommandFromWatch,
            object: nil
        )
        
        // Observe requests for connection state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateRequest(_:)),
            name: .requestConnectionStateForWatch,
            object: nil
        )
    }
    
    @objc private func handleCommandFromWatch(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let commandType = userInfo["commandType"] as? WatchConnectivityManager.CommandType,
              let commandData = userInfo["commandData"] as? Data else { return }
        
        print("📲 Executing command from watch: \(commandType)")
        
        // Execute the command via BLE
        sendCommand(commandData)
    }
    
    @objc private func handleConnectionStateRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let replyHandler = userInfo["replyHandler"] as? ([String: Any]) -> Void else { return }
        
        // Send current connection state back to watch
        let info = WatchConnectivityManager.ConnectionInfo(
            isConnected: connectionState == .connected,
            speakerName: connectedSpeaker?.name,
            speakerIdentifier: connectedSpeaker?.identifier.uuidString
        )
        
        if let data = try? JSONEncoder().encode(info) {
            replyHandler([WatchConnectivityManager.connectionStateKey: data])
        }
    }
    
    private func updateWatchConnectionState() {
        watchConnectivityManager?.updateConnectionState(
            isConnected: connectionState == .connected,
            speakerName: connectedSpeaker?.name,
            speakerIdentifier: connectedSpeaker?.identifier.uuidString
        )
    }
    #endif
    
    // MARK: - Public Methods
    
    /// Start scanning for devices. By default, only scans for our known devices.
    /// - Parameter showAllDevices: If true, shows all BLE devices (for debugging). Default is false.
    func startScanning(showAllDevices: Bool = false) {
        guard centralManager.state == .poweredOn else {
            #if os(watchOS)
            // watchOS may take a few seconds to initialize BLE after app launch
            print("⏳ Bluetooth not ready yet, retrying in 1 second...")
            connectionState = .scanning
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                startScanning(showAllDevices: showAllDevices)
            }
            return
            #else
            connectionState = .error("Bluetooth is not available")
            return
            #endif
        }
        
        discoveredSpeakers.removeAll()
        connectionState = .scanning
        
        if showAllDevices {
            // Debug mode: Show all devices (useful for development/troubleshooting)
            print("⚠️ Scanning for ALL Bluetooth devices (debug mode)")
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        } else {
            // Production mode: Only scan for peripherals advertising our custom service UUID
            // This ensures we only see devices we can actually interact with
            print("✅ Scanning for 42 Decibels devices only")
            centralManager.scanForPeripherals(
                withServices: [serviceUUID], 
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        
        // Cancel any existing timeout
        connectionTimeoutTask?.cancel()
        
        // Set a timeout for connection (watchOS has shorter range/weaker antenna)
        #if os(watchOS)
        let timeoutDuration: UInt64 = 15_000_000_000 // 15 seconds for Watch
        #else
        let timeoutDuration: UInt64 = 10_000_000_000 // 10 seconds for iOS
        #endif
        
        connectionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: timeoutDuration)
            
            if connectionState == .connecting {
                print("⏱️ Connection timeout - cancelling connection attempt")
                centralManager.cancelPeripheralConnection(peripheral)
                connectionState = .error("Connection timed out. Move closer to the speaker and try again.")
            }
        }
        
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        // Cancel timeout task if active
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        if let speaker = connectedSpeaker {
            centralManager.cancelPeripheralConnection(speaker)
        }
        writeCharacteristic = nil
        connectedSpeaker = nil
        connectionState = .disconnected
        
        #if !os(watchOS)
        // Notify watch that we're disconnected
        updateWatchConnectionState()
        #endif
        currentPreset = nil
        loudnessEnabled = nil
        galacticStatus = nil
    }
    
    func setPreset(_ preset: DSPPreset) {
        sendCommand(.setPreset(preset))
        currentPreset = preset
    }
    
    func setLoudness(enabled: Bool) {
        sendCommand(.setLoudness(enabled))
        loudnessEnabled = enabled
    }
    
    func requestStatus() {
        sendCommand(.requestStatus)
    }
    
    func setMute(_ enabled: Bool) {
        sendCommand(.mute(enabled))
    }
    
    func setAudioDuck(_ enabled: Bool) {
        sendCommand(.audioDuck(enabled))
    }
    
    func setNormalizer(_ enabled: Bool) {
        sendCommand(.normalizer(enabled))
    }
    
    func setVolume(_ level: UInt8) {
        sendCommand(.setVolume(level))
    }
    
    func setBypass(_ enabled: Bool) {
        sendCommand(.bypass(enabled))
    }
    
    func setBassBoost(_ enabled: Bool) {
        sendCommand(.bassBoost(enabled))
    }
    
    // TEST: Sine wave test mode
    func setSineTest(_ enabled: Bool) {
        sendCommand(.sineTest(enabled))
    }
    
    // MARK: - Private Methods
    
    /// Checks if a discovered peripheral is one of our known devices
    private func isValidDevice(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        // If we scanned with service UUID filter, all results are valid
        // This check is mainly for fallback scenarios
        
        guard let name = peripheral.name else {
            // No name = likely not our device
            return false
        }
        
        // Check if device name starts with any of our known prefixes
        return validDeviceNamePrefixes.contains { name.hasPrefix($0) }
    }
    
    private func sendCommand(_ command: Command) {
        guard let characteristic = writeCharacteristic,
              let peripheral = connectedSpeaker else {
            print("❌ Cannot send command: Not connected or characteristic not found")
            return
        }
        
        let data = command.data
        
        // Try to use .withResponse first, fall back to .withoutResponse if needed
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        
        peripheral.writeValue(data, for: characteristic, type: writeType)
        
        let hexString = data.map { String(format: "%02X", $0) }.joined()
        print("📤 Sent command: \(hexString) using \(writeType == .withResponse ? "withResponse" : "withoutResponse")")
    }
    
    // Overload to accept raw Data (for commands from watch)
    private func sendCommand(_ data: Data) {
        guard let characteristic = writeCharacteristic,
              let peripheral = connectedSpeaker else {
            print("❌ Cannot send command: Not connected or characteristic not found")
            return
        }
        
        // Try to use .withResponse first, fall back to .withoutResponse if needed
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        
        peripheral.writeValue(data, for: characteristic, type: writeType)
        
        let hexString = data.map { String(format: "%02X", $0) }.joined()
        print("📤 Sent command (raw): \(hexString) using \(writeType == .withResponse ? "withResponse" : "withoutResponse")")
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("Bluetooth is powered on")
            case .poweredOff:
                connectionState = .error("Bluetooth is powered off")
            case .unauthorized:
                connectionState = .error("Bluetooth access not authorized")
            case .unsupported:
                connectionState = .error("Bluetooth not supported")
            default:
                connectionState = .disconnected
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            // When scanning with service UUID filter, all discovered devices are valid
            // When scanning without filter (nil), we need to validate by name
            // For maximum compatibility, we always validate
            
            guard isValidDevice(peripheral, advertisementData: advertisementData) else {
                // Silently ignore devices that aren't ours
                return
            }
            
            // Avoid duplicates
            if !discoveredSpeakers.contains(where: { $0.identifier == peripheral.identifier }) {
                print("✅ Discovered valid device: \(peripheral.name ?? "Unknown") (RSSI: \(RSSI))")
                discoveredSpeakers.append(peripheral)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            // Cancel timeout since connection succeeded
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            
            print("Connected to \(peripheral.name ?? "Unknown")")
            connectedSpeaker = peripheral
            connectionState = .connected
            peripheral.delegate = self
            
            // Set peripheral for OTA manager (iOS/iPadOS only)
            #if !os(watchOS)
            otaManager.setPeripheral(peripheral)
            // Notify watch about connection
            updateWatchConnectionState()
            #endif
            
            // Discover all services (nil = discover all)
            // This ensures we find the service containing GALACTIC_STATUS and OTA characteristics
            peripheral.discoverServices(nil)
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            // Cancel timeout task
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            
            let errorMessage = error?.localizedDescription ?? "Unknown error"
            print("❌ Failed to connect: \(errorMessage)")
            
            #if os(watchOS)
            // Provide Watch-specific guidance
            connectionState = .error("Connection failed. Move closer to the speaker and try again.")
            #else
            connectionState = .error("Failed to connect: \(errorMessage)")
            #endif
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionState = .error("Disconnected: \(error.localizedDescription)")
            } else {
                connectionState = .disconnected
            }
            connectedSpeaker = nil
            writeCharacteristic = nil
            currentPreset = nil
            loudnessEnabled = nil
            galacticStatus = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Discovered service: \(service.uuid)")
            // Discover ALL characteristics to see everything that's available
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        print("📋 Service \(service.uuid) has \(characteristics.count) characteristics:")
        for char in characteristics {
            print("   - \(char.uuid) [props: \(char.properties.rawValue)]")
        }
        
        #if !os(watchOS)
        // Check if this service has OTA characteristics
        let otaUUIDs = [
            OTAManager.OTACharacteristics.credentials,
            OTAManager.OTACharacteristics.url,
            OTAManager.OTACharacteristics.control,
            OTAManager.OTACharacteristics.status
        ]
        
        let hasOTAChars = characteristics.contains { otaUUIDs.contains($0.uuid) }
        
        print("🔍 BluetoothManager: Checking service \(service.uuid) for OTA characteristics...")
        print("   Has OTA chars: \(hasOTAChars)")
        
        if hasOTAChars {
            print("   🎯 Found OTA characteristics in this service! Passing to OTA manager...")
            // Let OTA manager handle these characteristics
            Task { @MainActor in
                otaManager.handleDiscoveredCharacteristics(characteristics, for: peripheral)
            }
        } else {
            print("   ℹ️ No OTA characteristics in this service")
        }
        #endif
        
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid), properties: \(characteristic.properties)")
            
            // Control Write characteristic
            if characteristic.uuid == controlWriteUUID {
                Task { @MainActor in
                    writeCharacteristic = characteristic
                    print("✅ Control Write characteristic found!")
                }
            }
            
            // Status Notify characteristic
            if characteristic.uuid == statusNotifyUUID {
                Task { @MainActor in
                    statusCharacteristic = characteristic
                    print("✅ Status Notify characteristic found!")
                }
                // Subscribe to notifications
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("📢 Subscribed to status notifications")
                }
            }
            
            // Galactic Status characteristic
            if characteristic.uuid == galacticStatusUUID {
                Task { @MainActor in
                    galacticStatusCharacteristic = characteristic
                    print("✅ Galactic Status characteristic found!")
                    print("   Properties: \(characteristic.properties.rawValue)")
                    print("   Has Notify: \(characteristic.properties.contains(.notify))")
                    print("   Has Read: \(characteristic.properties.contains(.read))")
                }
                // Subscribe to notifications
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("🌌 Subscribing to Galactic Status notifications...")
                } else {
                    print("⚠️ Galactic Status does not support notify!")
                }
                // Also read initial value
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    print("📖 Reading initial Galactic Status value...")
                }
            }
        }
        
        // Request initial status after characteristics are discovered
        Task { @MainActor in
            if writeCharacteristic != nil {
                // Small delay to ensure everything is ready
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                requestStatus()
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value: \(error.localizedDescription)")
        } else {
            print("Successfully wrote value to characteristic")
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Error updating notification state for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("✅ Notifications ENABLED for \(characteristic.uuid)")
        } else {
            print("⚠️ Notifications DISABLED for \(characteristic.uuid)")
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error reading value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        print("Received data from \(characteristic.uuid): \(data.map { String(format: "%02X", $0) }.joined())")
        
        // Handle different characteristics
        Task { @MainActor in
            if characteristic.uuid == galacticStatusUUID {
                parseGalacticStatus(data)
            } else if characteristic.uuid == statusNotifyUUID {
                parseStatusResponse(data)
            } else {
                #if !os(watchOS)
                if characteristic.uuid == OTAManager.OTACharacteristics.status {
                    // Handle OTA status updates
                    otaManager.handleStatusUpdate(data)
                }
                #endif
            }
        }
    }
    
    @MainActor
    private func parseStatusResponse(_ data: Data) {
        // Parse responses from your custom BT device
        guard data.count >= 2 else {
            print("⚠️ Received incomplete status response")
            return
        }
        
        let commandType = data[0]
        
        // Debug: Print full response with context
        let hexData = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📥 Status Response - Type: 0x\(String(format: "%02X", commandType)), Full data: [\(hexData)]")
        
        switch commandType {
        case 0x01: // Preset response (single preset update)
            let value = data[1]
            switch value {
            case 0x00: currentPreset = .office
            case 0x01: currentPreset = .full
            case 0x02: currentPreset = .night
            case 0x03: currentPreset = .speech
            default:
                print("⚠️ Unknown preset value: \(value)")
            }
            print("✅ Updated preset to: \(currentPreset?.rawValue ?? "unknown")")
            
            // Check if this might actually be a multi-field status response
            if data.count >= 4 {
                print("ℹ️ Response has \(data.count) bytes - might be multi-field status:")
                print("   Byte 2: 0x\(String(format: "%02X", data[2])) (possibly loudness)")
                print("   Byte 3: 0x\(String(format: "%02X", data[3])) (possibly mute)")
                
                // Try parsing as if it's a full status
                loudnessEnabled = data[2] == 0x01
                print("   Interpreted loudness: \(loudnessEnabled == true ? "on" : "off")")
                print("   Interpreted mute: \(data[3] == 0x01 ? "muted" : "unmuted")")
            }
            
        case 0x02: // Loudness response (single loudness update)
            let value = data[1]
            loudnessEnabled = value == 0x01
            print("✅ Updated loudness to: \(loudnessEnabled == true ? "enabled" : "disabled")")
            
        case 0x03: // Full status response (recommended format)
            // Expected format: [0x03, preset, loudness, mute, ...]
            // Byte 0: 0x03 (status response)
            // Byte 1: Current preset (0x00-0x03)
            // Byte 2: Loudness state (0x00 or 0x01)
            // Byte 3: Mute state (0x00 or 0x01) - optional
            // Byte 4+: Future expansion (battery, volume, etc.)
            
            guard data.count >= 3 else {
                print("⚠️ Status response too short, expected at least 3 bytes")
                return
            }
            
            // Parse preset
            let presetValue = data[1]
            switch presetValue {
            case 0x00: currentPreset = .office
            case 0x01: currentPreset = .full
            case 0x02: currentPreset = .night
            case 0x03: currentPreset = .speech
            default:
                print("⚠️ Unknown preset in status: \(presetValue)")
            }
            
            // Parse loudness
            let loudnessValue = data[2]
            loudnessEnabled = loudnessValue == 0x01
            
            // Parse mute state if available (optional)
            if data.count >= 4 {
                let muteValue = data[3]
                print("ℹ️ Mute state: \(muteValue == 0x01 ? "muted" : "unmuted")")
            }
            
            print("✅ Status updated - Preset: \(currentPreset?.rawValue ?? "unknown"), Loudness: \(loudnessEnabled == true ? "on" : "off")")
            
        case 0x04: // Mute response
            let value = data[1]
            print("✅ Mute state: \(value == 0x01 ? "muted" : "unmuted")")
            
        case 0x05: // Audio Duck response
            let value = data[1]
            print("✅ Audio Duck state: \(value == 0x01 ? "active (volume reduced)" : "inactive (normal volume)")")
            
        case 0x06: // Normalizer response
            let value = data[1]
            print("✅ Normalizer state: \(value == 0x01 ? "enabled (DRC active)" : "disabled")")
            
        case 0x08: // Bypass response
            let value = data[1]
            print("✅ DSP Bypass state: \(value == 0x01 ? "enabled (EQ bypassed)" : "disabled (full DSP)")")
            
        case 0x09: // Bass boost response
            let value = data[1]
            print("✅ Bass Boost state: \(value == 0x01 ? "enabled (enhanced bass)" : "disabled")")
            
        default:
            print("⚠️ Unknown response type: 0x\(String(format: "%02X", commandType))")
        }
    }
    
    @MainActor
    private func parseGalacticStatus(_ data: Data) {
        // Parse GALACTIC_STATUS characteristic (7 bytes)
        // Format: [VER][PRESET][FLAGS][ENERGY][VOLUME][BATTERY][LAST_CONTACT]
        
        guard data.count >= 7 else {
            print("⚠️ Galactic Status too short: expected 7 bytes, got \(data.count)")
            return
        }
        
        let status = GalacticStatus(
            protocolVersion: data[0],
            currentQuantumFlavor: data[1],
            shieldStatus: GalacticStatus.ShieldStatus(byte: data[2]),
            energyCoreLevel: data[3],
            distortionFieldStrength: data[4],
            energyCore: data[5],
            lastContact: data[6],
            receivedAt: Date()  // Timestamp when iOS received this update
        )
        
        // Verify protocol version
        if status.protocolVersion != 0x42 {
            print("⚠️ Unexpected protocol version: 0x\(String(format: "%02X", status.protocolVersion))")
        }
        
        // Update published state
        galacticStatus = status
        
        // Also update the simple state properties for compatibility
        currentPreset = status.preset
        loudnessEnabled = status.shieldStatus.isLoudnessOn
        
        #if !os(watchOS)
        // Forward status update to watch
        watchConnectivityManager?.updateGalacticStatus(status)
        #endif
        
        print("🌌 Galactic Status:")
        print("   Protocol: 0x\(String(format: "%02X", status.protocolVersion))")
        print("   Quantum Flavor: \(status.preset?.rawValue ?? "UNKNOWN")")
        print("   Shield Status:")
        print("      - Muted: \(status.shieldStatus.isMuted)")
        print("      - Panic Mode: \(status.shieldStatus.isPanicMode)")
        print("      - Loudness: \(status.shieldStatus.isLoudnessOn)")
        print("      - Limiter Active: \(status.shieldStatus.isLimiterActive)")
        print("      - Bypass Active: \(status.shieldStatus.isBypassActive)")
        print("      - Bass Boost Active: \(status.shieldStatus.isBassBoostActive)")
        print("   Energy Core Level: \(status.energyCoreLevel)")
        print("   Distortion Field: \(status.distortionFieldStrength)")
        print("   Energy Core: \(status.energyCore)")
        print("   Last Contact: \(status.lastContact)s ago")
    }
}
