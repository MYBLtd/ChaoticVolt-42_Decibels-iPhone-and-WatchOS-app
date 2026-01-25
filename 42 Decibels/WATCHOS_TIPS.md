# watchOS Best Practices & Tips

## Apple Watch Design Guidelines

### Screen Sizes to Consider
- 38mm: 136×170 pixels (1st gen through Series 3)
- 40mm: 162×197 pixels (Series 4-6, SE)
- 41mm: 176×215 pixels (Series 7-9)
- 42mm: 156×195 pixels (1st gen through Series 3)  
- 44mm: 184×224 pixels (Series 4-6, SE)
- 45mm: 198×242 pixels (Series 7-9, Ultra)
- 49mm: 205×251 pixels (Ultra)

**Tip:** Test on both small (40mm) and large (45mm) simulators!

## UI/UX Best Practices

### ✅ DO:
- **Keep it simple:** 1-2 taps to accomplish a task
- **Use icons:** More recognizable than text at small sizes
- **Large tap targets:** Minimum 44pt for comfortable tapping
- **Vertical scrolling:** Users expect to scroll with Digital Crown
- **Show critical info first:** Most important controls at the top
- **Use system colors:** They adapt to always-on display
- **Provide haptic feedback:** Confirm actions with taptic engine

### ❌ DON'T:
- **Horizontal scrolling:** Hard to do with crown
- **Tiny text:** Below 11pt is hard to read
- **Complex layouts:** 3+ columns won't fit
- **Long text blocks:** Users want glanceable info
- **Bright colors:** Drain battery in always-on mode
- **Too many buttons:** 4-6 is max per screen

## Performance Tips

### Battery Optimization
```swift
// ✅ Good: Only update when view is visible
struct WatchContentView: View {
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ContentView()
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    // Resume BLE operations
                    bluetoothManager.requestStatus()
                case .background:
                    // Reduce update frequency
                    break
                case .inactive:
                    // App is transitioning
                    break
                @unknown default:
                    break
                }
            }
    }
}
```

### Memory Management
- Watch apps have ~32MB memory limit (vs 1-6GB on iPhone)
- Keep image assets small and optimized
- Use lazy loading for lists
- Clear caches when backgrounded

### Bluetooth on Watch
- Range is typically shorter than iPhone (smaller antenna)
- Connection might drop faster when moving away
- Consider adding auto-reconnect logic
- Show connection quality indicator

## Accessibility

### VoiceOver Support
```swift
// Add accessibility labels to buttons
Button {
    bluetoothManager.setPreset(.night)
} label: {
    Image(systemName: "moon.stars")
}
.accessibilityLabel("Night Mode")
.accessibilityHint("Reduces bass and limits volume for nighttime listening")
```

### Dynamic Type
```swift
// Support larger text sizes
Text("Volume")
    .font(.caption)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Limit max size
```

## Digital Crown Integration

### Optional Enhancement: Volume Control
```swift
struct WatchContentView: View {
    @State private var volumeValue: Double = 50.0
    @FocusState private var volumeFocused: Bool
    
    var body: some View {
        VStack {
            // ... other controls ...
            
            HStack {
                Text("Volume")
                Spacer()
                Text("\(Int(volumeValue))%")
                    .foregroundStyle(.secondary)
            }
            .focusable()
            .focused($volumeFocused)
            .digitalCrownRotation($volumeValue, from: 0, through: 100, by: 1)
            .onChange(of: volumeValue) { newValue in
                if volumeFocused {
                    bluetoothManager.setVolume(UInt8(newValue))
                }
            }
        }
    }
}
```

## Complications (Future Enhancement)

### Types of Complications
- **Circular:** Perfect for status indicator
- **Rectangular:** Good for preset name
- **Corner:** Compact icon + text
- **Graphic:** Full-color rich display

### Example Implementation
```swift
import WidgetKit

struct SpeckerStatusEntry: TimelineEntry {
    let date: Date
    let preset: BluetoothManager.DSPPreset?
    let isConnected: Bool
}

@main
struct SpeckerComplication: Widget {
    let kind: String = "SpeakerComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("42 Decibels")
        .description("Quick access to speaker controls")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
```

## Testing Checklist

