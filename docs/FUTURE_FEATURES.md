# Future Features & Implementation Guide

This document outlines features observed in JoyKeyMapper and other design considerations for future implementation in berrry-joyful.

---

## 1. Battery Display Design

### Current State
- Placeholder: `🔋 ---%` (ViewController.swift:1404)
- Battery info is available from JoyConSwift's `Controller` class

### ASCII/Emoji Battery Design Options

#### Option A: Simple Percentage with Icon
```
Full:      🔋 100%  ████████████
High:      🔋  75%  █████████░░░
Medium:    🔋  50%  ██████░░░░░░
Low:       🔋  25%  ███░░░░░░░░░
Critical:  🪫  10%  █░░░░░░░░░░░
Empty:     🪫   0%  ░░░░░░░░░░░░
Charging:  ⚡  50%  ██████░░░░░░
```

#### Option B: Single-Glyph Battery (Unicode)
```
Full:      🔋 (U+1F50B)
Empty:     🪫 (U+1FAAB)
Charging:  ⚡ (U+26A1)
```

#### Option C: ASCII Art Battery
```
Full:      [████████] 100%
High:      [██████░░]  75%
Medium:    [████░░░░]  50%
Low:       [██░░░░░░]  25%
Critical:  [█░░░░░░░]  10%  ⚠️
Empty:     [░░░░░░░░]   0%  ❌
Charging:  [████▶░░░]  50%  ⚡
```

#### Option D: Minimal Text-Only
```
Full:      Battery: Full
High:      Battery: 75%
Medium:    Battery: 50%
Low:       Battery: 25% ⚠️
Critical:  Battery: 10% ❗
Empty:     Battery: Empty ❌
Charging:  Battery: 50% ⚡
```

### Recommended Implementation: Option A (Simple + Visual)

**Why:**
- Clear visual indication (bar graph)
- Shows exact percentage
- Color-codable (green → yellow → red)
- Works well in header bar space

**Implementation Plan:**

```swift
// In ViewController.swift

private func updateBatteryDisplay() {
    guard let controller = controllers.first else {
        batteryLabel.stringValue = ""
        return
    }

    // Get battery from JoyConSwift
    let battery = controller.battery
    let isCharging = controller.isCharging

    let (icon, percentage, bars) = formatBatteryDisplay(battery, isCharging: isCharging)

    batteryLabel.stringValue = "\(icon) \(percentage)% \(bars)"
    batteryLabel.textColor = batteryColor(for: battery)
}

private func formatBatteryDisplay(_ battery: JoyCon.BatteryStatus, isCharging: Bool) -> (String, Int, String) {
    let icon = isCharging ? "⚡" : (battery == .empty ? "🪫" : "🔋")

    let percentage: Int
    let barCount: Int

    switch battery {
    case .full:     (percentage, barCount) = (100, 12)
    case .medium:   (percentage, barCount) = (50, 6)
    case .low:      (percentage, barCount) = (25, 3)
    case .critical: (percentage, barCount) = (10, 1)
    case .empty:    (percentage, barCount) = (0, 0)
    case .unknown:  return ("🔋", 0, "---")
    }

    let bars = String(repeating: "█", count: barCount) + String(repeating: "░", count: 12 - barCount)

    return (icon, percentage, bars)
}

private func batteryColor(for battery: JoyCon.BatteryStatus) -> NSColor {
    switch battery {
    case .full, .medium: return DesignSystem.Colors.success
    case .low: return DesignSystem.Colors.warning
    case .critical, .empty: return DesignSystem.Colors.error
    case .unknown: return DesignSystem.Colors.tertiaryText
    }
}

// Add battery change handler in setupJoyConHandlers()
controller.batteryChangeHandler = { [weak self] newState, oldState in
    self?.handleBatteryChange(newState: newState, oldState: oldState)
}

controller.isChargingChangeHandler = { [weak self] isCharging in
    self?.handleChargingChange(isCharging: isCharging)
}

private func handleBatteryChange(newState: JoyCon.BatteryStatus, oldState: JoyCon.BatteryStatus) {
    updateBatteryDisplay()

    // Log significant battery events
    if newState == .critical && oldState != .empty {
        log("⚠️ Battery Critical! Please charge your Joy-Con")
    }
    if newState == .full && oldState != .unknown {
        log("✅ Battery Full!")
    }
}

private func handleChargingChange(isCharging: Bool) {
    updateBatteryDisplay()
    log(isCharging ? "⚡ Charging started" : "⚡ Charging stopped")
}
```

