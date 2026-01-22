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
            
            init(byte: UInt8) {
                self.isMuted = (byte & 0x01) != 0
                self.isPanicMode = (byte & 0x02) != 0
                self.isLoudnessOn = (byte & 0x04) != 0
                self.isLimiterActive = (byte & 0x08) != 0
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
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var galacticStatusCharacteristic: CBCharacteristic?
    
    // Speaker UUIDs
    private let serviceUUID = CBUUID(string: "00000001-1234-5678-9ABC-DEF012345678")
    private let controlWriteUUID = CBUUID(string: "00000002-1234-5678-9ABC-DEF012345678")
    private let statusNotifyUUID = CBUUID(string: "00000003-1234-5678-9ABC-DEF012345678")
    private let galacticStatusUUID = CBUUID(string: "00000004-1234-5678-9ABC-DEF012345678")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .error("Bluetooth is not available")
            return
        }
        
        discoveredSpeakers.removeAll()
        connectionState = .scanning
        
        // Scan for peripherals - you can specify service UUIDs if known
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
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
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let speaker = connectedSpeaker {
            centralManager.cancelPeripheralConnection(speaker)
        }
        writeCharacteristic = nil
        connectedSpeaker = nil
        connectionState = .disconnected
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
    
    // MARK: - Private Methods
    
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
            // Only add peripherals with names (filters out many non-relevant devices)
            if peripheral.name != nil, !discoveredSpeakers.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredSpeakers.append(peripheral)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("Connected to \(peripheral.name ?? "Unknown")")
            connectedSpeaker = peripheral
            connectionState = .connected
            peripheral.delegate = self
            
            // Discover all services (nil = discover all)
            // This ensures we find the service containing GALACTIC_STATUS
            peripheral.discoverServices(nil)
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .error("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
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
        
        print("🌌 Galactic Status:")
        print("   Protocol: 0x\(String(format: "%02X", status.protocolVersion))")
        print("   Quantum Flavor: \(status.preset?.rawValue ?? "UNKNOWN")")
        print("   Shield Status:")
        print("      - Muted: \(status.shieldStatus.isMuted)")
        print("      - Panic Mode: \(status.shieldStatus.isPanicMode)")
        print("      - Loudness: \(status.shieldStatus.isLoudnessOn)")
        print("      - Limiter Active: \(status.shieldStatus.isLimiterActive)")
        print("   Energy Core Level: \(status.energyCoreLevel)")
        print("   Distortion Field: \(status.distortionFieldStrength)")
        print("   Energy Core: \(status.energyCore)")
        print("   Last Contact: \(status.lastContact)s ago")
    }
}
