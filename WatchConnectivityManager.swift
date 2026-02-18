//
//  WatchConnectivityManager.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-28.
//
//  Manages communication between iPhone and Apple Watch
//  to enable hybrid connectivity mode.

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the watch is reachable (for immediate messaging)
    @Published var isWatchReachable = false
    
    /// Whether the iPhone is reachable (Watch side)
    @Published var isPhoneReachable = false
    
    /// Connection state from the counterpart device
    @Published var counterpartConnectionState: ConnectionInfo?
    
    // MARK: - Connection Info
    
    struct ConnectionInfo: Codable, Equatable {
        let isConnected: Bool
        let speakerName: String?
        let speakerIdentifier: String?
        
        enum CodingKeys: String, CodingKey {
            case isConnected
            case speakerName
            case speakerIdentifier
        }
    }
    
    // MARK: - Message Keys
    
    enum MessageKey {
        static let connectionState = "connectionState"
        static let command = "command"
        static let commandType = "commandType"
        static let commandData = "commandData"
        static let galacticStatus = "galacticStatus"
    }
    
    // Make keys accessible externally for reply handlers
    static let connectionStateKey = "connectionState"
    
    // MARK: - Command Types
    
    enum CommandType: String, Codable {
        case setPreset
        case setMute
        case setAudioDuck
        case setLoudness
        case setNormalizer
        case setBypass
        case setBassBoost
        case requestStatus
        case disconnect
    }
    
    // MARK: - Session
    
    private var session: WCSession?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Public Methods (iOS)
    
    #if !os(watchOS)
    /// Update the watch with current connection state (iOS only)
    func updateConnectionState(isConnected: Bool, speakerName: String?, speakerIdentifier: String?) {
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let info = ConnectionInfo(
            isConnected: isConnected,
            speakerName: speakerName,
            speakerIdentifier: speakerIdentifier
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(info)
            let message = [MessageKey.connectionState: data]
            
            // Try immediate delivery if watch is reachable
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("⚠️ Failed to send connection state: \(error.localizedDescription)")
                }
            }
            
            // Always update application context for eventual delivery
            try session.updateApplicationContext(message)
        } catch {
            print("⚠️ Failed to encode connection state: \(error)")
        }
    }
    
    /// Forward GalacticStatus update to watch (iOS only)
    func updateGalacticStatus(_ status: BluetoothManager.GalacticStatus) {
        guard let session = session, session.isReachable else { return }
        
        // Create a simplified dictionary representation
        let statusDict: [String: Any] = [
            "protocolVersion": status.protocolVersion,
            "currentQuantumFlavor": status.currentQuantumFlavor,
            "shieldStatusByte": status.shieldStatus.rawByte,
            "energyCoreLevel": status.energyCoreLevel,
            "distortionFieldStrength": status.distortionFieldStrength,
            "energyCore": status.energyCore,
            "lastContact": status.lastContact,
            "receivedAt": status.receivedAt.timeIntervalSince1970
        ]
        
        let message = [MessageKey.galacticStatus: statusDict]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("⚠️ Failed to send galactic status: \(error.localizedDescription)")
        }
    }
    #endif
    
    // MARK: - Public Methods (watchOS)
    
    #if os(watchOS)
    /// Send a command to the iPhone to execute (Watch only)
    func sendCommand(type: CommandType, data: Data) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable, cannot send command")
            return
        }
        
        let message: [String: Any] = [
            MessageKey.commandType: type.rawValue,
            MessageKey.commandData: data
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("⚠️ Failed to send command: \(error.localizedDescription)")
        }
    }
    
    /// Request the current connection state from iPhone (Watch only)
    func requestConnectionState() {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }
        
        let message = ["requestConnectionState": true]
        
        session.sendMessage(message, replyHandler: { reply in
            Task { @MainActor in
                if let data = reply[MessageKey.connectionState] as? Data {
                    let decoder = JSONDecoder()
                    if let info = try? decoder.decode(ConnectionInfo.self, from: data) {
                        self.counterpartConnectionState = info
                    }
                }
            }
        }) { error in
            print("⚠️ Failed to request connection state: \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("⚠️ WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("✅ WCSession activated with state: \(activationState.rawValue)")
                
                #if os(watchOS)
                isPhoneReachable = session.isReachable
                // Request initial connection state
                requestConnectionState()
                #else
                isWatchReachable = session.isReachable
                #endif
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            #if os(watchOS)
            isPhoneReachable = session.isReachable
            print("📱 iPhone reachable: \(session.isReachable)")
            
            if session.isReachable {
                // Request connection state when iPhone becomes reachable
                requestConnectionState()
            }
            #else
            isWatchReachable = session.isReachable
            print("⌚ Watch reachable: \(session.isReachable)")
            #endif
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            handleReceivedMessage(message)
            
            // If it's a request for connection state, reply with current state
            #if !os(watchOS)
            if message["requestConnectionState"] as? Bool == true {
                // Reply will be sent by iOS BluetoothManager
                NotificationCenter.default.post(name: .requestConnectionStateForWatch, object: nil, userInfo: ["replyHandler": replyHandler])
            }
            #endif
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleReceivedMessage(applicationContext)
        }
    }
    
    // MARK: - iOS Only Delegate Methods
    
    #if !os(watchOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated, reactivating...")
        session.activate()
    }
    #endif
    
    // MARK: - Message Handling
    
    @MainActor
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Handle connection state updates
        if let data = message[MessageKey.connectionState] as? Data {
            let decoder = JSONDecoder()
            if let info = try? decoder.decode(ConnectionInfo.self, from: data) {
                counterpartConnectionState = info
                print("📲 Received connection state: connected=\(info.isConnected), speaker=\(info.speakerName ?? "nil")")
            }
        }
        
        #if !os(watchOS)
        // iOS: Handle commands from Watch
        if let commandTypeString = message[MessageKey.commandType] as? String,
           let commandType = CommandType(rawValue: commandTypeString),
           let commandData = message[MessageKey.commandData] as? Data {
            
            print("📲 Received command from watch: \(commandType)")
            
            // Post notification for BluetoothManager to handle
            NotificationCenter.default.post(
                name: .executeCommandFromWatch,
                object: nil,
                userInfo: ["commandType": commandType, "commandData": commandData]
            )
        }
        #endif
        
        #if os(watchOS)
        // watchOS: Handle GalacticStatus updates from iPhone
        if let statusDict = message[MessageKey.galacticStatus] as? [String: Any] {
            print("📲 Received galactic status from iPhone")
            
            // Post notification for WatchContentView to handle
            NotificationCenter.default.post(
                name: .receivedGalacticStatusFromPhone,
                object: nil,
                userInfo: statusDict
            )
        }
        #endif
    }
}

// MARK: - Helper Extension for ShieldStatus

extension BluetoothManager.GalacticStatus.ShieldStatus {
    var rawByte: UInt8 {
        var byte: UInt8 = 0
        if isMuted { byte |= 0x01 }
        if isPanicMode { byte |= 0x02 }
        if isLoudnessOn { byte |= 0x04 }
        if isLimiterActive { byte |= 0x08 }
        if isBypassActive { byte |= 0x10 }
        if isBassBoostActive { byte |= 0x20 }
        return byte
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let executeCommandFromWatch = Notification.Name("executeCommandFromWatch")
    static let requestConnectionStateForWatch = Notification.Name("requestConnectionStateForWatch")
    static let receivedGalacticStatusFromPhone = Notification.Name("receivedGalacticStatusFromPhone")
}