**Multi-Controller Battery Display:**

When both Joy-Cons are connected:
```
🔋 L:75% ██████░░ | R:50% ████░░░░
```

---

## 2. Menu Bar Integration

### Current Architecture
- **Regular app** with window (NSApplication.ActivationPolicy.regular)
- Shows in Dock and app switcher

### Menu Bar App Architecture

#### Option A: Pure Status Bar App (Lightweight)
Like JoyKeyMapper - no dock icon, lives in menu bar only.

```swift
// In AppDelegate.swift

func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Hide from Dock - becomes status bar only app
    NSApp.setActivationPolicy(.accessory)

    // Create status bar item
    setupStatusBarItem()

    // Window is created but not shown unless user clicks status icon
    setupWindow()

    setupControllerMonitoring()
}

private var statusBarItem: NSStatusItem?

private func setupStatusBarItem() {
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    guard let button = statusBarItem?.button else { return }

    // Icon
    button.image = NSImage(systemSymbolName: "gamecontroller.fill",
                           accessibilityDescription: "Berrry Joyful")
    button.image?.isTemplate = true  // Adapts to light/dark menu bar

    // Menu
    let menu = NSMenu()

    // Controller status
    let statusItem = NSMenuItem(title: "🔍 No controller connected", action: nil, keyEquivalent: "")
    statusItem.isEnabled = false
    menu.addItem(statusItem)

    menu.addItem(NSMenuItem.separator())

    // Battery info (populated dynamically)
    let batteryItem = NSMenuItem(title: "🔋 Battery: ---", action: nil, keyEquivalent: "")
    batteryItem.isEnabled = false
    menu.addItem(batteryItem)

    menu.addItem(NSMenuItem.separator())

    // Show Settings
    menu.addItem(NSMenuItem(title: "Settings...",
                            action: #selector(showSettings),
                            keyEquivalent: ","))

    // Current Profile
    menu.addItem(NSMenuItem(title: "Profile: Desktop+Terminal",
                            action: #selector(showProfileMenu),
                            keyEquivalent: ""))

    menu.addItem(NSMenuItem.separator())

    // Quit
    menu.addItem(NSMenuItem(title: "Quit Berrry Joyful",
                            action: #selector(NSApplication.terminate(_:)),
                            keyEquivalent: "q"))

    statusBarItem?.menu = menu
}

@objc private func showSettings() {
    // Show window
    NSApp.setActivationPolicy(.regular)  // Temporarily show in Dock
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

func updateStatusBarBattery() {
    guard let menu = statusBarItem?.menu,
          let batteryItem = menu.items.first(where: { $0.title.starts(with: "🔋") }) else { return }

    if let controller = viewController?.controllers.first {
        let battery = controller.battery
        let isCharging = controller.isCharging
        let icon = isCharging ? "⚡" : "🔋"

        batteryItem.title = "\(icon) Battery: \(battery.localizedString)"
    } else {
        batteryItem.title = "🔋 Battery: ---"
    }
}
```

#### Option B: Hybrid (Default window + optional status bar)
Keep current window-based app, add status bar as optional feature.

```swift
// Add preference in Settings
var showInMenuBar: Bool = false  // User preference

// If enabled, show status bar icon + window
// If disabled, just regular window app
```

### Recommendation: **Option B (Hybrid)**

**Why:**
- Your app has rich UI (tabs, settings, debug log) that benefits from window
- JoyKeyMapper is minimalist (just key mapping), yours has more features
- Users can choose: always-visible window OR background status bar app
- Easier migration (no breaking changes)

**Trade-offs:**
| Feature | Pure Status Bar (A) | Hybrid (B) | Current (Window Only) |
|---------|---------------------|------------|------------------------|
| Always visible | ✅ Menu bar | ⚠️ Optional | ❌ Must find window |
| Rich UI | ❌ Cramped menu | ✅ Full window | ✅ Full window |
| Resource usage | ✅ Lightweight | ⚠️ Medium | ⚠️ Medium |
| User preference | ❌ No choice | ✅ Choice | ❌ No choice |

---

## 3. App-Aware Profiles (Context Switching)

### What JoyKeyMapper Does

