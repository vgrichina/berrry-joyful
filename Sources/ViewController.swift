import Cocoa
import GameController

class ViewController: NSViewController {
    // UI Components
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var modeIndicator: NSTextField!
    private var connectionIndicator: NSTextField!
    private var permissionPanel: NSView?
    private var accessibilityButton: NSButton?
    private var microphoneButton: NSButton?

    // Controllers
    private var controllers: [GCController] = []

    // State
    private var currentMode: ControlMode = .unified
    private var specialMode: SpecialInputMode = .none
    private var modifiers = ModifierState()
    private var isZLHeld: Bool = false
    private var isZRHeld: Bool = false

    // Managers
    private let inputController = InputController.shared
    private let voiceManager = VoiceInputManager.shared
    private let settings = InputSettings.shared


    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInputController()
        setupVoiceManager()
        checkPermissions()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        // Header with mode and connection indicators
        let headerHeight: CGFloat = 50
        let headerView = NSView(frame: NSRect(x: 0, y: view.bounds.height - headerHeight,
                                               width: view.bounds.width, height: headerHeight))
        headerView.autoresizingMask = [.width, .minYMargin]
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor

        // Mode indicator
        modeIndicator = NSTextField(labelWithString: "🎮 Unified Control")
        modeIndicator.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        modeIndicator.textColor = .white
        modeIndicator.frame = NSRect(x: 16, y: 10, width: 300, height: 30)
        headerView.addSubview(modeIndicator)

        // Connection indicator
        connectionIndicator = NSTextField(labelWithString: "🎮 No Controller")
        connectionIndicator.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        connectionIndicator.textColor = NSColor.secondaryLabelColor
        connectionIndicator.alignment = .right
        connectionIndicator.frame = NSRect(x: view.bounds.width - 220, y: 12, width: 200, height: 25)
        connectionIndicator.autoresizingMask = [.minXMargin]
        headerView.addSubview(connectionIndicator)

        view.addSubview(headerView)

