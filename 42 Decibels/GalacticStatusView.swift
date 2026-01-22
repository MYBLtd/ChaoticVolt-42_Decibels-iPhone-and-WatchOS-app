//
//  GalacticStatusView.swift
//  42 Decibels
//
//  Created by Robin on 2026-01-21.
//

import SwiftUI

struct GalacticStatusView: View {
    let status: BluetoothManager.GalacticStatus
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Galactic Status")
                    .font(.headline)
                
                Spacer()
                
                // Protocol version badge
                Text("v\(String(format: "%02X", status.protocolVersion))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Shield Status (Flags)
            VStack(alignment: .leading, spacing: 8) {
                Label("Shield Status", systemImage: "shield.checkered")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    StatusPill(
                        title: "Mute",
                        isActive: status.shieldStatus.isMuted,
                        icon: "speaker.slash.fill",
                        activeColor: .red
                    )
                    
                    StatusPill(
                        title: "Panic",
                        isActive: status.shieldStatus.isPanicMode,
                        icon: "exclamationmark.shield",
                        activeColor: .orange
                    )
                    
                    StatusPill(
                        title: "Loudness",
                        isActive: status.shieldStatus.isLoudnessOn,
                        icon: "speaker.wave.3",
                        activeColor: .blue
                    )
                    
                    StatusPill(
                        title: "Limiter",
                        isActive: status.shieldStatus.isLimiterActive,
                        icon: "waveform.path.ecg",
                        activeColor: .green
                    )
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Quantum Flavor (Preset)
            HStack {
                Image(systemName: presetIcon)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quantum Flavor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(status.preset?.rawValue ?? "UNKNOWN")
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Last Contact
            HStack {
                Image(systemName: lastContactIcon)
                    .font(.title3)
                    .foregroundStyle(lastContactColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Contact")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(lastContactText)
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Optional: Energy/Volume/Battery (if you implement them later)
            if status.energyCoreLevel > 0 || status.distortionFieldStrength > 0 || status.energyCore > 0 {
                VStack(spacing: 8) {
                    if status.energyCoreLevel > 0 {
                        MeterView(
                            title: "Energy Core Level",
                            value: Int(status.energyCoreLevel),
                            icon: "bolt.fill",
                            color: .yellow
                        )
                    }
                    
                    if status.distortionFieldStrength > 0 {
                        MeterView(
                            title: "Distortion Field",
                            value: Int(status.distortionFieldStrength),
                            icon: "waveform",
                            color: .orange
                        )
                    }
                    
                    if status.energyCore > 0 {
                        MeterView(
                            title: "Battery",
                            value: Int(status.energyCore),
                            icon: "battery.100",
                            color: .green
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var presetIcon: String {
        switch status.preset {
        case .office: return "building.2"
        case .full: return "speaker.wave.3"
        case .night: return "moon.stars"
        case .speech: return "person.wave.2"
        case .none: return "questionmark.circle"
        }
    }
    
    private var lastContactText: String {
        let seconds = Int(status.lastContact)
        
        if seconds == 0 {
            return "Just now"
        } else if seconds == 1 {
            return "1 second ago"
        } else if seconds < 60 {
            return "\(seconds) seconds ago"
        } else if seconds == 255 {
            return ">4 minutes ago"
        } else {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
    }
    
    private var lastContactIcon: String {
        let seconds = Int(status.lastContact)
        
        if seconds == 0 {
            return "checkmark.circle.fill"
        } else if seconds < 5 {
            return "clock.fill"
        } else if seconds < 30 {
            return "clock"
        } else {
            return "clock.badge.exclamationmark"
        }
    }
    
    private var lastContactColor: Color {
        let seconds = Int(status.lastContact)
        
        if seconds == 0 {
            return .green
        } else if seconds < 5 {
            return .blue
        } else if seconds < 30 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
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

// MARK: - Meter View

struct MeterView: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        // Fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(value) / 100.0, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            Text("\(value)%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(width: 45, alignment: .trailing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        GalacticStatusView(
            status: BluetoothManager.GalacticStatus(
                protocolVersion: 0x42,
                currentQuantumFlavor: 1,
                shieldStatus: BluetoothManager.GalacticStatus.ShieldStatus(byte: 0b00001101),
                energyCoreLevel: 75,
                distortionFieldStrength: 60,
                energyCore: 85,
                lastContact: 3,
                receivedAt: Date()  // Add the timestamp
            )
        )
        .padding()
        
        Spacer()
    }
}
