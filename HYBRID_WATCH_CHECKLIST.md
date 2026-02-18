# ✅ Hybrid Watch Mode - Implementation Checklist

**Use this checklist to verify each step as you implement.**

---

## 📋 Pre-Implementation (CRITICAL)

- [ ] **Read all documentation first**
  - [ ] `HYBRID_WATCH_SUMMARY.md` - Overview
  - [ ] `HYBRID_WATCH_MIGRATION.md` - Safety guide
  - [ ] `HYBRID_WATCH_SETUP.md` - Detailed setup

- [ ] **Backup your work**
  ```bash
  git status  # Check for uncommitted changes
  git add .
  git commit -m "Working state before hybrid watch"
  git tag before-hybrid-watch-v2
  git checkout -b hybrid-watch-implementation
  ```

- [ ] **Verify current state works**
  - [ ] iOS app builds
  - [ ] iOS app runs
  - [ ] iOS app connects to speaker
  - [ ] Watch app builds
  - [ ] Watch app runs (in current direct-only mode)

---

## 🆕 New Files

### Step 1: Create WatchConnectivityManager.swift

- [ ] Copy `WatchConnectivityManager.swift` content into new file
- [ ] File location: Project root (same level as BluetoothManager.swift)
- [ ] **CRITICAL:** Set target membership:
  - [ ] ✅ iOS target checked
  - [ ] ✅ Watch target checked
  - [ ] Verify in File Inspector (⌥⌘1)

**Verification:**
```swift
// Should compile in both targets
#if os(watchOS)
print("Watch target")
#else
print("iOS target")
#endif
```

---

## 🔧 Modify Existing Files

### Step 2: Update BluetoothManager.swift (iOS side)

- [ ] **Add property** (after `otaManager`):
  ```swift
  #if !os(watchOS)
  var watchConnectivityManager: WatchConnectivityManager?
  #endif
  ```

- [ ] **Add setupWatchConnectivity() function** (iOS only):
  - [ ] Creates WatchConnectivityManager
  - [ ] Adds observer for `.executeCommandFromWatch`
  - [ ] Adds observer for `.requestConnectionStateForWatch`
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Add handleCommandFromWatch() function** (iOS only):
  - [ ] `@objc` attribute
  - [ ] Extracts command type and data
  - [ ] Calls `sendCommand(commandData)`
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Add handleConnectionStateRequest() function** (iOS only):
  - [ ] `@objc` attribute
  - [ ] Creates ConnectionInfo
  - [ ] Calls replyHandler with encoded data
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Add updateWatchConnectionState() function** (iOS only):
  - [ ] Calls watchConnectivityManager?.updateConnectionState()
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Update init():**
  - [ ] Add call to `setupWatchConnectivity()` (iOS only)
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Update didConnect peripheral:**
  - [ ] Add call to `updateWatchConnectionState()` after OTA setup
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Update disconnect():**
  - [ ] Add call to `updateWatchConnectionState()` at end
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

- [ ] **Update parseGalacticStatus():**
  - [ ] Add call to `updateGalacticStatus()` after updating properties
  - [ ] Wrapped in `#if !os(watchOS)` ... `#endif`

**Verification:**
- [ ] File still compiles for iOS target
- [ ] File still compiles for Watch target
- [ ] No changes to watch-side BLE functionality

### Step 3: Update WatchContentView.swift (Complete rewrite)

- [ ] **Add WatchConnectivity import:**
  ```swift
  import WatchConnectivity
  ```

- [ ] **Add new @StateObject:**
  ```swift
  @StateObject private var watchConnectivity = WatchConnectivityManager()
  ```

- [ ] **Add new @State variable:**
  ```swift
  @State private var connectionMode: ConnectionMode = .determining
  ```

- [ ] **Add ConnectionMode enum:**
  ```swift
  enum ConnectionMode {
      case determining
      case viaPhone
      case direct
  }
  ```

