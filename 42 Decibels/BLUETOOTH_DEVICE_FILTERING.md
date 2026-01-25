# Bluetooth Device Filtering

## Overview
The app now filters Bluetooth scanning to show **only your known 42 Decibels devices** instead of every Bluetooth device the iOS device can see.

## Implementation Strategy

### Primary Filter: Service UUID (Recommended)
The app scans specifically for devices advertising the custom service UUID:
- Service UUID: `00000001-1234-5678-9ABC-DEF012345678`
- This is the **most reliable** method
- iOS only shows devices that advertise this specific service
- Zero false positives (no AirPods, Apple Watches, etc.)

### Secondary Filter: Device Name (Fallback)
If devices don't always advertise the service UUID, we also validate by device name:
- Device names starting with: `"42 Decibels"`, `"42DB"`, or `"ChaoticVolt"`
- Useful for development or if your devices have intermittent advertising

## Benefits

### User Experience
- ✅ **Clean device list** - Only shows relevant devices
- ✅ **No confusion** - Users won't try connecting to their AirPods
- ✅ **Faster selection** - No scrolling through dozens of devices
- ✅ **Professional appearance** - Shows you know exactly what you support

### Technical Benefits
- ✅ **Faster scanning** - iOS can filter at the radio level
- ✅ **Better battery life** - Less processing of irrelevant advertisements
- ✅ **Fewer connection errors** - Can't attempt to connect to incompatible devices
- ✅ **Clear intent** - Code explicitly documents what devices you support

## Usage

### Normal Scanning (Production)
```swift
bluetoothManager.startScanning()
```
Shows only your 42 Decibels devices.

### Debug Scanning (Development)
```swift
bluetoothManager.startScanning(showAllDevices: true)
```
Shows all Bluetooth devices. Useful for:
- Troubleshooting why your device isn't appearing
- Verifying your device is advertising properly
- Development and testing

## Requirements for Your Bluetooth Device

### For Service UUID Filtering to Work:
Your ESP32/embedded device **must** advertise the service UUID in its advertisement packet:

```cpp
// ESP32 Arduino example
BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
pAdvertising->addServiceUUID(SERVICE_UUID);
pAdvertising->start();
```

### If Your Device Doesn't Advertise the Service:
Update the `validDeviceNamePrefixes` array in `BluetoothManager.swift`:

```swift
private let validDeviceNamePrefixes = [
    "42 Decibels",
    "42DB",
    "ChaoticVolt",
    "YourDevicePrefix"  // Add your device name prefix here
]
```

Then use `showAllDevices: true` mode and rely on name filtering.

## Testing Checklist

- [ ] Your device appears in scan results
- [ ] Other devices (AirPods, watches, etc.) do NOT appear
- [ ] Connection works normally
- [ ] Service discovery works after connection
- [ ] Debug mode (`showAllDevices: true`) shows all devices

## Troubleshooting

### "My device doesn't appear in the scan"

1. **Verify your device is advertising the service UUID**
   - Use a BLE scanner app (like LightBlue or nRF Connect)
   - Check if your service UUID appears in the advertisement packet
   - If not, update your device firmware to include it

2. **Use debug mode temporarily**
   ```swift
   bluetoothManager.startScanning(showAllDevices: true)
   ```
   - Check if your device appears now
   - If yes, the issue is with service UUID advertising

3. **Check device name**
   - Does your device name match any prefix in `validDeviceNamePrefixes`?
   - If not, add it to the array

### "Too many devices are showing up"

- You're probably in debug mode (`showAllDevices: true`)
- Remove the parameter to use filtered scanning:
  ```swift
  bluetoothManager.startScanning()  // Filtered mode (default)
  ```

## Recommendations

### For Production:
- ✅ Use filtered scanning (default)
- ✅ Ensure your device advertises the service UUID
- ✅ Use clear, branded device names

### For Development:
- 🔧 Keep debug mode option available
- 🔧 Test with multiple device types
- 🔧 Verify filtering works before release

## Future Enhancements

Consider adding:
- **Signal strength filtering** - Only show devices with RSSI > -80 dBm
- **Device type icons** - Different icons for different product models
- **Remembered devices** - Show previously connected devices first
- **Search/filter UI** - Let users search by name or ID
