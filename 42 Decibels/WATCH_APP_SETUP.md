# Apple Watch Setup Guide for 42 Decibels

This guide will walk you through adding Apple Watch support to your 42 Decibels app.

## Overview

The Watch app provides a simplified interface optimized for the Apple Watch screen, allowing users to:
- Connect to their Bluetooth speaker directly from the Watch
- Switch between DSP presets (Office, Full, Night, Speech)
- Control audio features (Mute, Audio Duck, Loudness, Normalizer)
- View real-time speaker status
- See current volume level

## Step 1: Add Watch App Target in Xcode

1. **Open your project in Xcode**
2. **File > New > Target...**
3. Select **watchOS** tab at the top
4. Choose **Watch App** template
5. Click **Next**

### Configure the Watch App:
- **Product Name:** `42 Decibels Watch App`
- **Organization Identifier:** (use your existing one, e.g., `com.chaoticvolt`)
- **Bundle Identifier:** Will be `com.yourorg.42-Decibels.watchkitapp`
- **Language:** Swift
- **User Interface:** SwiftUI
- Click **Finish**
- When asked to activate the scheme, click **Activate**

## Step 2: Add Files to Watch Target

### Files that need to be in BOTH iOS and watchOS targets:
1. `BluetoothManager.swift` ✅ (Core Bluetooth logic)
2. `OTAManager.swift` (if you want OTA support on Watch)

### Files only in watchOS target:
1. `42_Decibels_Watch_App.swift` (Watch app entry point)
2. `WatchContentView.swift` (Watch UI)

### How to add existing files to Watch target:
1. Select `BluetoothManager.swift` in the Project Navigator
2. Open the **File Inspector** (right sidebar, first tab)
3. Under **Target Membership**, check the box for `42 Decibels Watch App`
4. Repeat for any other shared files

## Step 3: Update Info.plist for Bluetooth

Your Watch app needs Bluetooth permissions just like the iOS app.

1. Select the **Watch App target** in the project settings
2. Go to the **Info** tab
3. Add the following keys (if not already present):
   - **Privacy - Bluetooth Always Usage Description**
     - Value: "42 Decibels needs Bluetooth to connect to and control your speaker"
   - **Privacy - Bluetooth Peripheral Usage Description** (if targeting older watchOS)
     - Value: "42 Decibels needs Bluetooth to connect to and control your speaker"

## Step 4: Watch App Assets

### App Icon
1. In the Watch App's Assets.xcassets, add your app icon
2. You'll need icons in these sizes for watchOS:
   - 48x48 (notification center)
   - 55x55 (notification center)
   - 58x58 (@2x)
   - 66x66 (notification center)
   - 80x80 (@2x)
   - 87x87 (@3x)
   - 88x88 (circular @2x)
   - 92x92 (short look notification)
   - 100x100 (circular @2x)
   - 102x102 (short look notification)
   - 172x172 (@2x)
   - 196x196 (@2x)
   - 216x216 (@2x)
   - 234x234 (@2x)
   - 258x258 (@2x)
   - 1024x1024 (App Store)

### Logo (if needed)
- If you reference `ChaoticVoltLogo` in the Watch app, add it to the Watch App's Assets

## Step 5: Test Your Watch App

### On Simulator:
1. Select **42 Decibels Watch App** scheme from the scheme picker
2. Choose a Watch simulator (e.g., "Apple Watch Series 10 (45mm)")
3. Click **Run** (⌘R)

**Note:** Bluetooth functionality is limited in the simulator. The UI will work, but you won't be able to connect to real devices.

### On Real Device:
1. Make sure your iPhone is paired with an Apple Watch
2. Install the iOS app on your iPhone first
3. Select the Watch scheme and your paired Watch as the destination
4. Click **Run**

The Watch app will be installed on your Watch and will run independently, allowing you to control your Bluetooth speaker directly from your wrist!

## Architecture Notes

### Independent Bluetooth Connection
The Watch app maintains its **own** Bluetooth connection to the speaker. This means:
- ✅ You can control the speaker from your Watch even if your iPhone is in another room
- ✅ The Watch and iPhone apps can both connect to the speaker (though typically only one at a time)
- ✅ No dependency on WatchConnectivity framework - direct BLE connection

### Shared Code
Both apps use the same `BluetoothManager.swift` file, ensuring:
- Consistent behavior across platforms
- Single source of truth for BLE protocol
- Easy maintenance and updates

## Features on Apple Watch

### ✅ Supported Features:
- Device scanning and connection
- DSP preset switching
- Mute/Unmute
- Audio Duck (volume reduction)
- Loudness toggle
- Normalizer toggle
- Real-time status updates
- Volume display
- Live connection indicator

### ❌ Not Included (due to screen size):
- OTA firmware updates (do these on iPhone)
- Detailed status information
- Advanced debugging features

## Watch UI Design

The Watch interface is optimized for small screens:
- **Compact button layout:** 2x2 grid for quick controls
- **Minimal text:** Uses icons and short labels
- **Essential info only:** Focus on most-used controls
- **Large tap targets:** Easy to use while moving
- **Live status indicator:** Shows when speaker is actively responding

## Troubleshooting

### "BluetoothManager not found" error
- Make sure `BluetoothManager.swift` is added to the Watch target (see Step 2)

### "Cannot connect to device on Watch"
- Ensure Bluetooth permissions are added to Watch app Info.plist
- Check that the device is in range of the Watch (not just the iPhone)
- CoreBluetooth on Watch requires watchOS 4.0+

### App crashes on Watch
- Check that you're not using any iOS-only frameworks (like UIKit)
- Verify all assets referenced exist in the Watch target
- Look at the crash logs in Xcode's Devices window

## Deployment Considerations

### App Store Submission:
- The Watch app is bundled with your iOS app
- Both apps share the same app listing in the App Store
- Users can install the Watch app from their iPhone's Watch app

### Minimum Versions:
- **watchOS 9.0+** (recommended for modern SwiftUI features)
- **watchOS 7.0+** (minimum for most features to work well)

### Size Optimization:
- Keep Watch assets optimized (compress images)
- Consider excluding OTA/advanced features from Watch target
- Watch apps have stricter size limits than iOS apps

## Next Steps

Once you have the Watch app running:
1. ✅ Test all controls on a real Watch
2. ✅ Verify Bluetooth range from iPhone
3. ✅ Test disconnection/reconnection scenarios
4. ✅ Adjust UI spacing/sizing if needed for different Watch sizes
5. ✅ Add complications (future enhancement) for quick access
6. ✅ Consider adding Watch-specific haptic feedback

## Future Enhancements

Possible additions:
- **Complications:** Show speaker status on watch face
- **Siri Shortcuts:** "Hey Siri, set speaker to Night mode"
- **Live Activities:** Show audio status in Dynamic Island (iOS) and Live Activity (Watch)
- **Volume control:** Direct volume adjustment from Digital Crown
- **Widgets:** Quick access to presets

---

**Need help?** Check the Watch console logs and make sure all files are properly added to the Watch target!