- [ ] **Add new view functions:**
  - [ ] `connectionModeIndicator` - Shows badge
  - [ ] `connectedViaPhoneView()` - Proxy mode UI
  - [ ] `connectedDirectView()` - Direct mode UI (existing enhanced)
  - [ ] `quickControlsView()` - Shared controls with routing
  - [ ] `setupHybridMode()` - Initial phone check
  - [ ] `updateConnectionMode()` - Smart mode selection
  - [ ] `sendCommandViaPhone()` - Command routing

- [ ] **Add .onAppear handler:**
  - [ ] Calls `setupHybridMode()`

- [ ] **Add .onChange handlers:**
  - [ ] For `watchConnectivity.counterpartConnectionState`
  - [ ] For `watchConnectivity.isPhoneReachable`

- [ ] **Update body to show connectionModeIndicator**

- [ ] **Update body to route to correct view based on mode**

- [ ] **Update button handlers to check viaPhone flag**

- [ ] **Keep existing views:**
  - [ ] WatchPresetButton
  - [ ] WatchControlButton
  - [ ] WatchScannerView

**Verification:**
- [ ] File compiles for Watch target
- [ ] No syntax errors
- [ ] All view functions return proper View types

---

## 📦 Add Frameworks

### Step 4: Add WatchConnectivity to iOS Target

- [ ] Select project in Navigator
- [ ] Select iOS app target
- [ ] Go to "General" tab
- [ ] Scroll to "Frameworks, Libraries, and Embedded Content"
- [ ] Click "+" button
- [ ] Search for "WatchConnectivity"
- [ ] Select "WatchConnectivity.framework"
- [ ] Click "Add"
- [ ] Verify it appears in list

### Step 5: Add WatchConnectivity to Watch Target

- [ ] Select project in Navigator
- [ ] Select Watch app target
- [ ] Go to "General" tab
- [ ] Scroll to "Frameworks, Libraries, and Embedded Content"
- [ ] Click "+" button
- [ ] Search for "WatchConnectivity"
- [ ] Select "WatchConnectivity.framework"
- [ ] Click "Add"
- [ ] Verify it appears in list

---

## 🔨 Build Verification

### Step 6: Build iOS App

- [ ] Select iOS scheme (not Watch)
- [ ] Clean build folder (⇧⌘K)
- [ ] Build (⌘B)
- [ ] **Result:** Build succeeds with 0 errors

**If build fails:**
- [ ] Check error message
- [ ] Verify WatchConnectivity framework is added
- [ ] Verify WatchConnectivityManager.swift is in iOS target
- [ ] Verify all `#if !os(watchOS)` guards are correct
- [ ] Check for typos in new code

**Common errors:**
- "Cannot find WatchConnectivityManager" → Check target membership
- "Cannot find WatchConnectivity" → Add framework
- "Use of undeclared type" → Check imports

### Step 7: Run iOS App on Simulator

- [ ] Select iOS scheme
- [ ] Select iPhone simulator
- [ ] Run (⌘R)
- [ ] **Result:** App launches without crashing

**Test iOS independently:**
- [ ] App shows familiar UI
- [ ] Can tap "Scan" (even if no devices found)
- [ ] No console errors related to WatchConnectivity
- [ ] OTA section still visible

### Step 8: Build Watch App

- [ ] Select Watch scheme (not iOS)
- [ ] Clean build folder (⇧⌘K)
- [ ] Build (⌘B)
- [ ] **Result:** Build succeeds with 0 errors

**If build fails:**
- [ ] Check error message
- [ ] Verify WatchConnectivity framework is added
- [ ] Verify WatchConnectivityManager.swift is in Watch target
- [ ] Check WatchContentView.swift syntax

### Step 9: Run Watch App on Simulator

- [ ] Select Watch scheme
- [ ] Select Apple Watch simulator
- [ ] Run (⌘R)
- [ ] **Result:** App launches without crashing

**Test Watch in simulator:**
- [ ] App shows UI (even if "Determining" forever)
- [ ] After ~2 seconds, should show disconnected state
- [ ] Can tap "Scan" button
- [ ] No crashes

