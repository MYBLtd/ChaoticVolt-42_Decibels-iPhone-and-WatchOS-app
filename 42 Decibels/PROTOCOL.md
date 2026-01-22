# 42 Decibels BLE Protocol Documentation

## Control Commands (Characteristic: 0x0002)

All commands are sent as 2-byte packets: `[COMMAND_TYPE, VALUE]`

### Command Types

| Command | Byte 0 | Byte 1 | Description |
|---------|--------|--------|-------------|
| **Set Preset** | `0x01` | `0x00-0x03` | Change DSP preset |
| **Set Loudness** | `0x02` | `0x00-0x01` | Enable/disable loudness compensation |
| **Request Status** | `0x03` | `0x00` | Request full status update |
| **Set Mute** | `0x04` | `0x00-0x01` | Mute/unmute audio completely |
| **Set Audio Duck** | `0x05` | `0x00-0x01` | Enable/disable Audio Duck (volume reduction) |
| **Set Normalizer** | `0x06` | `0x00-0x01` | Enable/disable Normalizer/DRC |

### Preset Values (for Command 0x01)

| Value | Preset | Description |
|-------|--------|-------------|
| `0x00` | OFFICE | Balanced sound for office/desk use |
| `0x01` | FULL | Full-range audio |
| `0x02` | NIGHT | Reduced bass, enhanced clarity |
| `0x03` | SPEECH | Optimized for voice content |

### Command Examples

```
// Set preset to NIGHT
0x01 0x02

// Enable loudness compensation
0x02 0x01

// Enable Audio Duck (reduce volume to ~25%)
0x05 0x01

// Disable Audio Duck (restore normal volume)
0x05 0x00

// Enable Normalizer (dynamic range compression)
0x06 0x01

// Mute audio
0x04 0x01
```

---

## Status Responses (Characteristic: 0x0003)

The device can respond with status updates via notifications on this characteristic.

### Response Format

Simple response: `[COMMAND_TYPE, VALUE]`

Multi-field response (recommended): `[0x03, PRESET, LOUDNESS, MUTE, ...]`

### Response Types

| Type | Format | Description |
|------|--------|-------------|
| **Preset Update** | `[0x01, preset_value]` | Current preset changed |
| **Loudness Update** | `[0x02, 0x00/0x01]` | Loudness state changed |
| **Full Status** | `[0x03, preset, loudness, mute, ...]` | Complete state |
| **Mute Update** | `[0x04, 0x00/0x01]` | Mute state changed |
| **Audio Duck Update** | `[0x05, 0x00/0x01]` | Audio Duck state changed |
| **Normalizer Update** | `[0x06, 0x00/0x01]` | Normalizer state changed |

---

## Galactic Status (Characteristic: 0x0004)

This characteristic provides a comprehensive status snapshot as a 7-byte packet.

### Packet Format

```
[VER][PRESET][FLAGS][ENERGY][VOLUME][BATTERY][LAST_CONTACT]
 0     1       2      3       4       5        6
```

### Byte Descriptions

| Byte | Field | Type | Description |
|------|-------|------|-------------|
| 0 | Protocol Version | `uint8` | Always `0x42` |
| 1 | Current Preset | `uint8` | Active preset (0-3) |
| 2 | Shield Status | Bitfield | Status flags (see below) |
| 3 | Energy Core Level | `uint8` | Reserved (0-100) |
| 4 | Distortion Field | `uint8` | Volume level (0-100) |
| 5 | Battery Level | `uint8` | Battery percentage (0-100) |
| 6 | Last Contact | `uint8` | Seconds since last BLE interaction |

### Shield Status Bitfield (Byte 2)

| Bit | Mask | Field | Description |
|-----|------|-------|-------------|
| 0 | `0x01` | Muted | Audio is muted |
| 1 | `0x02` | Audio Duck | Volume reduced (panic mode) |
| 2 | `0x04` | Loudness | Loudness compensation enabled |
| 3 | `0x08` | Normalizer | Dynamic range compression enabled |
| 4-7 | - | Reserved | Future use |

### Example Galactic Status

```
42 01 06 64 50 64 00
```

