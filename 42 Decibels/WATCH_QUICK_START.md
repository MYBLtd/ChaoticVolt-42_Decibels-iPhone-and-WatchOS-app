# watchOS Quick Start Checklist

Follow this checklist to add Apple Watch support to your 42 Decibels app.

## ✅ Step-by-Step Setup

### 1. Create Watch Target
- [ ] In Xcode: File > New > Target...
- [ ] Select watchOS > Watch App
- [ ] Name: "42 Decibels Watch App"
- [ ] Click Finish and Activate

### 2. Add Shared Files to Watch Target
- [ ] Select `BluetoothManager.swift` in Project Navigator
- [ ] In File Inspector (right sidebar), check "42 Decibels Watch App" under Target Membership
- [ ] Repeat for any other shared files you want (optional: `OTAManager.swift`)

### 3. Add Watch-Specific Files
- [ ] Add `42_Decibels_Watch_App.swift` to Watch target
- [ ] Add `WatchContentView.swift` to Watch target

**Note:** Make sure these files are ONLY in the Watch target, not the iOS target!

### 4. Configure Permissions
- [ ] Select Watch App target in project settings
- [ ] Go to Info tab
- [ ] Add key: "Privacy - Bluetooth Always Usage Description"
- [ ] Value: "42 Decibels needs Bluetooth to connect to and control your speaker"

### 5. Add App Icons
- [ ] Open Watch App's Assets.xcassets
- [ ] Add app icons for all required sizes (see WATCH_APP_SETUP.md for sizes)
- [ ] Or use Asset Catalog to generate from a 1024x1024 icon

### 6. Test in Simulator
- [ ] Select "42 Decibels Watch App" scheme
- [ ] Choose a Watch simulator (e.g., Apple Watch Series 10)
- [ ] Press ⌘R to run
- [ ] Verify UI loads correctly

**Note:** Bluetooth won't work in simulator, but UI should render!

### 7. Test on Real Device
- [ ] Pair an Apple Watch with your iPhone
- [ ] Install iOS app on iPhone first (optional but recommended)
- [ ] Select Watch scheme with your paired Watch as destination
- [ ] Press ⌘R to run
- [ ] Test connecting to your speaker
- [ ] Verify all controls work

### 8. Verify All Features
- [ ] Scan for devices ✓
- [ ] Connect to speaker ✓
- [ ] Switch DSP presets ✓
- [ ] Toggle Mute ✓
- [ ] Toggle Audio Duck ✓
- [ ] Toggle Loudness ✓
- [ ] Toggle Normalizer ✓
- [ ] View live status ✓
- [ ] Disconnect ✓

## 🐛 Troubleshooting

### Build Errors

#### "Cannot find 'BluetoothManager' in scope"
**Fix:** Add `BluetoothManager.swift` to Watch target membership

#### "Module 'UIKit' not found"
**Fix:** Remove any iOS-specific imports from shared files, or wrap in `#if os(iOS)`

#### Asset not found
**Fix:** Make sure all assets referenced exist in Watch App's Assets.xcassets

### Runtime Issues

#### App crashes on launch
**Fix:** Check Console in Xcode for specific error. Common causes:
- Missing Bluetooth permission in Info.plist
- Asset references that don't exist in Watch target

#### Can't connect to speaker
**Fix:** 
- Verify Bluetooth permission is granted (Settings > Privacy > Bluetooth)
- Make sure speaker is in range of Watch (not just iPhone)
- Try disconnecting from iPhone app first

#### "Live" indicator never shows green
**Fix:**
- Verify `galacticStatusUUID` characteristic exists and is notifying
- Check Console for "Galactic Status" log messages
- Ensure speaker is sending status updates

## 📱 Distribution

### For Testing (TestFlight)
- [ ] Archive both iOS and Watch apps (they're bundled together)
- [ ] Upload to App Store Connect
- [ ] Add external testers
- [ ] Testers need both iPhone and Apple Watch to test Watch app

### For Release
- [ ] Same as TestFlight - both apps are bundled in one submission
- [ ] Watch app appears in App Store as part of iOS app
- [ ] Users install Watch app from iPhone's Watch app

## 🎨 Customization Ideas

Once you have the basics working, consider:

### Visual Enhancements
- [ ] Add haptic feedback for button presses (already in StatusPillCompact)
- [ ] Customize colors to match brand
- [ ] Add animations for state changes

### Features
- [ ] Add Watch face complications
- [ ] Create Siri shortcuts
- [ ] Add Digital Crown volume control
- [ ] Create Live Activities (watchOS 10+)

### Optimization
- [ ] Test battery impact
- [ ] Optimize polling frequency
- [ ] Add connection timeout handling
- [ ] Implement auto-reconnect logic

## 📚 Reference Files

- **WATCH_APP_SETUP.md** - Detailed setup instructions
- **PLATFORM_COMPARISON.md** - iOS vs watchOS feature comparison
- **BluetoothManager.swift** - Shared Bluetooth logic
- **WatchContentView.swift** - Watch UI implementation

## 🎯 Success Criteria

You know it's working when:
- ✅ Watch app launches without crashes
- ✅ Scan finds your speaker
- ✅ Connection is established from Watch (independently of iPhone)
- ✅ Preset changes are reflected in speaker behavior
- ✅ "Live" indicator turns green when connected
- ✅ All controls respond to taps
- ✅ Status updates appear in real-time

## 🚀 Next Steps After Setup

1. **Test thoroughly** with real speaker and Watch
2. **Optimize UI** based on your Watch size preferences
3. **Add to App Store** by archiving and uploading
4. **Consider complications** for quick access from watch face
5. **Gather feedback** from beta testers

---

**Questions?** Check the documentation files or review the Watch Console logs in Xcode!

**Tip:** The Digital Crown naturally scrolls the ScrollView in the Watch app, making it easy to access all controls!

**Solutions to try (in order):**



**1. Clean Build Folder**

Press **Shift + Command + K** (or Product → Clean Build Folder)



**2. Clear Derived Data**

1. Close Xcode
2. Open Finder
3. Press **Shift + Command + G**
4. Paste this path: ~/Library/Developer/Xcode/DerivedData
5. Find the folder for your project (should be named something like _2_Decibels_Watch_App-...)
6. Delete that folder
7. Reopen Xcode and rebuild



**3. Verify the file header comment matches the target**



I notice your file header says // 42 Decibels Watch App but the actual target name appears to be 42 Decibels Watch App Watch App (with "Watch App" twice). Let me fix the struct name to ensure there's no naming conflict:

☐ Restarted Mac, iPhone, and Apple Watch

☐ Watch has >500MB free storage

☐ iPhone connected via USB (not just Wi-Fi)

☐ Watch wireless debugging is OFF

☐ Cleaned build folder (⇧⌘K)

☐ Deleted Derived Data

☐ No VPN active on Mac or iPhone

☐ Same Wi-Fi network for Mac and iPhone

☐ Xcode version is up to date

☐ watchOS is up to date
