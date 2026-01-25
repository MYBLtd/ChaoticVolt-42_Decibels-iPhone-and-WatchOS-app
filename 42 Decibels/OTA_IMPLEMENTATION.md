# OTA Implementation - iOS Companion App

This document describes the implementation of the Over-The-Air (OTA) firmware update feature in the iOS companion app.

## Architecture

The OTA implementation consists of three main components:

### 1. OTAManager (`OTAManager.swift`)
The core manager that handles:
- BLE characteristic management for OTA
- Command encoding and sending
- Status updates from the device
- State management during the OTA process

### 2. UI Components (`OTAViews.swift`)
SwiftUI views that provide:
- **WiFiCredentialsSheet**: Form for entering WiFi credentials and firmware URL
- **OTAProgressView**: Real-time progress display with download statistics
- **ValidationDialog**: Alert for validating or rolling back new firmware
- **OTASettingsView**: Main entry point integrated into the app

### 3. BluetoothManager Integration
The `BluetoothManager` has been extended to:
- Discover OTA characteristics alongside DSP characteristics
- Route OTA status notifications to the OTA manager
- Provide access to the peripheral for OTA operations

## BLE Protocol

### Service UUID
```
00000001-1234-5678-9ABC-DEF012345678
```

### OTA Characteristics

| Characteristic | UUID | Properties | Max Size | Description |
|---|---|---|---|---|
| OTA_CREDENTIALS | 0x0005 | Write | 98 bytes | WiFi SSID + password |
| OTA_URL | 0x0006 | Write | 258 bytes | Firmware download URL |
| OTA_CONTROL | 0x0007 | Write | 2 bytes | Control commands |
| OTA_STATUS | 0x0008 | Read/Notify | 8 bytes | Progress and state |

## Data Formats

### OTA_CREDENTIALS (0x0005)
Format: `[SSID][0x00][PASSWORD]`
- SSID: UTF-8 encoded, max 32 bytes
- Separator: Single null byte (0x00)
- Password: UTF-8 encoded, max 64 bytes

### OTA_URL (0x0006)
Format: Plain UTF-8 string, max 256 bytes
Example: `https://chaoticvolt.eu/firmware/speaker_latest.bin`

### OTA_CONTROL (0x0007)
Format: `[COMMAND][PARAMETER]` (2 bytes)

Commands:
- `0x10` - START: Begin OTA download
- `0x11` - CANCEL: Cancel ongoing OTA
- `0x12` - REBOOT: Reboot to new firmware
- `0x13` - GET_VERSION: Request firmware version
- `0x14` - ROLLBACK: Rollback to previous firmware
- `0x15` - VALIDATE: Mark new firmware as valid

### OTA_STATUS (0x0008)
Format: 8 bytes

| Byte | Field | Description |
|---|---|---|
| 0 | State | Current OTA state |
| 1 | Error | Error code (0 = no error) |
| 2 | Progress | Download progress 0-100% |
| 3-4 | Downloaded KB | Little-endian uint16 |
| 5-6 | Total KB | Little-endian uint16 |
| 7 | RSSI | WiFi signal strength (signed int8) |

## OTA States

- `0x00` - IDLE: Ready for OTA
- `0x01` - CREDS_RECEIVED: WiFi credentials received
- `0x02` - URL_RECEIVED: Firmware URL received
- `0x03` - WIFI_CONNECTING: Connecting to WiFi
- `0x04` - WIFI_CONNECTED: WiFi connected
- `0x05` - DOWNLOADING: Downloading firmware
- `0x06` - VERIFYING: Verifying firmware
- `0x07` - SUCCESS: OTA complete, ready for reboot
- `0x08` - PENDING_VERIFY: New firmware running, needs validation
- `0xFF` - ERROR: Error occurred

## OTA Errors

- `0x00` - NONE: No error
- `0x01` - WIFI_CONNECT: WiFi connection failed
- `0x02` - HTTP_CONNECT: HTTP connection failed
- `0x03` - HTTP_RESPONSE: HTTP error response
- `0x04` - DOWNLOAD: Download failed
- `0x05` - VERIFY: Verification failed
- `0x06` - WRITE: Flash write failed
- `0x07` - NO_CREDENTIALS: No WiFi credentials
- `0x08` - NO_URL: No firmware URL
- `0x09` - INVALID_IMAGE: Invalid firmware image
- `0x0A` - CANCELLED: OTA cancelled by user
- `0x0B` - ROLLBACK_FAILED: Rollback failed