        // Log scroll view - calculate frame accounting for potential permission panel
        let permissionPanelHeight: CGFloat = 80
        let logFrame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - headerHeight - permissionPanelHeight)
        scrollView = NSScrollView(frame: logFrame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)

        let contentSize = scrollView.contentSize
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor(white: 0.85, alpha: 1.0)
        textView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        scrollView.documentView = textView
        view.addSubview(scrollView)

        // Permission panel (add AFTER scrollView so it's on top)
        let permissionPanelY = view.bounds.height - headerHeight - permissionPanelHeight
        permissionPanel = NSView(frame: NSRect(x: 0, y: permissionPanelY, width: view.bounds.width, height: permissionPanelHeight))
        permissionPanel?.autoresizingMask = [.width, .minYMargin]
        permissionPanel?.wantsLayer = true
        permissionPanel?.layer?.backgroundColor = NSColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0).cgColor
        permissionPanel?.isHidden = true // Start hidden

        let warningLabel = NSTextField(labelWithString: "⚠️ Permissions Required")
        warningLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        warningLabel.textColor = .white
        warningLabel.frame = NSRect(x: 16, y: 45, width: 300, height: 25)
        permissionPanel?.addSubview(warningLabel)

        // Accessibility button
        accessibilityButton = NSButton(frame: NSRect(x: 16, y: 10, width: 200, height: 28))
        accessibilityButton?.title = "Grant Accessibility"
        accessibilityButton?.bezelStyle = .rounded
        accessibilityButton?.target = self
        accessibilityButton?.action = #selector(requestAccessibilityPermission)
        permissionPanel?.addSubview(accessibilityButton!)

        // Microphone button
        microphoneButton = NSButton(frame: NSRect(x: 230, y: 10, width: 200, height: 28))
        microphoneButton?.title = "Grant Microphone"
        microphoneButton?.bezelStyle = .rounded
        microphoneButton?.target = self
        microphoneButton?.action = #selector(requestMicrophonePermission)
        permissionPanel?.addSubview(microphoneButton!)

        // Refresh button
        let refreshButton = NSButton(frame: NSRect(x: 445, y: 10, width: 120, height: 28))
        refreshButton.title = "↻ Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshPermissions)
        permissionPanel?.addSubview(refreshButton)

        view.addSubview(permissionPanel!)

        // Initial messages
        log("🫐 berrry-joyful - Joy-Con Mac Controller")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("Optimized for Claude Code and terminal workflows")
        log("")
        log("Unified Control Mode:")
        log("  Left Stick   → Move mouse cursor")
        log("  Right Stick  → Scroll vertically/horizontally")
        log("  ZR           → Left click")
        log("  ZL           → Right click")
        log("  D-Pad        → Arrow keys (↑↓←→)")
        log("  A/B/X/Y      → Enter / Escape / Tab / Space")
        log("")
        log("Special Modes (hold):")
        log("  ZL + ZR      → 🎤 Voice input (speak to type)")
        log("  L + R        → ✨ Precision mode")
        log("  Options (-)  → Help overlay")
        log("")
        log("Waiting for controller connection...")
        log("")
    }

    private func setupInputController() {
        inputController.onLog = { [weak self] message in
            self?.log(message)
        }
        inputController.startMouseUpdates()
    }

    private func setupVoiceManager() {
        voiceManager.onLog = { [weak self] message in
            self?.log(message)
        }
        voiceManager.onTranscriptUpdate = { [weak self] transcript in
            // Show transcript in log
            self?.log("🎤 \(transcript)")
        }
        voiceManager.onFinalTranscript = { [weak self] transcript in
            guard let self = self else { return }
            // Check if it's a command first
            if !self.voiceManager.processVoiceCommand(transcript) {
                // Not a command, type it
                self.voiceManager.typeCurrentTranscript()
            }
        }
        voiceManager.onError = { [weak self] error in
            self?.log("❌ Voice Error: \(error)")
        }
    }

    private func checkPermissions() {
        updatePermissionPanel()
    }

    private func updatePermissionPanel() {
        var needsPermissions = false

        // Check accessibility permission
        let hasAccessibility = InputController.checkAccessibilityPermission()
        if !hasAccessibility {
            log("⚠️  Accessibility permission required for mouse/keyboard control")
            log("   Click 'Grant Accessibility' button above to open System Settings")
            log("")
            needsPermissions = true
            accessibilityButton?.isEnabled = true
            accessibilityButton?.title = "Grant Accessibility"
        } else {
            log("✅ Accessibility permission granted")
            accessibilityButton?.isEnabled = false
            accessibilityButton?.title = "✅ Accessibility OK"
        }

        // Check microphone permission (don't request at startup)
        let hasMicrophone = VoiceInputManager.checkMicrophonePermission()
        if !hasMicrophone {
            // Don't log warning - only show in panel if user tries to use voice
            microphoneButton?.isEnabled = true
            microphoneButton?.title = "Grant Microphone"
        } else {
            log("✅ Microphone permission granted")
            microphoneButton?.isEnabled = false
            microphoneButton?.title = "✅ Microphone OK"
        }

        // Show panel only if accessibility missing (critical)
        // Microphone is optional - only needed for voice mode
        DispatchQueue.main.async { [weak self] in
            self?.permissionPanel?.isHidden = !needsPermissions
            if needsPermissions {
                self?.log("🔧 Permission panel shown - look for red banner at top of window")
            }
        }
    }

    @objc private func requestAccessibilityPermission() {
        log("📋 Opening Accessibility settings...")
        InputController.requestAccessibilityPermission()

        // Check again after a delay (user needs to grant in System Settings)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updatePermissionPanel()
        }
    }

    @objc private func requestMicrophonePermission() {
        log("📋 Requesting microphone permission...")
        VoiceInputManager.requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.log("✅ Microphone permission granted")
                } else {
                    self?.log("❌ Microphone permission denied")
                }
                self?.updatePermissionPanel()
            }
        }
    }

    @objc private func refreshPermissions() {
        log("🔄 Refreshing permissions...")
        updatePermissionPanel()
    }

    // MARK: - Logging

    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textView = self.textView else { return }

            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)\n"

            let attrString = NSAttributedString(string: logMessage, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor(white: 0.85, alpha: 1.0)
            ])

            textView.textStorage?.append(attrString)
            textView.scrollToEndOfDocument(nil)
        }
    }

    // MARK: - Controller Connection

    func controllerConnected(_ controller: GCController) {
        controllers.append(controller)

        let name = controller.vendorName ?? "Controller"
        log("✅ Controller Connected: \(name)")
        log("   Product: \(controller.productCategory)")

        DispatchQueue.main.async { [weak self] in
            self?.connectionIndicator.stringValue = "🎮 \(name)"
            self?.connectionIndicator.textColor = .white
        }

        // Setup input handlers
        if let gamepad = controller.extendedGamepad {
            log("   Type: Extended Gamepad")
            setupExtendedGamepadHandlers(gamepad)
        } else if let micro = controller.microGamepad {
            log("   Type: Micro Gamepad")
            setupMicroGamepadHandlers(micro)
        }

        // Monitor battery
        if let battery = controller.battery {
            log(String(format: "   Battery: %.0f%%", battery.batteryLevel * 100))
        }

        log("")
    }

    func controllerDisconnected(_ controller: GCController) {
        controllers.removeAll { $0 == controller }
        log("❌ Controller Disconnected: \(controller.vendorName ?? "Unknown")")

        DispatchQueue.main.async { [weak self] in
            if self?.controllers.isEmpty == true {
                self?.connectionIndicator.stringValue = "🎮 No Controller"
                self?.connectionIndicator.textColor = NSColor.secondaryLabelColor
            }
        }
    }

    // MARK: - Special Mode Management

    private func updateSpecialMode() {
        let newMode: SpecialInputMode

        // ZL + ZR = Voice mode
        if isZLHeld && isZRHeld {
            newMode = .voice
        }
        // L + R = Precision mode
        else if modifiers.option && modifiers.shift {
            newMode = .precision
        } else {
            newMode = .none
        }

        // Mode changed?
        if newMode != specialMode {
            specialMode = newMode
            handleSpecialModeChange(to: newMode)
        }
    }

    private func handleSpecialModeChange(to mode: SpecialInputMode) {
        switch mode {
        case .voice:
            // Start voice input
            log("🎤 Voice input activated - speak now")
            voiceManager.startListening()
            DispatchQueue.main.async { [weak self] in
                self?.modeIndicator.stringValue = "🎤 Voice Input"
            }

        case .precision:
            // Activate precision mode
            log("✨ Precision mode activated")
            inputController.setPrecisionMode(true)
            DispatchQueue.main.async { [weak self] in
                self?.modeIndicator.stringValue = "✨ Precision Mode"
            }

        case .none:
            // Return to unified mode
            if specialMode == .voice {
                voiceManager.stopListening()
                // Type the transcript if we have one
                if !voiceManager.currentTranscript.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.voiceManager.typeCurrentTranscript()
                    }
                }
            }
            if specialMode == .precision {
                inputController.setPrecisionMode(false)
            }
            DispatchQueue.main.async { [weak self] in
                self?.modeIndicator.stringValue = "🎮 Unified Control"
            }
        }
    }

    // MARK: - Extended Gamepad Handlers

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            self.handleButtonA()
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            self.handleButtonB()
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            self.handleButtonX()
        }

        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self, pressed else { return }
            // Y button now presses Space
            self.log("🕹️ Button Y → Space")
            self.inputController.pressSpace(modifiers: self.modifiers)
        }

        // D-pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDpad(x: xValue, y: yValue)
        }

        // Left stick - primary movement/scroll
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleLeftStick(x: xValue, y: yValue)
        }

        // Right stick - fine movement/scroll
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleRightStick(x: xValue, y: yValue)
        }

        // Left stick click - middle click
        if let leftStickButton = gamepad.leftThumbstickButton {
            leftStickButton.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                self?.inputController.middleClick()
            }
        }

        // Right stick click - precision mode toggle
        if let rightStickButton = gamepad.rightThumbstickButton {
            rightStickButton.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.inputController.setPrecisionMode(pressed)
            }
        }

        // Shoulder buttons - precision mode activation + modifiers
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            self.modifiers.option = pressed
            self.updateModifierDisplay()
            self.updateSpecialMode()  // Check for L+R precision mode
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            self.modifiers.shift = pressed
            self.updateModifierDisplay()
            self.updateSpecialMode()  // Check for L+R precision mode
        }


        // ZL trigger - right click + voice activation combo
        var zlPressTime: Date?
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }

            self.isZLHeld = pressed

            if pressed {
                zlPressTime = Date()
            } else {
                // Check if this was a quick press for right click
                // (only if not in voice mode)
                if let pressTime = zlPressTime,
                   Date().timeIntervalSince(pressTime) < 0.3,
                   self.specialMode != .voice {
                    self.log("🕹️ ZL (quick) → Right click")
                    self.inputController.rightClick()
                }
                zlPressTime = nil
            }

            // Update special modes (voice activation)
            self.updateSpecialMode()
        }

        // ZR trigger - left click + voice activation combo
        var zrPressTime: Date?
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }

            self.isZRHeld = pressed

            if pressed {
                zrPressTime = Date()
            } else {
                // Check if this was a click or drag end
                // (only if not in voice mode)
                if self.specialMode != .voice {
                    if let pressTime = zrPressTime {
                        let duration = Date().timeIntervalSince(pressTime)
                        if duration < 0.2 {
                            // Quick press = click
                            self.log("🕹️ ZR (quick) → Left click")
                            self.inputController.leftClick()
                        } else {
                            // Was holding = end drag
                            self.log("🕹️ ZR (release) → End drag")
                            self.inputController.endDrag()
                        }
                    }
                }
                zrPressTime = nil
            }

            // Update special modes (voice activation)
            self.updateSpecialMode()
        }

        // Long ZR hold starts drag
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard pressed, value > 0.8 else { return }
            if let pressTime = zrPressTime, Date().timeIntervalSince(pressTime) > 0.3 {
                self?.log("🕹️ ZR (hold) → Start drag")
                self?.inputController.startDrag()
            }
        }

        // Menu button - unused (could be settings in future)
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.log("ℹ️ Menu button - currently unassigned")
        }

        // Options button - help
        if let buttonOptions = gamepad.buttonOptions {
            buttonOptions.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                self?.toggleHelp()
            }
        }
    }

    // MARK: - Button Handlers

    private func handleButtonA() {
        log("🕹️ Button A → Enter")
        if modifiers.command {
            // Cmd+Enter - submit with newline in some apps
            inputController.pressEnter(modifiers: modifiers)
        } else {
            inputController.pressEnter(modifiers: modifiers)
        }
    }

    private func handleButtonB() {
        if modifiers.command {
            log("🕹️ Button B + Cmd → Interrupt (Ctrl+C)")
            // Cmd+B could be bold, or Ctrl+C for interrupt
            inputController.interruptProcess()
        } else {
            log("🕹️ Button B → Escape")
            inputController.pressEscape()
        }
    }

    private func handleButtonX() {
        if modifiers.command {
            log("🕹️ Button X + Cmd → New Tab (Cmd+T)")
            // Cmd+T for new tab in most apps
            inputController.pressKey(CGKeyCode(0x11), modifiers: modifiers)  // T key
        } else {
            log("🕹️ Button X → Tab")
            inputController.pressTab(modifiers: modifiers)
        }
    }

    private func handleDpad(x: Float, y: Float) {
        guard x != 0 || y != 0 else { return }

        // Unified mode: D-pad always does arrow keys
        if y > 0.5 {
            log("🕹️ D-pad Up → ↑")
            inputController.pressArrowUp(modifiers: modifiers)
        } else if y < -0.5 {
            log("🕹️ D-pad Down → ↓")
            inputController.pressArrowDown(modifiers: modifiers)
        }
        if x > 0.5 {
            log("🕹️ D-pad Right → →")
            inputController.pressArrowRight(modifiers: modifiers)
        } else if x < -0.5 {
            log("🕹️ D-pad Left → ←")
            inputController.pressArrowLeft(modifiers: modifiers)
        }
    }

    private func handleLeftStick(x: Float, y: Float) {
        // Log only when stick is actually moved (not centered)
        if abs(x) > 0.1 || abs(y) > 0.1 {
            log(String(format: "🕹️ Left stick: (%.2f, %.2f) → mouse move", x, y))
        }
        // Unified mode: Left stick always moves mouse
        inputController.setMouseDelta(x: x, y: y)
    }

    private func handleRightStick(x: Float, y: Float) {
        // Log only when stick is actually moved (not centered)
        if abs(x) > 0.1 || abs(y) > 0.1 {
            log(String(format: "🕹️ Right stick: (%.2f, %.2f) → scroll", x, y))
        }
        // Unified mode: Right stick always scrolls (both axes)
        inputController.setScrollDelta(x: x, y: y)
    }

    private func updateModifierDisplay() {
        // Modifiers now only shown in window UI
    }

    private func toggleHelp() {
        // Help removed - all info now in log and menu bar
        log("ℹ️ Help: All controls are shown in the startup log above")
    }

    // MARK: - Micro Gamepad (Fallback)

    private func setupMicroGamepadHandlers(_ gamepad: GCMicroGamepad) {
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.inputController.pressEnter()
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.inputController.pressTab()
        }

        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDpad(x: xValue, y: yValue)
        }
    }
}
