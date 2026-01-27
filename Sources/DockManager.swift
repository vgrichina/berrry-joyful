import Cocoa
import Foundation

/// Manages Dock reveal when cursor approaches screen edges
/// Since programmatic mouse events don't trigger native Dock reveal,
/// we manually show the Dock using Control+F3 when cursor is near the Dock edge
class DockManager {
    static let shared = DockManager()

    private var dockPosition: DockPosition = .bottom
    private var isDockAutoHidden: Bool = false
    private var lastTriggerTime: Date?
    private let triggerCooldown: TimeInterval = 0.5  // Prevent rapid toggling

    enum DockPosition {
        case bottom
        case left
        case right

        init(from string: String) {
            switch string.lowercased() {
            case "left": self = .left
            case "right": self = .right
            default: self = .bottom
            }
        }
    }

    private init() {
        updateDockSettings()

        // Watch for Dock preference changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(dockPreferencesChanged),
            name: NSNotification.Name("com.apple.dock.prefchanged"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func dockPreferencesChanged() {
        updateDockSettings()
    }

    private func updateDockSettings() {
        // Read Dock orientation
        if let orientation = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["orientation"] as? String {
            dockPosition = DockPosition(from: orientation)
        }

        // Read auto-hide setting
        if let autohide = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["autohide"] as? Bool {
            isDockAutoHidden = autohide
        }
    }

    /// Check if cursor is near the Dock edge and trigger reveal if needed
    func checkCursorForDockReveal(at position: CGPoint) {
        // Only trigger if Dock is auto-hidden
        guard isDockAutoHidden else { return }

        // Check cooldown to prevent rapid triggering
        if let lastTrigger = lastTriggerTime,
           Date().timeIntervalSince(lastTrigger) < triggerCooldown {
            return
        }

        // Get screen bounds
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(position) }) else {
            return
        }
        let screenFrame = screen.frame

        // Define trigger zones (20 pixels from edge)
        let triggerMargin: CGFloat = 20

        let shouldTrigger: Bool
        switch dockPosition {
        case .bottom:
            // In macOS, Y=0 is at TOP, so bottom is maxY
            shouldTrigger = position.y >= screenFrame.maxY - triggerMargin
        case .left:
            shouldTrigger = position.x <= screenFrame.minX + triggerMargin
        case .right:
            shouldTrigger = position.x >= screenFrame.maxX - triggerMargin
        }

        if shouldTrigger {
            print("DockManager: 🎯 Revealing Dock at edge")
            revealDock()
            lastTriggerTime = Date()
        }
    }

    /// Manually reveal the Dock by toggling auto-hide with Option+Cmd+D
    private func revealDock() {
        let source = CGEventSource(stateID: .hidSystemState)
        let dKeyCode: CGKeyCode = 0x02  // 'D' key

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: dKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: dKeyCode, keyDown: false) {

            // Set Option+Command modifiers
            var flags: CGEventFlags = []
            flags.insert(.maskAlternate)
            flags.insert(.maskCommand)
            keyDown.flags = flags
            keyUp.flags = flags

            keyDown.post(tap: CGEventTapLocation.cghidEventTap)
            usleep(10000)  // 10ms delay
            keyUp.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }

    /// Get current Dock position for debugging
    var currentDockInfo: String {
        let position = switch dockPosition {
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
        let autoHide = isDockAutoHidden ? "Auto-hide ON" : "Auto-hide OFF"
        return "Dock: \(position), \(autoHide)"
    }
}