Interpretation:
- Protocol Version: `0x42` ✓
- Preset: `0x01` (FULL)
- Shield Status: `0x06` (bits 1 and 2 set)
  - Muted: NO
  - Audio Duck: YES (volume reduced)
  - Loudness: YES
  - Normalizer: NO
- Energy Core: 100%
- Volume: 50%
- Battery: 100%
- Last Contact: 0 seconds ago (✓ just updated)

---

## ⚠️ IMPORTANT: Last Contact Field Implementation

The **Last Contact** field (Byte 6) should represent the time since the **most recent BLE interaction**. This field must be **reset to 0** whenever:

1. ✅ The ESP32 receives a command from iOS
2. ✅ The ESP32 sends/notifies the Galactic Status characteristic
3. ✅ Any BLE read/write occurs

### Correct ESP32 Implementation

```cpp
uint32_t lastBleInteractionTime = 0;  // millis() timestamp

// Called whenever ANY BLE command is received
void onCharacteristicWrite(BLECharacteristic* pCharacteristic) {
    lastBleInteractionTime = millis();  // RESET timer
    
    uint8_t* data = pCharacteristic->getData();
    // ... handle command ...
}

// Called when building Galactic Status packet
void updateGalacticStatus() {
    uint32_t elapsed = millis() - lastBleInteractionTime;
    uint8_t lastContactSeconds = min(255, elapsed / 1000);
    
    galacticStatus[6] = lastContactSeconds;
    
    pGalacticStatusChar->setValue(galacticStatus, 7);
    pGalacticStatusChar->notify();
    
    // IMPORTANT: Reset after notifying (this IS a BLE interaction!)
    lastBleInteractionTime = millis();
}
```

### Expected Behavior

When working correctly:
- ✅ Last Contact shows **0-2 seconds** most of the time (iOS app polls regularly)
- ✅ Number resets to 0 when you press any button
- ✅ Number increases slowly when idle (no commands sent)
- ❌ Should NOT continuously count up to 87+ seconds while actively using the app

### iOS Fallback

The iOS app now tracks its own timestamp (`receivedAt`) for each Galactic Status update, so even if the ESP32's Last Contact field is incorrect, the iOS app will show accurate timing based on when it last received data.

---

## Implementation Notes for ESP32

### Audio Duck Implementation

When Audio Duck is enabled (`0x05 0x01`):
1. Store current volume level
2. Reduce volume to 25-30% of current level
3. Set bit 1 in Shield Status byte
4. Update Galactic Status characteristic
5. Send response: `[0x05, 0x01]`

When Audio Duck is disabled (`0x05 0x00`):
1. Restore previous volume level
2. Clear bit 1 in Shield Status byte
3. Update Galactic Status characteristic
4. Send response: `[0x05, 0x00]`

### Normalizer Implementation

When Normalizer is enabled (`0x06 0x01`):
1. Enable dynamic range compression in DSP
2. Typical settings:
   - Threshold: -20 dB
   - Ratio: 4:1
   - Attack: 5-10 ms
   - Release: 100-200 ms
3. Set bit 3 in Shield Status byte
4. Update Galactic Status characteristic
5. Send response: `[0x06, 0x01]`

### Recommended Response Strategy

For any command:
1. Execute the command
2. Send simple acknowledgment on Status Notify (0x0003)
3. Update Galactic Status characteristic (0x0004)
4. Trigger notification on Galactic Status

This ensures the iOS app stays in sync with the actual device state.

---

## Characteristic Properties

| UUID | Name | Properties | Purpose |
|------|------|------------|---------|
| `0x0002` | Control Write | Write (with/without response) | Send commands to device |
| `0x0003` | Status Notify | Notify, Read | Receive simple status updates |
| `0x0004` | Galactic Status | Notify, Read | Receive comprehensive status snapshot |

---

## Testing Checklist

- [ ] Audio Duck reduces volume to ~25%
- [ ] Audio Duck restores previous volume when disabled
- [ ] Normalizer applies appropriate compression
- [ ] Galactic Status updates reflect Audio Duck state (bit 1)
- [ ] Galactic Status updates reflect Normalizer state (bit 3)
- [ ] All four shield status pills work independently
- [ ] Quick Duck toolbar button activates Audio Duck
- [ ] Orange overlay appears during Audio Duck mode
- [ ] Status updates arrive within 100ms of command

---

*Last Updated: 2026-01-22*