JoyKeyMapper automatically changes key mappings based on the **frontmost application**. For example:
- Safari: A = Click, B = Back, X = New Tab
- Terminal: A = Enter, B = Escape, X = Ctrl+C
- VS Code: A = Accept, B = Close, X = Command Palette

### How It Works

```swift
// From JoyKeyMapper AppDelegate.swift (lines 441-450)
@objc func didActivateApp(notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
        let bundleID = app.bundleIdentifier else { return }

    resetMetaKeyState()

    self.controllers.forEach { controller in
        controller.switchApp(bundleID: bundleID)
    }
}

// They observe NSWorkspace.didActivateApplicationNotification
NSWorkspace.shared.notificationCenter.addObserver(
    self,
    selector: #selector(didActivateApp),
    name: NSWorkspace.didActivateApplicationNotification,
    object: nil
)
```

### Architecture for berrry-joyful

#### Data Model

```swift
// New file: Sources/AppContextProfile.swift

struct AppContext: Codable {
    let bundleIdentifier: String
    let appName: String
    var profileName: String  // Which ButtonProfile to use
    var overrides: [String: ButtonAction]?  // Optional per-button overrides
}

class AppContextManager {
    static let shared = AppContextManager()

    private var contexts: [String: AppContext] = [:]  // bundleID → context
    private var currentBundleID: String?

    var onContextSwitch: ((AppContext?) -> Void)?

    func registerContext(bundleID: String, appName: String, profileName: String) {
        contexts[bundleID] = AppContext(
            bundleIdentifier: bundleID,
            appName: appName,
            profileName: profileName
        )
        saveToUserDefaults()
    }

    func switchToApp(bundleID: String) {
        guard bundleID != currentBundleID else { return }
        currentBundleID = bundleID

        let context = contexts[bundleID]
        onContextSwitch?(context)
    }

    func getContextForCurrentApp() -> AppContext? {
        guard let bundleID = currentBundleID else { return nil }
        return contexts[bundleID]
    }
}
```

#### Integration with Existing Profile System

```swift
// In AppDelegate.swift

func setupAppContextMonitoring() {
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(didActivateApp),
        name: NSWorkspace.didActivateApplicationNotification,
        object: nil
    )
}

@objc private func didActivateApp(notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
          let bundleID = app.bundleIdentifier else { return }

    let appName = app.localizedName ?? bundleID

    viewController.log("🔄 App switched: \(appName)")

    // Check if we have a context for this app
    AppContextManager.shared.switchToApp(bundleID: bundleID)
}

// In ViewController.swift

override func viewDidLoad() {
    super.viewDidLoad()

    // ...existing setup...

    setupAppContextManager()
}

private func setupAppContextManager() {
    AppContextManager.shared.onContextSwitch = { [weak self] context in
        guard let self = self else { return }

        if let context = context {
            // Auto-switch to app-specific profile
            self.profileManager.setActiveProfile(named: context.profileName)
            self.log("🎯 Auto-switched to profile: \(context.profileName)")

            // Optionally show overlay
            ProfileOverlay.show(profile: self.profileManager.activeProfile,
                               reason: "Auto-switched for \(context.appName)")
        } else {
            // Unknown app - use default profile
            self.profileManager.setActiveProfile(named: "Desktop+Terminal")
            self.log("🎯 Using default profile (unknown app)")
        }
    }
}
```

#### UI for Managing App Contexts

Add a new tab or section in Settings:

```
┌─────────────────────────────────────────┐
│  App-Specific Profiles                  │
├─────────────────────────────────────────┤
│  ☑️ Enable automatic profile switching  │
│                                          │
│  Applications:                           │
│  ┌───────────────────────────────────┐  │
│  │ 🌐 Safari          → Media        │  │
│  │ 💻 Terminal        → Desktop      │  │
│  │ 🎮 Steam           → Gaming       │  │
│  │ 📝 VS Code         → Desktop      │  │
│  │ + Add Application...              │  │
│  └───────────────────────────────────┘  │
│                                          │
│  [Learn Current App]  [Remove]          │
└─────────────────────────────────────────┘
```

### Use Cases

1. **Terminal/iTerm2** (`com.apple.Terminal`, `com.googlecode.iterm2`)
   - Use "Desktop+Terminal" profile
   - D-Pad = arrow keys for navigation
   - A = Enter, B = Escape

