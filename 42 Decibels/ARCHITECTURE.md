# 42 Decibels Architecture - iOS & watchOS

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    42 Decibels Ecosystem                     │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐                        ┌──────────────────┐
│   iPhone App     │                        │  Apple Watch App │
│   (iOS Target)   │                        │ (watchOS Target) │
│                  │                        │                  │
│  ┌────────────┐  │                        │  ┌────────────┐  │
│  │ ContentView│  │                        │  │  WatchView │  │
│  │    (iOS)   │  │                        │  │  (watchOS) │  │
│  └─────┬──────┘  │                        │  └─────┬──────┘  │
│        │         │                        │        │         │
│        v         │                        │        v         │
│  ┌────────────┐  │    ┌──────────────┐   │  ┌────────────┐  │
│  │    OTA     │  │    │  Bluetooth   │   │  │  Bluetooth │  │
│  │   Views    │  │    │   Manager    │   │  │   Manager  │  │
│  │  (iOS UI)  │  │    │  (SHARED)    │   │  │  (SHARED)  │  │
│  └────────────┘  │    └──────┬───────┘   │  └─────┬──────┘  │
│        │         │           │            │        │         │
└────────┼─────────┘           │            └────────┼─────────┘
         │                     │                     │
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                               │ Bluetooth LE
                               │
                               v
                    ┌──────────────────┐
                    │  42 Decibels     │
                    │  Bluetooth       │
                    │  Speaker         │
                    │                  │
                    │  • GALACTIC_     │
                    │    STATUS        │
                    │  • CONTROL_WRITE │
                    │  • STATUS_NOTIFY │
                    │  • OTA (iOS)     │
                    └──────────────────┘
```

## File Organization

```
42 Decibels (iOS App)
├── Shared Code (both iOS & watchOS)
│   ├── BluetoothManager.swift       ⭐ Core BLE logic
│   └── [Optional] OTAManager.swift  ⚡ Firmware updates
│
├── iOS-Specific
│   ├── _2_DecibelsApp.swift         📱 iOS app entry point
│   ├── ContentView.swift            🎨 iOS UI (full-featured)
│   ├── SplashScreenView.swift       🚀 Splash screen
│   ├── OTAViews.swift              🔧 Firmware update UI
│   ├── GalacticStatusView.swift    📊 Detailed status
│   └── Assets.xcassets             🖼️ iOS assets
│
└── watchOS-Specific
    ├── 42_Decibels_Watch_App.swift  ⌚ Watch app entry point
    ├── WatchContentView.swift       🎨 Watch UI (compact)
    └── Assets.xcassets              🖼️ Watch assets

```

## Data Flow

```
User Interaction
       │
       ▼
┌─────────────────┐
│   UI Layer      │
│ (iOS or Watch)  │
└────────┬────────┘
         │
         │ Call method (e.g., setPreset())
         │
         ▼
┌──────────────────────┐
│  BluetoothManager    │
│  @MainActor class    │
│                      │
│  Published:          │
│  • connectionState   │
│  • galacticStatus    │
│  • currentPreset     │
└────────┬─────────────┘
         │
         │ BLE Commands
         ▼
┌──────────────────────┐
│   CoreBluetooth      │
│   (System Framework) │
└────────┬─────────────┘
         │
         │ Bluetooth LE Radio
         ▼
┌──────────────────────┐
│   Speaker Hardware   │
│   • DSP              │
│   • Audio Processing │
│   • Battery          │
└──────────────────────┘
```

## Bluetooth Connection Flow

```
iPhone                Watch                 Speaker
  │                     │                      │
  │  User taps "Scan"   │                      │
  ├─────────────────────┤                      │
  │                     │                      │
  │  startScanning()    │                      │
  ├──────────────────────────────────────────► │
  │                     │                      │
  │                     │  ◄───── Advertising  │
  │  ◄──────────────────────────────────────── │
  │                     │                      │
  │  connect(device)    │                      │
  ├──────────────────────────────────────────► │
  │                     │                      │
  │  ◄─────────────────────────── Connected    │
  │                     │                      │
  │  Subscribe to       │                      │
  │  GALACTIC_STATUS    │                      │
  ├──────────────────────────────────────────► │
  │                     │                      │
  │  ◄────────────── Status Updates (1Hz)      │
  │                     │                      │
  │                     │  User taps "Scan"    │
  │                     ├──────────────────────┤
  │                     │  startScanning()     │
  │                     ├─────────────────────►│
  │                     │                      │
  │                     │  ◄───── Advertising  │
  │                     │ ◄──────────────────── │
  │                     │                      │
  │                     │  connect(device)     │
  │                     ├─────────────────────►│
  │                     │                      │
  │                     │ ◄────── Connected    │
  │                     │                      │
  │  [iOS disconnected] │  [Watch connected]   │
  │                     │                      │
  │                     │ ◄──── Status Updates │
  │                     │                      │

NOTE: Only ONE device typically connected at a time.
      Speaker accepts connections from either iOS or watchOS.
```

## Key Concepts

### 1. Independent Apps
- **iOS and watchOS apps run independently**
- No WatchConnectivity needed
- Each maintains its own Bluetooth connection
- Typically only one connects at a time

### 2. Shared Logic
- `BluetoothManager.swift` contains ALL BLE logic
- Same protocol, same commands, same behavior
- Changes to BLE code automatically work on both platforms

### 3. Platform-Specific UI
- **iOS:** Full-featured, detailed, OTA updates
- **watchOS:** Essential controls, glanceable info

### 4. Status Updates
- Speaker broadcasts status via `GALACTIC_STATUS` characteristic
- Updates sent ~1Hz (once per second)
- Both apps display real-time "Live" indicator

### 5. Controls
```
iOS/Watch App            BLE Command              Speaker Action
─────────────────────────────────────────────────────────────────
Set Preset (OFFICE)  ->  [0x01, 0x00]        ->  Change DSP mode
Set Loudness (ON)    ->  [0x02, 0x01]        ->  Enable loudness EQ
Mute                 ->  [0x04, 0x01]        ->  Mute audio output
Audio Duck           ->  [0x05, 0x01]        ->  Reduce vol to 25%
Normalizer           ->  [0x06, 0x01]        ->  Enable DRC/Limiter
```

## Testing Strategy

### Phase 1: Simulator (UI Only)
- [ ] Test iOS UI in iPhone simulator
- [ ] Test Watch UI in Watch simulator
- [ ] Verify layouts and navigation

### Phase 2: Real Devices (BLE Testing)
- [ ] Connect from iPhone -> verify all controls
- [ ] Disconnect iPhone
- [ ] Connect from Watch -> verify all controls
- [ ] Test range (Watch has smaller range than iPhone)

### Phase 3: Integration
- [ ] Test switching between devices
- [ ] Verify status updates on both platforms
- [ ] Check battery impact on Watch

## Benefits of This Architecture

✅ **Single Source of Truth:** One BLE implementation for both platforms
✅ **Independent Operation:** Watch works without iPhone nearby
✅ **Easy Maintenance:** Update BluetoothManager once, both apps benefit
✅ **Platform Optimization:** Each UI optimized for its platform
✅ **No Network Required:** Direct Bluetooth, no cloud dependencies

## Future Enhancements

### Possible Additions:
- **Complications:** Quick access from watch face
- **Widgets:** iOS 14+ home screen widgets
- **Shortcuts:** Siri integration
- **Live Activities:** Real-time status in Dynamic Island
- **Mac Catalyst:** Run iOS app on Mac

---

**The beauty of this architecture is its simplicity:**
One Bluetooth manager, two great apps, zero compromises! 🎵⌚📱