**Note:** WatchConnectivity won't work in simulator, but app should still launch.

---

## 📱 Device Testing

### Step 10: Test iOS on Device (Independent)

- [ ] Build and run iOS app on physical iPhone
- [ ] Scan for speaker
- [ ] Connect to speaker
- [ ] Verify all controls work:
  - [ ] Presets change
  - [ ] Mute toggles
  - [ ] Duck toggles
  - [ ] Loudness toggles
  - [ ] Normalizer toggles
  - [ ] Bypass toggles
  - [ ] Bass boost toggles
- [ ] Verify status updates show "Live"
- [ ] Verify OTA section works

**If anything fails:** iOS basic functionality is broken. Fix before proceeding.

### Step 11: Test Watch Direct Mode

**Setup:**
- [ ] Disconnect iPhone from speaker (or turn off iPhone)
- [ ] Build and run Watch app on physical Apple Watch

**Test:**
- [ ] Watch shows "direct" badge (may need to wait ~2 seconds)
- [ ] Tap "Scan" button
- [ ] Speaker appears in list
- [ ] Tap speaker to connect
- [ ] Connection succeeds
- [ ] "Live" indicator appears
- [ ] Change preset → works
- [ ] Toggle Mute → works
- [ ] Toggle Duck → works
- [ ] Toggle Loudness → works
- [ ] Toggle Normalizer → works
- [ ] Volume displays correctly

**If anything fails:** Direct mode is broken. Check Console logs.

### Step 12: Test Proxy Mode

**Setup:**
- [ ] Disconnect Watch from speaker (if connected)
- [ ] Connect iPhone to speaker
- [ ] iPhone app shows "Live" status
- [ ] Open Watch app (or keep open)

**Test:**
- [ ] Watch detects iPhone connection (may take 2-5 seconds)
- [ ] Watch shows "via iPhone" badge (blue)
- [ ] Watch shows speaker name from iPhone
- [ ] Watch shows "Live" indicator
- [ ] Change preset from Watch → works
  - [ ] Check iPhone Console for "Received command from watch"
  - [ ] Speaker responds (verify by audio change)
  - [ ] Both devices show new preset
- [ ] Toggle Mute from Watch → works
  - [ ] iPhone Console shows command received
  - [ ] Speaker mutes
  - [ ] Both devices show muted state
- [ ] Test all other controls similarly

**If commands don't work:**
- [ ] Check Watch Console for "iPhone not reachable"
- [ ] Check iPhone Console for "Received command" messages
- [ ] Verify both devices are unlocked
- [ ] Try force-quitting and relaunching both apps

### Step 13: Test Mode Switching (Direct → Proxy)

**Setup:**
- [ ] Watch connected directly to speaker
- [ ] Shows "direct" badge and "Live" status
- [ ] iPhone app closed or not connected

**Test:**
- [ ] Open iPhone app
- [ ] Connect iPhone to speaker
- [ ] Watch after ~2-5 seconds:
  - [ ] Badge changes from "direct" to "via iPhone"
  - [ ] Speaker name updates
  - [ ] No crash
  - [ ] Controls continue to work
- [ ] Test a command from Watch → should work via iPhone now
- [ ] Check iPhone Console for command receipt

**If switch doesn't happen:**
- [ ] Check Watch Console for reachability messages
- [ ] Verify WCSession is active on both devices
- [ ] Try force-quitting Watch app and reopening

### Step 14: Test Mode Switching (Proxy → Direct)

**Setup:**
- [ ] Watch in proxy mode (via iPhone)
- [ ] Both devices showing speaker connection

**Test:**
- [ ] Put iPhone in airplane mode (or walk >10m away)
- [ ] Watch after ~2-5 seconds:
  - [ ] Badge changes to "direct" or disappears
  - [ ] Shows disconnected state
  - [ ] Can tap "Scan"
- [ ] Tap "Scan" on Watch
- [ ] Connect to speaker directly
- [ ] Badge shows "direct"
- [ ] Controls work
- [ ] Bring iPhone back
- [ ] iPhone reconnects
- [ ] Watch should switch back to "via iPhone" after ~2-5 seconds

