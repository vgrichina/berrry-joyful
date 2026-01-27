import Cocoa
import CoreGraphics
import Carbon.HIToolbox

/// Handles mouse movement, clicking, and keyboard input simulation
class InputController {
    static let shared = InputController()

    private var mouseTimer: Timer?
    private var currentMouseDelta: CGPoint = .zero
    private var currentScrollDelta: CGPoint = .zero
    private var isPrecisionMode: Bool = false
    private var isDragging: Bool = false

    private let settings = InputSettings.shared

    // Create an HID event source to make events appear as hardware input
    // This is necessary for system UI elements (Dock, hot corners) to respond
    private let eventSource: CGEventSource? = {
        return CGEventSource(stateID: .hidSystemState)
    }()

    // Callback for logging
    var onLog: ((String) -> Void)?

    // Debug mode - skips actual input events (for testing without permissions)
    // Always defaults to false - user must explicitly enable via checkbox
    var debugMode: Bool = false

    private init() {}

    // MARK: - Accessibility Check

    static func checkAccessibilityPermission() -> Bool {
        // Check without showing prompt
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        // Request with prompt to open System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Mouse Movement

    func startMouseUpdates() {
        guard mouseTimer == nil else { return }
        mouseTimer = Timer.scheduledTimer(withTimeInterval: settings.mouseUpdateRate, repeats: true) { [weak self] _ in
            self?.updateMouse()
        }
        RunLoop.current.add(mouseTimer!, forMode: .common)
    }

    func stopMouseUpdates() {
        mouseTimer?.invalidate()
        mouseTimer = nil
    }

    enum Stick {
        case left
        case right
    }

    func setMouseDelta(x: Float, y: Float, stick: Stick = .right) {
        // Apply appropriate deadzone for the stick
        let deadzone = (stick == .left) ? settings.leftStickDeadzone : settings.rightStickDeadzone
        let adjustedX = abs(x) > deadzone ? x : 0
        let adjustedY = abs(y) > deadzone ? y : 0

        // Apply acceleration curve
        let magnitude = sqrt(Double(adjustedX * adjustedX + adjustedY * adjustedY))
        let accelerated = pow(magnitude, settings.accelerationCurve)
        let scale = magnitude > 0 ? accelerated / magnitude : 0

        // Apply sensitivity and precision mode
        var sensitivity = settings.mouseSensitivity
        if isPrecisionMode {
            sensitivity *= settings.precisionMultiplier
        }

        currentMouseDelta = CGPoint(
            x: CGFloat(adjustedX) * CGFloat(scale) * sensitivity,
            y: CGFloat(-adjustedY) * CGFloat(scale) * sensitivity  // Invert Y for natural feel
        )
    }

    func setScrollDelta(x: Float, y: Float, stick: Stick = .left) {
        // Apply appropriate deadzone for the stick
        let deadzone = (stick == .left) ? settings.leftStickDeadzone : settings.rightStickDeadzone
        let adjustedX = abs(x) > deadzone ? x : 0
        let adjustedY = abs(y) > deadzone ? y : 0

        // Apply invert Y setting to scroll
        let yMultiplier: CGFloat = settings.invertY ? -1.0 : 1.0

        currentScrollDelta = CGPoint(
            x: CGFloat(adjustedX) * settings.scrollSensitivity,
            y: CGFloat(adjustedY) * settings.scrollSensitivity * yMultiplier
        )
    }

    func setPrecisionMode(_ enabled: Bool) {
        isPrecisionMode = enabled
        onLog?("🎯 Precision mode: \(enabled ? "ON" : "OFF")")
    }

    private func updateMouse() {
        // Handle mouse movement
        if currentMouseDelta.x != 0 || currentMouseDelta.y != 0 {
            moveMouse(deltaX: currentMouseDelta.x, deltaY: currentMouseDelta.y)
        }

        // Handle scrolling
        if currentScrollDelta.x != 0 || currentScrollDelta.y != 0 {
            scroll(deltaX: currentScrollDelta.x, deltaY: currentScrollDelta.y)
        }
    }

    private func moveMouse(deltaX: CGFloat, deltaY: CGFloat) {
        if debugMode { return }  // Skip in debug mode

        guard let currentPos = CGEvent(source: nil)?.location else { return }

        // Apply sticky mouse slowdown if enabled
        let stickyMultiplier = StickyMouseManager.shared.calculateSpeedMultiplier(at: currentPos)
        let adjustedDeltaX = deltaX * stickyMultiplier
        let adjustedDeltaY = deltaY * stickyMultiplier

        let newX = currentPos.x + adjustedDeltaX
        let newY = currentPos.y + adjustedDeltaY

        // Clamp to screen bounds
        let screens = NSScreen.screens
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        for screen in screens {
            maxX = max(maxX, screen.frame.maxX)
            maxY = max(maxY, screen.frame.maxY)
        }

        let clampedX = max(0, min(newX, maxX))
        let clampedY = max(0, min(newY, maxY))

        // Use CGWarpMouseCursorPosition to actually move the cursor
        // This triggers Dock/hot corners, unlike CGEvent posting
        let newPosition = CGPoint(x: clampedX, y: clampedY)
        CGWarpMouseCursorPosition(newPosition)

        // Check if cursor is near Dock edge and manually trigger reveal
        DockManager.shared.checkCursorForDockReveal(at: newPosition)

        // Post event for proper event handling in applications
        if isDragging {
            if let moveEvent = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDragged,
                                       mouseCursorPosition: newPosition,
                                       mouseButton: .left) {
                moveEvent.post(tap: .cghidEventTap)
            }
        } else {
            // Post .mouseMoved event for browsers/apps that rely on the event loop
            // CGWarpMouseCursorPosition alone doesn't generate events that apps listen for
            if let moveEvent = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved,
                                       mouseCursorPosition: newPosition,
                                       mouseButton: .left) {
                moveEvent.post(tap: .cghidEventTap)
            }
        }
    }

    private func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        if debugMode { return }  // Skip in debug mode

        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                      units: .pixel,
                                      wheelCount: 2,
                                      wheel1: Int32(deltaY),
                                      wheel2: Int32(deltaX),
                                      wheel3: 0) {
            scrollEvent.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Mouse Clicking

    func leftClick(modifiers: ModifierState = ModifierState()) {
        let modStr = modifiers.isEmpty ? "" : " (\(modifiers.description))"
        onLog?("🖱️ Left click\(modStr)")

        if debugMode { return }  // Skip in debug mode

        guard let pos = CGEvent(source: eventSource)?.location else { return }

        var flags: CGEventFlags = []
        if modifiers.command { flags.insert(.maskCommand) }
        if modifiers.option { flags.insert(.maskAlternate) }
        if modifiers.shift { flags.insert(.maskShift) }
        if modifiers.control { flags.insert(.maskControl) }

        if let downEvent = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown,
                                   mouseCursorPosition: pos, mouseButton: .left) {
            downEvent.flags = flags
            downEvent.post(tap: .cghidEventTap)
        }

        if let upEvent = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp,
                                 mouseCursorPosition: pos, mouseButton: .left) {
            upEvent.flags = flags
            upEvent.post(tap: .cghidEventTap)
        }
    }

    func rightClick() {
        onLog?("🖱️ Right click")

        if debugMode { return }  // Skip in debug mode

        guard let pos = CGEvent(source: eventSource)?.location else { return }

        if let downEvent = CGEvent(mouseEventSource: eventSource, mouseType: .rightMouseDown,
                                   mouseCursorPosition: pos, mouseButton: .right) {
            downEvent.post(tap: .cghidEventTap)
        }

        if let upEvent = CGEvent(mouseEventSource: eventSource, mouseType: .rightMouseUp,
                                 mouseCursorPosition: pos, mouseButton: .right) {
            upEvent.post(tap: .cghidEventTap)
        }
    }

    func middleClick() {
        guard let pos = CGEvent(source: eventSource)?.location else { return }

        if let downEvent = CGEvent(mouseEventSource: eventSource, mouseType: .otherMouseDown,
                                   mouseCursorPosition: pos, mouseButton: .center) {
            downEvent.post(tap: .cghidEventTap)
        }

        if let upEvent = CGEvent(mouseEventSource: eventSource, mouseType: .otherMouseUp,
                                 mouseCursorPosition: pos, mouseButton: .center) {
            upEvent.post(tap: .cghidEventTap)
        }

        onLog?("🖱️ Middle click")
    }

    func startDrag() {
        guard let pos = CGEvent(source: eventSource)?.location else { return }

        if let downEvent = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown,
                                   mouseCursorPosition: pos, mouseButton: .left) {
            downEvent.post(tap: .cghidEventTap)
        }
        isDragging = true
        onLog?("🖱️ Drag started")
    }

    func endDrag() {
        guard let pos = CGEvent(source: eventSource)?.location else { return }

        if let upEvent = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp,
                                 mouseCursorPosition: pos, mouseButton: .left) {
            upEvent.post(tap: .cghidEventTap)
        }
        isDragging = false
        onLog?("🖱️ Drag ended")
    }

    // MARK: - Modifier Key Simulation (for real keyboard behavior)

    /// Currently held modifier flags (updated by pressModifier/releaseModifier)
    private var heldModifierFlags: CGEventFlags = []

    /// Press a modifier key down (like holding Cmd on a real keyboard)
    func pressModifier(_ modifier: ModifierAction) {
        if debugMode { return }

        let (keyCode, flag) = modifierToKeyCodeAndFlag(modifier)
        guard let keyCode = keyCode, let flag = flag else { return }

        heldModifierFlags.insert(flag)

        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            event.flags = heldModifierFlags
            event.post(tap: .cghidEventTap)
        }
    }

    /// Release a modifier key (like releasing Cmd on a real keyboard)
    func releaseModifier(_ modifier: ModifierAction) {
        if debugMode { return }

        let (keyCode, flag) = modifierToKeyCodeAndFlag(modifier)
        guard let keyCode = keyCode, let flag = flag else { return }

        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            event.flags = heldModifierFlags
            event.post(tap: .cghidEventTap)
        }

        heldModifierFlags.remove(flag)
    }

    private func modifierToKeyCodeAndFlag(_ modifier: ModifierAction) -> (CGKeyCode?, CGEventFlags?) {
        switch modifier {
        case .command: return (CGKeyCode(kVK_Command), .maskCommand)
        case .shift: return (CGKeyCode(kVK_Shift), .maskShift)
        case .option: return (CGKeyCode(kVK_Option), .maskAlternate)
        case .control: return (CGKeyCode(kVK_Control), .maskControl)
        case .none: return (nil, nil)
        }
    }

    // MARK: - Keyboard Input

    func pressKey(_ keyCode: CGKeyCode, modifiers: ModifierState = ModifierState()) {
        if debugMode { return }  // Skip in debug mode

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }

        // Combine passed modifiers with any physically held modifiers
        var flags = heldModifierFlags
        if modifiers.command { flags.insert(.maskCommand) }
        if modifiers.option { flags.insert(.maskAlternate) }
        if modifiers.shift { flags.insert(.maskShift) }
        if modifiers.control { flags.insert(.maskControl) }

        event.flags = flags
        event.post(tap: .cghidEventTap)

        if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            upEvent.flags = flags
            upEvent.post(tap: .cghidEventTap)
        }
    }

    /// Press a key combo with specified modifiers (for custom keybindings)
    func pressKeyCombo(keyCode: UInt16?, command: Bool, shift: Bool, option: Bool, control: Bool) {
        if debugMode {
            // Log in debug mode
            var modDesc = ""
            if control { modDesc += "⌃" }
            if option { modDesc += "⌥" }
            if shift { modDesc += "⇧" }
            if command { modDesc += "⌘" }
            let keyDesc = keyCode.map { CapturedKey.keyCodeToString($0) } ?? "None"
            onLog?("⌨️  DEBUG: \(modDesc)\(keyDesc)")
            return
        }

        var modifiers = ModifierState()
        modifiers.command = command
        modifiers.shift = shift
        modifiers.option = option
        modifiers.control = control

        if let code = keyCode {
            pressKey(CGKeyCode(code), modifiers: modifiers)
        } else {
            // Pure modifier press - just send modifier flags
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return }
            var flags: CGEventFlags = []
            if command { flags.insert(.maskCommand) }
            if option { flags.insert(.maskAlternate) }
            if shift { flags.insert(.maskShift) }
            if control { flags.insert(.maskControl) }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    func typeText(_ text: String) {
        for char in text {
            if let keyCode = keyCodeForCharacter(char) {
                let needsShift = char.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(char)
                var modifiers = ModifierState()
                modifiers.shift = needsShift
                pressKey(keyCode, modifiers: modifiers)
                Thread.sleep(forTimeInterval: 0.01)  // Small delay between keys
            }
        }
    }

    // MARK: - Common Key Actions (Claude Code Optimized)

    func pressEnter(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_Return), modifiers: modifiers)
        onLog?("⏎ Enter\(modifiers.isEmpty ? "" : " (\(modifiers.description))")")
    }

    func pressEscape() {
        pressKey(CGKeyCode(kVK_Escape))
        onLog?("⎋ Escape")
    }

    func pressTab(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_Tab), modifiers: modifiers)
        onLog?("⇥ Tab\(modifiers.isEmpty ? "" : " (\(modifiers.description))")")
    }

    func pressArrowUp(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_UpArrow), modifiers: modifiers)
    }

    func pressArrowDown(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_DownArrow), modifiers: modifiers)
    }

    func pressArrowLeft(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_LeftArrow), modifiers: modifiers)
    }

    func pressArrowRight(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_RightArrow), modifiers: modifiers)
    }

    func pressSpace(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_Space), modifiers: modifiers)
        onLog?("␣ Space\(modifiers.isEmpty ? "" : " (\(modifiers.description))")")
    }

    func pressBackspace(modifiers: ModifierState = ModifierState()) {
        pressKey(CGKeyCode(kVK_Delete), modifiers: modifiers)
        onLog?("⌫ Backspace\(modifiers.isEmpty ? "" : " (\(modifiers.description))")")
    }

    // Claude Code specific shortcuts
    func interruptProcess() {
        // Ctrl+C to interrupt
        var modifiers = ModifierState()
        modifiers.control = true
        pressKey(CGKeyCode(kVK_ANSI_C), modifiers: modifiers)
        onLog?("⌃C Interrupt")
    }

    func acceptSuggestion() {
        // Tab to accept autocomplete
        pressTab()
    }

    func cancelOperation() {
        pressEscape()
    }

    func submitInput() {
        pressEnter()
    }

    func scrollUp() {
        scroll(deltaX: 0, deltaY: -30)
    }

    func scrollDown() {
        scroll(deltaX: 0, deltaY: 30)
    }

    func pageUp() {
        pressKey(CGKeyCode(kVK_PageUp))
        onLog?("⇞ Page Up")
    }

    func pageDown() {
        pressKey(CGKeyCode(kVK_PageDown))
        onLog?("⇟ Page Down")
    }

    // MARK: - Key Code Mapping

    private func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        let charToKeyCode: [Character: CGKeyCode] = [
            "a": CGKeyCode(kVK_ANSI_A), "b": CGKeyCode(kVK_ANSI_B), "c": CGKeyCode(kVK_ANSI_C),
            "d": CGKeyCode(kVK_ANSI_D), "e": CGKeyCode(kVK_ANSI_E), "f": CGKeyCode(kVK_ANSI_F),
            "g": CGKeyCode(kVK_ANSI_G), "h": CGKeyCode(kVK_ANSI_H), "i": CGKeyCode(kVK_ANSI_I),
            "j": CGKeyCode(kVK_ANSI_J), "k": CGKeyCode(kVK_ANSI_K), "l": CGKeyCode(kVK_ANSI_L),
            "m": CGKeyCode(kVK_ANSI_M), "n": CGKeyCode(kVK_ANSI_N), "o": CGKeyCode(kVK_ANSI_O),
            "p": CGKeyCode(kVK_ANSI_P), "q": CGKeyCode(kVK_ANSI_Q), "r": CGKeyCode(kVK_ANSI_R),
            "s": CGKeyCode(kVK_ANSI_S), "t": CGKeyCode(kVK_ANSI_T), "u": CGKeyCode(kVK_ANSI_U),
            "v": CGKeyCode(kVK_ANSI_V), "w": CGKeyCode(kVK_ANSI_W), "x": CGKeyCode(kVK_ANSI_X),
            "y": CGKeyCode(kVK_ANSI_Y), "z": CGKeyCode(kVK_ANSI_Z),
            "0": CGKeyCode(kVK_ANSI_0), "1": CGKeyCode(kVK_ANSI_1), "2": CGKeyCode(kVK_ANSI_2),
            "3": CGKeyCode(kVK_ANSI_3), "4": CGKeyCode(kVK_ANSI_4), "5": CGKeyCode(kVK_ANSI_5),
            "6": CGKeyCode(kVK_ANSI_6), "7": CGKeyCode(kVK_ANSI_7), "8": CGKeyCode(kVK_ANSI_8),
            "9": CGKeyCode(kVK_ANSI_9),
            " ": CGKeyCode(kVK_Space), "\n": CGKeyCode(kVK_Return), "\t": CGKeyCode(kVK_Tab),
            "-": CGKeyCode(kVK_ANSI_Minus), "=": CGKeyCode(kVK_ANSI_Equal),
            "[": CGKeyCode(kVK_ANSI_LeftBracket), "]": CGKeyCode(kVK_ANSI_RightBracket),
            "\\": CGKeyCode(kVK_ANSI_Backslash), ";": CGKeyCode(kVK_ANSI_Semicolon),
            "'": CGKeyCode(kVK_ANSI_Quote), ",": CGKeyCode(kVK_ANSI_Comma),
            ".": CGKeyCode(kVK_ANSI_Period), "/": CGKeyCode(kVK_ANSI_Slash),
            "`": CGKeyCode(kVK_ANSI_Grave),
        ]

        let lowercased = char.lowercased().first ?? char
        return charToKeyCode[lowercased]
    }
}
