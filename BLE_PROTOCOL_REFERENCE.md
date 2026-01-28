# 42 Decibels BLE Protocol Reference

## Service and Characteristics

```
Service UUID: 00000001-1234-5678-9ABC-DEF012345678
├── Control (Write):        00000002-1234-5678-9ABC-DEF012345678
├── Status (Notify):        00000003-1234-5678-9ABC-DEF012345678
└── Galactic Status (Notify): 00000004-1234-5678-9ABC-DEF012345678
```

## Control Commands (Write to 0x0002)

| Command | Byte 0 | Byte 1 | Description |
|---------|--------|--------|-------------|
| **Set Preset** | 0x01 | 0x00-0x03 | Set DSP preset (0=Office, 1=Full, 2=Night, 3=Speech) |
| **Set Loudness** | 0x02 | 0x00/0x01 | Disable/Enable loudness compensation |
| **Request Status** | 0x03 | 0x00 | Request current device status |
| **Set Mute** | 0x04 | 0x00/0x01 | Unmute/Mute audio output |
| **Set Audio Duck** | 0x05 | 0x00/0x01 | Disable/Enable panic mode (−12 dB) |
| **Set Normalizer** | 0x06 | 0x00/0x01 | Disable/Enable DRC/limiter |
| **Set Volume** | 0x07 | 0-100 | Set volume trim level |
| **Set Bypass** | 0x08 | 0x00/0x01 | Disable/Enable DSP bypass (EQ off) |
| **Set Bass Boost** | 0x09 | 0x00/0x01 | Disable/Enable bass enhancement |

### Examples

```swift
// Swift/iOS
let bypassOn: [UInt8] = [0x08, 0x01]
peripheral.writeValue(Data(bypassOn), for: controlChar, type: .withResponse)

let bassBoostOff: [UInt8] = [0x09, 0x00]
peripheral.writeValue(Data(bassBoostOff), for: controlChar, type: .withResponse)
```

```cpp
// Arduino/ESP32
uint8_t command[] = {0x08, 0x01};  // Enable bypass
controlCharacteristic->setValue(command, 2);
controlCharacteristic->notify();
```

## Galactic Status (Notify from 0x0004)

**Format**: 7 bytes, sent periodically (e.g., every 1 second)

```
┌──────┬─────────────────────────────┬────────────────────────────┐
│ Byte │           Field             │         Description        │
├──────┼─────────────────────────────┼────────────────────────────┤
│  0   │ protocolVersion             │ Always 0x42                │
├──────┼─────────────────────────────┼────────────────────────────┤
│  1   │ currentQuantumFlavor        │ Active preset (0-3)        │
├──────┼─────────────────────────────┼────────────────────────────┤
│  2   │ shieldStatus (bitfield)     │ See bitfield table below   │
├──────┼─────────────────────────────┼────────────────────────────┤
│  3   │ energyCoreLevel             │ Reserved (0-100)           │
├──────┼─────────────────────────────┼────────────────────────────┤
│  4   │ distortionFieldStrength     │ Current volume (0-100)     │
├──────┼─────────────────────────────┼────────────────────────────┤
│  5   │ energyCore                  │ Battery level (0-100)      │
├──────┼─────────────────────────────┼────────────────────────────┤
│  6   │ lastContact                 │ Seconds since last BLE msg │
└──────┴─────────────────────────────┴────────────────────────────┘
```

### Shield Status Bitfield (Byte 2)

```
┌─────┬──────┬──────────────────────┬────────────────────────────┐
│ Bit │ Mask │       Field          │        Description         │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  0  │ 0x01 │ isMuted              │ Audio muted                │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  1  │ 0x02 │ isPanicMode          │ Audio duck active (−12 dB) │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  2  │ 0x04 │ isLoudnessOn         │ Loudness compensation on   │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  3  │ 0x08 │ isLimiterActive      │ Normalizer/DRC active      │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  4  │ 0x10 │ isBypassActive       │ DSP bypass enabled         │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│  5  │ 0x20 │ isBassBoostActive    │ Bass boost enabled         │
├─────┼──────┼──────────────────────┼────────────────────────────┤
│ 6-7 │      │ (reserved)           │ Available for future use   │
└─────┴──────┴──────────────────────┴────────────────────────────┘
```