---

## 🧪 Edge Case Testing

### Step 15: Test Edge Cases

- [ ] **Rapid mode switching:**
  - Connect/disconnect iPhone multiple times
  - Verify no crashes
  - Watch should adapt each time

- [ ] **Background/foreground transitions:**
  - With Watch in proxy mode, minimize iPhone app
  - Commands should still work (briefly)
  - Bring iPhone to foreground
  - Should resume normal operation

- [ ] **Speaker turned off mid-session:**
  - Watch connected (any mode)
  - Turn off speaker
  - Both apps should show connection loss
  - No crashes

- [ ] **Simultaneous connections:**
  - Watch and iPhone both connected
  - Change preset from iPhone → Watch should update
  - Change preset from Watch → iPhone should update

- [ ] **Out of range scenarios:**
  - Start in proxy mode
  - Walk away with just Watch
  - Watch should detect iPhone unreachable
  - Allow manual scan and direct connection

---

## ✅ Final Verification

### Step 16: Complete Success Checklist

- [ ] iOS app builds without errors
- [ ] iOS app runs without crashes
- [ ] iOS app connects to speaker normally
- [ ] iOS app all existing features work
- [ ] Watch app builds without errors
- [ ] Watch app runs without crashes
- [ ] Watch shows "via iPhone" when iPhone connected
- [ ] Watch shows "direct" when connecting directly
- [ ] Watch commands work in proxy mode
- [ ] Watch commands work in direct mode
- [ ] Watch automatically switches between modes
- [ ] No crashes during mode transitions
- [ ] Status updates work on both devices
- [ ] All edge cases handled gracefully

---

## 📸 Capture Evidence

### Step 17: Document Success

Take screenshots/videos of:
- [ ] iOS app connected to speaker
- [ ] Watch app in "via iPhone" mode
- [ ] Watch app in "direct" mode
- [ ] Mode switching in action
- [ ] Command execution from Watch
- [ ] Status updates on both devices

---

## 🎉 Completion

### Step 18: Commit and Tag

If all tests pass:

```bash
git add .
git commit -m "Implement hybrid watch mode - SUCCESS

- Added WatchConnectivityManager for iOS-Watch communication
- Updated BluetoothManager with Watch sync (iOS only)
- Rewrote WatchContentView for hybrid mode
- Watch intelligently uses iPhone as proxy when available
- Falls back to direct BLE when needed
- Automatic mode switching
- All tests passing"

git tag hybrid-watch-v1.0

# Merge back to main
git checkout main
git merge hybrid-watch-implementation
```

---

## 🚨 If Something Goes Wrong

### Rollback Procedure

```bash
# Quick rollback (before commit)
git checkout .

# Full rollback (after commit)
git checkout before-hybrid-watch-v2

# Start over
git checkout main
git branch -D hybrid-watch-implementation
git checkout -b hybrid-watch-implementation-v2
# Start from Step 1 again
```

### Get Help

If stuck:
1. Note exactly which step failed
2. Copy the error message
3. Check Console logs on both devices
4. Review relevant documentation section
5. Don't proceed until issue is resolved

---

## 📊 Progress Tracking

```
┌─────────────────────────────────────────────┐
│ Implementation Progress                     │
├─────────────────────────────────────────────┤
│ □ Pre-Implementation (Steps 1)             │
│ □ New Files (Step 1)                        │
│ □ Modify Files (Steps 2-3)                  │
│ □ Add Frameworks (Steps 4-5)                │
│ □ Build Verification (Steps 6-9)            │
│ □ Device Testing (Steps 10-14)              │
│ □ Edge Cases (Step 15)                      │
│ □ Final Verification (Step 16)              │
│ □ Documentation (Step 17)                   │
│ □ Completion (Step 18)                      │
└─────────────────────────────────────────────┘

Time estimate: 2-3 hours for careful implementation
```

---

**Good luck! Take your time, follow each step carefully, and test thoroughly. 🚀**