### On-Device Testing
- [ ] Test on actual Apple Watch (not just simulator)
- [ ] Test with different wrist positions (antenna orientation)
- [ ] Walk away from speaker to test range
- [ ] Test with iPhone screen off/locked
- [ ] Test with iPhone in airplane mode
- [ ] Verify battery impact (check Battery settings)
- [ ] Test always-on display appearance

### Edge Cases
- [ ] What happens when connection drops?
- [ ] What if user switches presets rapidly?
- [ ] What if speaker is turned off mid-session?
- [ ] What if multiple devices try to connect?
- [ ] What if Watch loses Bluetooth connection?

## Debugging on Watch

### Enable Console Logging
1. Window > Devices and Simulators
2. Select your Apple Watch
3. Click "Open Console"
4. Filter by your app's bundle ID

### Common Issues & Solutions

#### Issue: "Bluetooth Unavailable"
```
watchOS may take a few seconds to initialize BLE after app launch.
```
**Solution:** Add retry logic:
```swift
func startScanning() {
    guard centralManager.state == .poweredOn else {
        // Retry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startScanning()
        }
        return
    }
    // ... scanning code ...
}
```

#### Issue: UI freezing
```
Probably doing too much work on MainActor
```
**Solution:** Move heavy operations off main thread:
```swift
Task.detached {
    // Heavy work here
    await MainActor.run {
        // Update UI here
    }
}
```

#### Issue: "Device not found"
```
Watch might have smaller BLE range than iPhone
```
**Solution:** 
- Move Watch closer to speaker
- Ensure speaker is actively advertising
- Check if iPhone app is hogging the connection

## Localization Considerations

### Keep Text Short
Watch screens can't fit long translations. Use abbreviations:
```swift
// Good for Watch
Text("Vol")  // Instead of "Volume"
Text("Norm") // Instead of "Normalizer"

// But provide full accessibility label
.accessibilityLabel("Volume Level")
```

### Test with Longest Language
German and Russian tend to have longest text. Test with these locales.

## Submission to App Store

### What Apple Reviews
- Crashes on launch
- Bluetooth permissions properly requested
- UI fits on all Watch sizes
- No placeholder content
- Privacy policy (if collecting data)

### Metadata
Your Watch app appears as part of your iOS app:
- Same App Store listing
- Same screenshots (but add Watch screenshots!)
- Same description
- Users install via iPhone's Watch app

### Watch Screenshots
Required sizes:
- 396×484 (40mm)
- 448×536 (45mm)

**Tip:** Take screenshots on both sizes to show it works on small and large watches!

## Power User Features

### Quick Launch
Users can add your app to Watch Dock:
1. Open app on Watch
2. Swipe up for Control Center  
3. Tap "Keep in Dock"

Now they can access it without going through app list!

### Siri Integration (Future)
```swift
import Intents

struct SetPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Speaker Preset"
    
    @Parameter(title: "Preset")
    var preset: BluetoothManager.DSPPreset
    
    func perform() async throws -> some IntentResult {
        // Implementation
    }
}
```

This enables:
- "Hey Siri, set speaker to Night mode"
- Shortcuts app integration
- Automation triggers

## Common User Scenarios

### Morning Routine
1. Tap app from Dock
2. Tap "Office" preset
3. Raise to wake shows "Live" status
4. Lower wrist (app stays connected in background briefly)

### Late Night
1. Raise wrist
2. Force touch or long press for "Night" mode
3. Volume automatically capped
4. Tap "Disconnect" to save battery

### Emergency Mute
1. Raise wrist
2. Tap "Mute" button
3. Haptic confirms
4. Audio instantly cut

## Resources

### Apple Documentation
- [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/watchos)
- [WatchKit Programming Guide](https://developer.apple.com/watchos/)
- [CoreBluetooth on watchOS](https://developer.apple.com/documentation/corebluetooth)

### Sample Code
- See `WatchContentView.swift` for full implementation
- See `BluetoothManager.swift` for BLE protocol

### Community
- Apple Developer Forums (watchOS section)
- /r/watchOSBeta on Reddit
- StackOverflow [watchos] tag

---

**Remember:** The Watch is for quick, glanceable interactions. Keep it simple and fast! ⌚⚡
