# WiFi Network Detection Setup

This guide explains how to enable WiFi network detection for the OTA firmware update feature.

## What Changed

The app can now automatically detect and pre-fill the WiFi network name (SSID) that your iPhone is currently connected to. This eliminates the need to manually type the network name.

### New Features

1. **Auto-fill Current Network**: When you open the firmware update sheet, it automatically tries to detect your current WiFi network
2. **"Use Current WiFi Network" Button**: Tap this to re-fetch the current network at any time
3. **Better UX**: Shows loading state and error messages if detection fails
4. **Manual Override**: You can still manually type any network name if needed

## Required Setup in Xcode

To use WiFi network detection, you need to add the **Access WiFi Information** capability:

### Step 1: Add Capability

1. Open your project in Xcode
2. Select your app target (not the project)
3. Click the **"Signing & Capabilities"** tab
4. Click the **"+ Capability"** button
5. Search for and add **"Access WiFi Information"**

This will automatically add the required entitlement to your app.

### Step 2: Update Info.plist (Optional, but Recommended)

Add a privacy description explaining why you need WiFi information:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need access to WiFi information to auto-configure your speaker with your current network during firmware updates.</string>
```

**Note**: On iOS 13+, accessing WiFi information requires location permission or the Access WiFi Information entitlement. With the entitlement, you don't need to request location permission.

## How It Works

### User Experience

1. User taps "Update Firmware"
2. Sheet opens and automatically detects current WiFi network
3. SSID field is pre-filled (e.g., "MyHomeNetwork")
4. User only needs to enter the password
5. User taps "Start Update"

### Technical Flow

```swift
// Automatically called when sheet appears
private func fetchCurrentWiFiNetwork() {
    Task {
        do {
            let networks = try await NEHotspotNetwork.fetchCurrent()
            if let network = networks.first {
                ssid = network.ssid  // Auto-fill the text field
            }
        } catch {
            // Show error message to user
        }
    }
}
```

### API Used

- **Framework**: `NetworkExtension`
- **Class**: `NEHotspotNetwork`
- **Method**: `fetchCurrent()` - Returns array of WiFi networks (usually just one)
- **Property**: `ssid` - The network name

## Limitations

### What Works ✅

- Detects the SSID of the WiFi network your iPhone is **currently connected to**
- Works on WiFi networks (both 2.4GHz and 5GHz on iPhone side)
- No user permission dialog needed (with the entitlement)

### What Doesn't Work ❌

- **Cannot scan for nearby networks** - iOS doesn't allow apps to see available WiFi networks
- **Cannot get WiFi password** - For obvious security reasons, iOS never shares passwords
- **Cannot detect 2.4GHz vs 5GHz** - The API doesn't provide frequency information
- **Doesn't work on cellular** - If iPhone is on cellular data, detection will fail

## User Guidance

Since ESP32 only supports 2.4GHz WiFi, we've added a warning in the UI:

> ⚠️ WiFi Requirements
> - Network must be 2.4GHz (ESP32 limitation)
> - Network must have internet access
> - You'll need to enter the password manually

### Dual-Band Networks

Many modern routers broadcast the same SSID on both 2.4GHz and 5GHz. If the user's iPhone is connected to the 5GHz version:

1. The app will auto-fill the SSID (e.g., "MyHomeNetwork")
2. The ESP32 will automatically connect to the 2.4GHz version of the same network
3. User doesn't need to do anything special!

### 5GHz-Only Networks

If the user is on a 5GHz-only network:

1. The app will auto-fill the SSID
2. The ESP32 will fail to connect (can't see 5GHz)
3. The OTA status will show "WiFi connection failed"
4. User needs to manually enter a 2.4GHz network name

## Troubleshooting

### "Not connected to WiFi" Error

**Cause**: iPhone is on cellular data, not WiFi

**Solution**: Connect iPhone to WiFi first, then retry

### "Unable to detect network" Error

**Cause**: Missing entitlement or iOS restriction

**Solutions**:
1. Verify the "Access WiFi Information" capability is added
2. Try on a real device (may not work in Simulator)
3. Check Console for detailed error messages

### Empty SSID Field

**Cause**: Detection failed silently

**Solution**: User can manually type the network name

## Testing

### On Device (Recommended)

WiFi detection works best on a real iOS device:

```bash
# Build and run on device
xcodebuild -scheme "42 Decibels" -destination 'platform=iOS,name=YourDevice'
```

### In Simulator (Limited)

The Simulator may not accurately reflect WiFi detection behavior. Always test on a real device before release.

### Test Cases

1. **Happy Path**: iPhone on WiFi → SSID auto-fills
2. **On Cellular**: iPhone on cellular → Shows error, allows manual entry
3. **Airplane Mode**: No connectivity → Shows error, allows manual entry
4. **VPN Active**: iPhone on VPN → Should still detect underlying WiFi

## Alternative Approaches (For Reference)

### Option A: ESP32 Does WiFi Scan

Instead of iOS scanning, the ESP32 can scan and send results via BLE:

**Pros**:
- ESP32 can distinguish 2.4GHz from 5GHz
- ESP32 sees networks it can actually connect to
- No iOS entitlements needed

**Cons**:
- More complex BLE protocol
- WiFi scan on ESP32 takes time (2-3 seconds)
- ESP32 can't scan while connected to BLE (resource conflict)

### Option B: QR Code Configuration

User scans a QR code with WiFi credentials:

**Pros**:
- Very fast and user-friendly
- Works for guest networks at hotels, etc.
- No typing needed

**Cons**:
- Requires camera permission
- User must have WiFi credentials in QR format
- Not common for home networks

### Option C: Bluetooth LE Provisioning

Use Espressif's BLE provisioning protocol:

**Pros**:
- Industry standard for ESP32
- Espressif provides iOS SDK
- Handles everything automatically

**Cons**:
- Completely different architecture
- Requires integrating Espressif SDK
- May conflict with your existing BLE protocol

## Recommendation

The current implementation (auto-fill current network) provides the best balance of:
- **Simplicity**: Minimal code and setup
- **User Experience**: Reduces typing by 80% (just password needed)
- **Reliability**: Uses official Apple APIs
- **Privacy**: Doesn't require location or other sensitive permissions

For most users, their iPhone and ESP32 device will be on the same WiFi network, so this solution works perfectly!

## See Also

- [OTA Implementation Guide](OTA_IMPLEMENTATION.md)
- [Apple Documentation: NEHotspotNetwork](https://developer.apple.com/documentation/networkextension/nehotspotnetwork)
- [Espressif ESP32 WiFi Provisioning](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/provisioning/wifi_provisioning.html)
