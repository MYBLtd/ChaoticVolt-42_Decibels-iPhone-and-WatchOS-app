# UI and BLE Protocol Updates

## Summary of Changes

This update implements three main UI/UX improvements and adds support for two new DSP features:

### 1. ✅ Detailed Status Section - Collapsed by Default
- Changed `isDetailedStatusExpanded` from `true` to `false`
- The "Detailed Status" section now starts collapsed, reducing visual clutter
- Users can expand it by tapping to see volume, battery, and timing information

### 2. ✅ Shield Status - Two Row Layout
- Reorganized Shield Status pills into two rows
- **First Row**: Mute, Duck, Loudness, Normalize (existing 4 shields)
- **Second Row**: Bypass, Bass boost (2 new shields + 2 empty spacers for alignment)
- Maintains consistent grid appearance with proper spacing

### 3. ✅ New BLE Controls: Bypass & Bass Boost

#### Bypass Mode (Bit 4 - 0x10)
- **Icon**: `arrow.triangle.turn.up.right.circle`
- **Color**: Purple
- **Function**: Bypasses EQ processing for pure audio passthrough
- **BLE Command**: `0x08` (DSP_CMD_SET_BYPASS)
  - Enable: `[0x08, 0x01]`
  - Disable: `[0x08, 0x00]`
- **Status Bit**: Bit 4 in shieldStatus byte (mask 0x10)

#### Bass Boost Mode (Bit 5 - 0x20)
- **Icon**: `waveform.badge.magnifyingglass`
- **Color**: Indigo
- **Function**: Enhanced low-frequency response
- **BLE Command**: `0x09` (DSP_CMD_SET_BASS_BOOST)
  - Enable: `[0x09, 0x01]`
  - Disable: `[0x09, 0x00]`
- **Status Bit**: Bit 5 in shieldStatus byte (mask 0x20)

## Updated shieldStatus Bitfield (Byte 2)

```
┌─────┬──────┬────────────────────┐
│ Bit │ Mask │      Meaning       │
├─────┼──────┼────────────────────┤
│ 0   │ 0x01 │ Muted              │
├─────┼──────┼────────────────────┤
│ 1   │ 0x02 │ Audio Duck (panic) │
├─────┼──────┼────────────────────┤
│ 2   │ 0x04 │ Loudness           │
├─────┼──────┼────────────────────┤
│ 3   │ 0x08 │ Normalizer         │
├─────┼──────┼────────────────────┤
│ 4   │ 0x10 │ DSP Bypass         │ ⭐ NEW
├─────┼──────┼────────────────────┤
│ 5   │ 0x20 │ Bass Boost         │ ⭐ NEW
└─────┴──────┴────────────────────┘
```

## Files Modified

### ContentView.swift
- Updated `isDetailedStatusExpanded` default value to `false`
- Added second row to `shieldStatusPills()` with Bypass and Bass boost controls
- Added calls to `bluetoothManager.setBypass()` and `bluetoothManager.setBassBoost()`

### BluetoothManager.swift
- Extended `ShieldStatus` struct with two new properties:
  - `isBypassActive: Bool` (bit 4)
  - `isBassBoostActive: Bool` (bit 5)
- Added two new Command enum cases:
  - `.bypass(Bool)` → `0x08` command
  - `.bassBoost(Bool)` → `0x09` command
- Added public methods:
  - `func setBypass(_ enabled: Bool)`
  - `func setBassBoost(_ enabled: Bool)`
- Updated `parseStatusResponse()` to handle 0x08 and 0x09 responses
- Updated `parseGalacticStatus()` logging to show bypass and bass boost states

## Testing Checklist

- [ ] Detailed Status starts collapsed by default
- [ ] Shield Status displays in two rows
- [ ] Bypass shield appears in second row
- [ ] Bass boost shield appears in second row
- [ ] Tapping Bypass sends `0x08` command
- [ ] Tapping Bass boost sends `0x09` command
- [ ] Bypass state updates correctly when status is received
- [ ] Bass boost state updates correctly when status is received
- [ ] Visual feedback (colors, icons) work for both new shields
- [ ] Info popover shows correct descriptions

## Firmware Requirements

Your ESP32 firmware should now handle these additional commands:

```cpp
// In your BLE control characteristic handler:
case 0x08:  // DSP_CMD_SET_BYPASS
    if (rxValue[1] == 0x01) {
        // Enable bypass mode (bypass EQ)
    } else {
        // Disable bypass mode (full DSP)
    }
    break;

case 0x09:  // DSP_CMD_SET_BASS_BOOST
    if (rxValue[1] == 0x01) {
        // Enable bass boost
    } else {
        // Disable bass boost
    }
    break;
```

And update your GalacticStatus byte 2 to include these bits:
```cpp
uint8_t shieldStatus = 0;
if (isMuted) shieldStatus |= 0x01;
if (isAudioDuck) shieldStatus |= 0x02;
if (isLoudnessOn) shieldStatus |= 0x04;
if (isNormalizerActive) shieldStatus |= 0x08;
if (isBypassActive) shieldStatus |= 0x10;  // NEW
if (isBassBoostActive) shieldStatus |= 0x20;  // NEW
```