## Parsing Examples

### Swift (iOS/watchOS)
```swift
// Parse Galactic Status
let protocolVersion = data[0]  // Should be 0x42
let preset = data[1]           // 0-3
let shieldByte = data[2]       // Bitfield

let isMuted = (shieldByte & 0x01) != 0
let isPanicMode = (shieldByte & 0x02) != 0
let isLoudnessOn = (shieldByte & 0x04) != 0
let isLimiterActive = (shieldByte & 0x08) != 0
let isBypassActive = (shieldByte & 0x10) != 0
let isBassBoostActive = (shieldByte & 0x20) != 0

let volume = data[4]           // 0-100
let battery = data[5]          // 0-100
```

### C++ (ESP32)
```cpp
// Build Galactic Status packet
uint8_t galacticStatus[7];
galacticStatus[0] = 0x42;                    // Protocol version
galacticStatus[1] = currentPreset;           // 0-3
galacticStatus[2] = buildShieldStatus();     // Bitfield
galacticStatus[3] = 0;                       // Reserved
galacticStatus[4] = currentVolume;           // 0-100
galacticStatus[5] = batteryLevel;            // 0-100
galacticStatus[6] = secondsSinceLastBLE;     // 0-255

uint8_t buildShieldStatus() {
    uint8_t status = 0;
    if (isMuted) status |= 0x01;
    if (isAudioDuck) status |= 0x02;
    if (isLoudnessOn) status |= 0x04;
    if (isNormalizerActive) status |= 0x08;
    if (isBypassActive) status |= 0x10;
    if (isBassBoostActive) status |= 0x20;
    return status;
}
```

### Python (for testing)
```python
# Parse received notification
protocol_version = data[0]
preset = data[1]
shield_status = data[2]

is_muted = bool(shield_status & 0x01)
is_panic = bool(shield_status & 0x02)
is_loudness = bool(shield_status & 0x04)
is_normalizer = bool(shield_status & 0x08)
is_bypass = bool(shield_status & 0x10)
is_bass_boost = bool(shield_status & 0x20)

volume = data[4]
battery = data[5]
last_contact = data[6]
```

## Implementation Notes

### iOS/watchOS App
- Commands are sent via `writeValue(_:for:type:)` with `.withResponse` preferred
- Status updates arrive via `peripheral(_:didUpdateValueFor:characteristic:error:)`
- The app maintains a timestamp (`receivedAt`) for each status update
- UI shows "Live" indicator when `secondsSinceReceived < 3`

### ESP32 Firmware
- Send Galactic Status notifications periodically (every 1 second recommended)
- Update `lastContact` byte based on time since last received BLE command
- Commands should be acknowledged with a response on Status characteristic (optional)
- Use `notify()` for status updates, not `indicate()` (for performance)

### Timing Considerations
- Galactic Status: Send every 1 second when active
- lastContact: Increment every second, cap at 255
- Response latency: Try to respond to commands within 100ms
- iOS reconnection: Auto-retry connection if lost

## Testing Tools

### nRF Connect (iOS/Android)
1. Connect to device
2. Find service `00000001-1234-...`
3. Enable notifications on `00000004-...` (Galactic Status)
4. Write to `00000002-...` (Control) to send commands

### Xcode Console Logs
```
✅ Control Write characteristic found!
📤 Sent command: 0801 using withResponse
🌌 Galactic Status:
   Protocol: 0x42
   Shield Status:
      - Bypass Active: true
      - Bass Boost Active: false
```

## Version History

- v1.0: Initial protocol (commands 0x01-0x07)
- v1.1: Added Bypass (0x08) and Bass Boost (0x09) controls
- Protocol version remains 0x42 (backward compatible)