2. **Web Browsers** (`com.apple.Safari`, `org.mozilla.firefox`)
   - Use "Media" profile
   - A = Click, B = Back
   - Scroll stick for page navigation

3. **Games** (`com.valvesoftware.steam`, games in /Applications)
   - Use "Gaming" profile
   - Full WASD + mouse control

4. **Code Editors** (`com.microsoft.VSCode`, `com.sublimetext.4`)
   - Use "Desktop+Terminal" profile
   - Enhanced shortcuts for coding

### Implementation Priority: 🟡 Medium

**Pros:**
- Very powerful for users who switch contexts frequently
- Reduces need to manually switch profiles
- Matches JoyKeyMapper's killer feature

**Cons:**
- Requires UI work to configure app → profile mappings
- Need to detect all common apps (bundle IDs)
- May surprise users if they don't expect auto-switching

**Alternative: Simpler "Quick Switch" Feature**
Instead of full auto-switching, add a chord to cycle profiles:
- Hold **Home** + D-Pad → instant profile switch (already implemented!)
- Shows overlay with profile name (already done!)

This gives 80% of the benefit without complexity.

---

## 4. Reconnection Deep Dive

### The Problem

JoyConSwift uses **IOHIDManager** to detect controllers. When Joy-Cons disconnect/reconnect:
- Sleep/wake cycles
- Bluetooth range loss
- Manual disconnect/reconnect

There are two approaches:

#### ❌ Bad Approach: Restart JoyConManager

```swift
// DON'T DO THIS
private func attemptReconnection() {
    joyConManager = nil  // Release old manager
    joyConManager = JoyConManager()  // Create new manager
    joyConManager.connectHandler = { ... }
    joyConManager.runAsync()  // Start new async loop
}
```

**Why this is bad:**
1. **Multiple IOHIDManager instances**: Each `runAsync()` creates a new run loop listening to USB/HID events
2. **Crashes**: IOHIDManager doesn't gracefully handle multiple concurrent instances
3. **Memory leaks**: Old handlers may not be released properly
4. **Race conditions**: Old and new managers may both fire events