## OTA Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
    1. Subscribe to OTA_STATUS notifications
                              │
    2. Write WiFi credentials to OTA_CREDENTIALS
                              │◄── State: CREDS_RECEIVED (0x01)
                              │
    3. Write firmware URL to OTA_URL
                              │◄── State: URL_RECEIVED (0x02)
                              │
    4. Write START command to OTA_CONTROL
                              │◄── State: WIFI_CONNECTING (0x03)
                              │◄── State: WIFI_CONNECTED (0x04)
                              │◄── State: DOWNLOADING (0x05) + progress updates
                              │◄── State: VERIFYING (0x06)
                              │◄── State: SUCCESS (0x07)
                              │
    5. Write REBOOT command to OTA_CONTROL
                              │◄── [Device reboots, BLE disconnects]
                              │
    6. Wait and reconnect to device
                              │◄── State: PENDING_VERIFY (0x08)
                              │
    7. Write VALIDATE command to OTA_CONTROL
                              │◄── State: IDLE (0x00) - Update complete!
```

## Usage

### Starting an OTA Update

```swift
// 1. User taps "Update Firmware" button
// 2. WiFi credentials sheet is presented
// 3. User enters SSID, password, and confirms

bluetoothManager.otaManager.startOTA(
    ssid: "MyNetwork",
    password: "MyPassword123",
    firmwareURL: "https://chaoticvolt.eu/firmware/speaker_latest.bin"
)
```

### Monitoring Progress

The OTA manager publishes status updates via the `@Published var status` property:

```swift
@ObservedObject var otaManager: OTAManager

var body: some View {
    if otaManager.isUpdating {
        OTAProgressView(otaManager: otaManager, brandColor: brandPurple)
    }
}
```

### Handling States

The app automatically handles state transitions:
- **DOWNLOADING**: Shows progress bar and download statistics
- **SUCCESS**: Shows "Reboot Now" button
- **ERROR**: Shows error message with retry option (if retryable)
- **PENDING_VERIFY**: Shows validation dialog after reboot

### Validation After Reboot

After the device reboots with new firmware, the app will automatically detect the `PENDING_VERIFY` state and present a validation dialog:

```swift
.alert("Validate New Firmware", isPresented: $otaManager.showingValidationDialog) {
    Button("Keep New Firmware") {
        otaManager.validateFirmware()
    }
    Button("Rollback to Previous", role: .destructive) {
        otaManager.rollbackFirmware()
    }
}
```

## Error Handling

The OTA manager categorizes errors as retryable or non-retryable:

**Retryable Errors:**
- WiFi connection failed
- HTTP connection failed
- Download failed

For retryable errors, the app shows a "Retry" button that presents the credentials sheet again.

**Non-Retryable Errors:**
- Verification failed
- Flash write failed
- Invalid firmware image

For non-retryable errors, the user must cancel and restart the process.

## Testing

Comprehensive unit tests are provided in `OTAManagerTests.swift` covering:
- Status parsing from binary data
- Command encoding
- Error handling
- State transitions
- Characteristic UUIDs

Run tests with Xcode's Test Navigator or:
```bash
xcodebuild test -scheme "42 Decibels"
```

## Security Considerations

1. **WiFi Credentials**: Transmitted once over BLE, not stored on device
2. **Firmware URL**: Supports HTTPS for secure download
3. **Verification**: Device verifies firmware signature before installation
4. **Rollback**: Automatic rollback if validation not confirmed
5. **Safe State**: Device remains functional even if OTA fails

## Future Enhancements

- [ ] Automatic WiFi credential detection from iPhone settings
- [ ] Firmware version checking before download
- [ ] Changelog display for updates
- [ ] Background OTA updates
- [ ] Delta updates for smaller download sizes
- [ ] Multiple firmware server support
- [ ] OTA update scheduling

## Troubleshooting

### Update Fails at WiFi Connection
- Verify SSID is correct (case-sensitive)
- Check password (max 64 characters)
- Ensure WiFi network is 2.4GHz (ESP32 limitation)
- Verify network has internet access

### Download Fails
- Check firmware URL is accessible
- Verify server is online
- Ensure device WiFi signal is strong (check RSSI)
- Try HTTPS URL for better reliability

### Verification Fails
- Firmware file may be corrupted
- Device may have insufficient storage
- Try downloading again
- Contact firmware provider

### Device Won't Reboot
- Disconnect and reconnect BLE
- Power cycle the device manually
- Device may auto-rollback after timeout

## Support

For issues or questions:
- Check device logs via BLE console
- Review OTA status error codes
- Contact ChaoticVolt support at support@chaoticvolt.eu
