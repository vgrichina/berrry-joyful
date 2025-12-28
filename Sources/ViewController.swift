import Cocoa
import GameController

class ViewController: NSViewController {
    // UI Components
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var modeIndicator: NSTextField!
    private var connectionIndicator: NSTextField!

    // Controllers
    private var controllers: [GCController] = []

    // State
    private var currentMode: ControlMode = .mouse
    private var modifiers = ModifierState()
    private var isVoiceHeld: Bool = false

    // Managers
    private let inputController = InputController.shared
    private let voiceManager = VoiceInputManager.shared
    private let settings = InputSettings.shared

    // Overlays
    private var statusOverlay: StatusOverlayWindow?
    private var helpOverlay: HelpOverlayWindow?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInputController()
        setupVoiceManager()
        setupStatusOverlay()
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
        modeIndicator = NSTextField(labelWithString: "🖱️ Mouse Mode")
        modeIndicator.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        modeIndicator.textColor = .white
        modeIndicator.frame = NSRect(x: 16, y: 10, width: 200, height: 30)
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

        // Log scroll view
        let logFrame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - headerHeight)
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

        // Initial messages
        log("🫐 berrry-joyful - Joy-Con Mac Controller")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("Optimized for Claude Code and terminal workflows")
        log("")
        log("Controls:")
        log("  Y        → Cycle modes (Mouse/Scroll/Text)")
        log("  A        → Enter  |  B → Escape  |  X → Tab")
        log("  Menu (+) → Voice input  |  Options (-) → Help")
        log("")
        log("Waiting for controller connection...")
        log("")
    }

    private func setupStatusOverlay() {
        statusOverlay = StatusOverlayWindow()
        statusOverlay?.updateMode(currentMode)
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
            self?.statusOverlay?.updateVoiceStatus(listening: true, transcript: transcript)
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
        // Check accessibility permission
        if !InputController.checkAccessibilityPermission() {
            log("⚠️  Accessibility permission required for mouse/keyboard control")
            log("   Go to: System Preferences → Privacy & Security → Accessibility")
            log("   Add berrry-joyful to the allowed apps")
            log("")
            InputController.requestAccessibilityPermission()
        } else {
            log("✅ Accessibility permission granted")
        }

        // Check microphone permission
        VoiceInputManager.requestMicrophonePermission { [weak self] granted in
            if granted {
                self?.log("✅ Microphone permission granted")
            } else {
                self?.log("⚠️  Microphone permission denied - voice input disabled")
            }
        }
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
            self?.statusOverlay?.updateConnectionStatus(connected: true, controllerName: name)
            self?.statusOverlay?.show()
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
            statusOverlay?.updateBattery(level: battery.batteryLevel)
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
                self?.statusOverlay?.updateConnectionStatus(connected: false)
            }
        }
    }

    // MARK: - Mode Switching

    private func cycleMode() {
        currentMode = currentMode.next()
        log("\(currentMode.icon) Switched to \(currentMode.rawValue) Mode")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.modeIndicator.stringValue = "\(self.currentMode.icon) \(self.currentMode.rawValue) Mode"
            self.statusOverlay?.updateMode(self.currentMode)
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
            self.cycleMode()
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

        // Shoulder buttons - modifiers
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.modifiers.option = pressed
            self?.updateModifierDisplay()
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.modifiers.shift = pressed
            self?.updateModifierDisplay()
            // L + R = Control
            if let self = self {
                self.modifiers.control = self.modifiers.option && self.modifiers.shift
            }
        }

        // Triggers
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            self.modifiers.command = pressed
            self.updateModifierDisplay()

            if !pressed && self.currentMode == .mouse {
                // ZL release = right click (if it was a quick press)
            }
        }

        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self = self, pressed else { return }
            // Just update command modifier state
            self.modifiers.command = true
        }

        // ZL quick press for right click
        var zlPressTime: Date?
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            self.modifiers.command = pressed
            self.updateModifierDisplay()

            if pressed {
                zlPressTime = Date()
            } else {
                // If quick press (< 0.3s), do right click
                if let pressTime = zlPressTime, Date().timeIntervalSince(pressTime) < 0.3 {
                    if self.currentMode == .mouse {
                        self.inputController.rightClick()
                    }
                }
                zlPressTime = nil
            }
        }

        // ZR for left click / drag
        var zrPressTime: Date?
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }

            if pressed {
                zrPressTime = Date()
            } else {
                if let pressTime = zrPressTime {
                    let duration = Date().timeIntervalSince(pressTime)
                    if duration < 0.2 {
                        // Quick press = click
                        self.inputController.leftClick()
                    } else {
                        // Was holding = end drag
                        self.inputController.endDrag()
                    }
                }
                zrPressTime = nil
            }
        }

        // Long ZR hold starts drag
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard pressed, value > 0.8 else { return }
            if let pressTime = zrPressTime, Date().timeIntervalSince(pressTime) > 0.3 {
                self?.inputController.startDrag()
            }
        }

        // Menu button - voice input
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleVoiceButton(pressed: pressed)
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
        if modifiers.command {
            // Cmd+Enter - submit with newline in some apps
            inputController.pressEnter(modifiers: modifiers)
        } else {
            inputController.pressEnter(modifiers: modifiers)
        }
        statusOverlay?.showAction("⏎ Enter")
    }

    private func handleButtonB() {
        if modifiers.command {
            // Cmd+B could be bold, or Ctrl+C for interrupt
            inputController.interruptProcess()
            statusOverlay?.showAction("⌃C Interrupt")
        } else {
            inputController.pressEscape()
            statusOverlay?.showAction("⎋ Escape")
        }
    }

    private func handleButtonX() {
        if modifiers.command {
            // Cmd+T for new tab in most apps
            inputController.pressKey(CGKeyCode(0x11), modifiers: modifiers)  // T key
            statusOverlay?.showAction("⌘T New Tab")
        } else {
            inputController.pressTab(modifiers: modifiers)
            statusOverlay?.showAction("⇥ Tab")
        }
    }

    private func handleDpad(x: Float, y: Float) {
        guard x != 0 || y != 0 else { return }

        switch currentMode {
        case .mouse, .text:
            // Arrow key navigation
            if y > 0.5 {
                inputController.pressArrowUp(modifiers: modifiers)
            } else if y < -0.5 {
                inputController.pressArrowDown(modifiers: modifiers)
            }
            if x > 0.5 {
                inputController.pressArrowRight(modifiers: modifiers)
            } else if x < -0.5 {
                inputController.pressArrowLeft(modifiers: modifiers)
            }

        case .scroll:
            // Page navigation
            if y > 0.5 {
                inputController.pageUp()
            } else if y < -0.5 {
                inputController.pageDown()
            }
        }
    }

    private func handleLeftStick(x: Float, y: Float) {
        switch currentMode {
        case .mouse:
            inputController.setMouseDelta(x: x, y: y)

        case .scroll:
            inputController.setScrollDelta(x: 0, y: y)

        case .text:
            // In text mode, left stick can be used for quick scrolling
            inputController.setScrollDelta(x: 0, y: y * 0.5)
        }
    }

    private func handleRightStick(x: Float, y: Float) {
        switch currentMode {
        case .mouse:
            // Fine movement or scrolling
            if modifiers.shift {
                inputController.setScrollDelta(x: x, y: y)
            } else {
                // Add to mouse movement for fine control
                inputController.setMouseDelta(x: x * 0.3, y: y * 0.3)
            }

        case .scroll:
            // Horizontal scroll
            inputController.setScrollDelta(x: x, y: 0)

        case .text:
            // Fine scroll
            inputController.setScrollDelta(x: x * 0.5, y: y * 0.5)
        }
    }

    private func handleVoiceButton(pressed: Bool) {
        guard settings.voiceInputEnabled else {
            if pressed {
                log("⚠️ Voice input disabled in settings")
            }
            return
        }

        isVoiceHeld = pressed

        if pressed {
            voiceManager.startListening()
            statusOverlay?.updateVoiceStatus(listening: true)
            statusOverlay?.showPersistent()
        } else {
            voiceManager.stopListening()
            statusOverlay?.updateVoiceStatus(listening: false)

            // Type the transcript if there is one
            if !voiceManager.currentTranscript.isEmpty {
                // Small delay to ensure final transcript is processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.voiceManager.typeCurrentTranscript()
                }
            }
        }
    }

    private func updateModifierDisplay() {
        statusOverlay?.updateModifiers(modifiers)
    }

    private func toggleHelp() {
        if helpOverlay?.isVisible == true {
            helpOverlay?.orderOut(nil)
            log("📖 Help closed")
        } else {
            if helpOverlay == nil {
                helpOverlay = HelpOverlayWindow()
            }
            helpOverlay?.makeKeyAndOrderFront(nil)
            log("📖 Help opened - Press Options (-) to close")
        }
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