**Error you'd see:**
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException'
reason: 'IOHIDManager: Multiple concurrent instances detected'
```

#### ✅ Good Approach: Trust JoyConSwift's Auto-Reconnection

```swift
// From your AppDelegate.swift:416-426
private func attemptReconnection() {
    viewController.log("🔄 Attempting to detect reconnected controllers...")

    // Don't restart the manager - JoyConSwift should automatically detect reconnections
    // Restarting creates multiple concurrent run loops which causes IOHIDManager crashes

    // Just log the status check
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.checkJoyConStatus()
    }
}
```

**Why this works:**

1. **Single IOHIDManager instance**: Only one manager is created at app startup
2. **Persistent device monitoring**: IOHIDManager continues watching for devices even after disconnect
3. **Automatic reconnection**: When Joy-Con reappears, `connectHandler` fires automatically
4. **No race conditions**: Single source of truth

### How JoyConSwift Detects Reconnection

From JoyConSwift source (simplified):

```swift
// JoyConManager.swift
public func runAsync() {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    // Set device matching criteria (Nintendo vendor ID)
    let deviceMatch = [
        kIOHIDProductIDKey: kProductIDJoyConL,  // or JoyConR, ProController
        kIOHIDVendorIDKey: kVendorIDNintendo
    ]

    IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)

    // Register callbacks for device add/remove
    IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceAddedCallback,
                                                Unmanaged.passUnretained(self).toOpaque())
    IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback,
                                               Unmanaged.passUnretained(self).toOpaque())

    // Schedule on run loop - this keeps running forever
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

    // Run loop - blocks until manager is stopped
    CFRunLoopRun()
}
```

**Key insight:** The run loop (`CFRunLoopRun()`) never stops. It continuously monitors for:
- **Device added** → triggers `deviceAddedCallback` → your `connectHandler`
- **Device removed** → triggers `deviceRemovedCallback` → your `disconnectHandler`

### When Reconnection Happens Automatically

1. **Joy-Con wakes from sleep**
   - Joy-Con enters sleep after ~30 seconds of inactivity
   - Pressing any button wakes it
   - IOHIDManager detects device and fires `connectHandler`

2. **Bluetooth reconnection**
   - Joy-Con goes out of range, then comes back
   - Bluetooth re-establishes connection
   - IOHIDManager sees device again → `connectHandler`

3. **Manual disconnect/reconnect**
   - User disconnects in Bluetooth settings, then reconnects
   - IOHIDManager detects new connection → `connectHandler`

### What Your Code Does

```swift
// AppDelegate.swift:342-355
joyConManager.disconnectHandler = { [weak self] controller in
    guard let self = self else { return }

    let controllerType = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
    self.viewController.log("❌ Joy-Con Disconnected: \(controllerType)")

    self.viewController.joyConDisconnected(controller)

    // Schedule reconnection attempt after a short delay
    // This helps detect when Joy-Cons wake from sleep
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
        self?.attemptReconnection()  // Just logs status, doesn't restart manager
    }
}
```

**Why the 3-second delay?**
- Gives Bluetooth time to re-establish if it's a temporary disconnection
- Logs status for user feedback
- **Doesn't restart manager** - just checks if reconnection happened

### Debugging Reconnection Issues

If users report "Joy-Con doesn't reconnect after sleep":

1. **Check Bluetooth pairing**
   ```swift
   // Already in your code: AppDelegate.swift:368-396
   private func logBluetoothJoyConStatus() {
       let task = Process()
       task.launchPath = "/usr/sbin/system_profiler"
       task.arguments = ["SPBluetoothDataType", "-detailLevel", "basic"]
       // ... parse output for Joy-Con devices
   }
   ```

2. **Verify IOHIDManager is still running**
   ```swift
   // Add debug logging to connectHandler
   joyConManager.connectHandler = { [weak self] controller in
       print("DEBUG: IOHIDManager fired connectHandler")  // Should always fire
       // ... rest of handler
   }
   ```

3. **Button press to wake**
   - Joy-Cons in sleep mode won't reconnect until button press
   - Document this: "Press any button on Joy-Con to wake after sleep"

### Edge Case: Multiple Joy-Cons

```swift
// Your code handles this: AppDelegate.swift:398-414
private func checkJoyConStatus() {
    let controllers = viewController.controllers
    viewController.log("📊 Status Check: \(controllers.count) controller(s) connected")

    if controllers.count == 1 {
        viewController.log("⚠️ Only 1 Joy-Con detected. If both are paired via Bluetooth:")
        viewController.log("   1. Try pressing buttons on the missing Joy-Con")
        // ... helpful debug messages
    }
}
```

**Why this matters:**
- Both Joy-Cons use the same vendor/product ID
- IOHIDManager sees them as separate devices
- Each triggers its own `connectHandler`
- Your array (`controllers`) tracks both

### Summary: Why Your Approach is Correct

✅ **Single JoyConManager instance** (created once in `setupControllerMonitoring()`)
✅ **Never restart manager** (avoids IOHIDManager crashes)
✅ **Trust automatic detection** (IOHIDManager run loop handles reconnection)
✅ **Helpful logging** (guides users through reconnection)
✅ **No race conditions** (single source of truth)

**Your implementation is production-ready.** The comment on line 420 shows you understand the pitfall and explicitly avoided it:

```swift
// Don't restart the manager - JoyConSwift should automatically detect reconnections
// Restarting creates multiple concurrent run loops which causes IOHIDManager crashes
```

This is **better documented** than JoyKeyMapper, which doesn't explicitly comment on this behavior.

---

## Status: Battery Display & Menu Bar Next Steps

### Quick Wins
1. **Battery display** (2-3 hours work):
   - Add `batteryChangeHandler` and `isChargingChangeHandler`
   - Implement `formatBatteryDisplay()` with Option A design
   - Update `updateConnectionDisplay()` to show battery

2. **Menu bar item** (1-2 hours work):
   - Add status bar icon (optional, controlled by preference)
   - Keep existing window-based UI
   - Hybrid approach for best of both worlds

### Future Consideration
3. **App-aware profiles** (8-10 hours work):
   - New `AppContextManager` class
   - UI for configuring app → profile mappings
   - NSWorkspace observation
   - **OR** skip this and just use existing Minus+DPad quick switch

### No Action Needed
4. **Reconnection** ✅ Already correct - just document the behavior for users

---

**Diagnostic Note:** The "No such module 'JoyConSwift'" error means you need to run:
```bash
pod install
```
Then build using `berrry-joyful.xcworkspace` (not `.xcodeproj`).
