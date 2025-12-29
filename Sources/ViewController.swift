import Cocoa
import JoyConSwift
import Carbon.HIToolbox

enum ControlModeTab: String {
    case mouse = "Mouse"
    case keyboard = "Keyboard"
    case voice = "Voice"
}

class ViewController: NSViewController {
    // MARK: - UI Components

    // Header
    private var connectionLabel: NSTextField!
    private var batteryLabel: NSTextField!
    private var ledIndicator: NSTextField!

    // Mode Tabs
    private var mouseTabButton: NSButton!
    private var keyboardTabButton: NSButton!
    private var voiceTabButton: NSButton!
    private var currentTab: ControlModeTab = .mouse

    // Configuration Panels (one for each mode)
    private var mouseConfigPanel: NSView!
    private var keyboardConfigPanel: NSView!
    private var voiceConfigPanel: NSView!

    // Mouse Controls
    private var sensitivitySlider: NSSlider!
    private var sensitivityLabel: NSTextField!
    private var deadzoneSlider: NSSlider!
    private var deadzoneLabel: NSTextField!
    private var invertYCheckbox: NSButton!
    private var accelerationCheckbox: NSButton!

    // Keyboard Controls
    private var keyboardPresetPopup: NSPopUpButton!

    // Voice Controls
    private var voiceStatusLabel: NSTextField!
    private var voiceActivationMatrix: NSMatrix!

    // Bottom Bar & Debug Log
    private var debugLogButton: NSButton!
    private var debugLogContainer: NSView!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var isDebugLogExpanded: Bool = true

    // MARK: - Controllers & State

    var controllers: [Controller] = []
    private var currentMode: ControlMode = .unified
    private var specialMode: SpecialInputMode = .none
    private var modifiers = ModifierState()
    private var isZLHeld: Bool = false
    private var isZRHeld: Bool = false

    // Managers
    private let inputController = InputController.shared
    private let voiceManager = VoiceInputManager.shared
    private let settings = InputSettings.shared

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInputController()
        setupVoiceManager()
        log("🫐 berrry-joyful initialized - waiting for controllers...")
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor

        let yOffset = setupHeader()
        let yAfterTabs = setupModeTabs(below: yOffset)
        let yAfterConfig = setupConfigurationPanels(below: yAfterTabs)
        setupBottomBarAndDebugLog(below: yAfterConfig)

        // Show initial tab
        switchToTab(.mouse)
    }

    private func setupHeader() -> CGFloat {
        let headerHeight: CGFloat = 60
        let headerView = NSView(frame: NSRect(
            x: 0,
            y: view.bounds.height - headerHeight,
            width: view.bounds.width,
            height: headerHeight
        ))
        headerView.autoresizingMask = [.width, .minYMargin]
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor

        // Connection status
        connectionLabel = NSTextField(labelWithString: "🔍 No Joy-Con detected")
        connectionLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        connectionLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        connectionLabel.frame = NSRect(x: 20, y: 20, width: 400, height: 25)
        headerView.addSubview(connectionLabel)

        // Battery indicator
        batteryLabel = NSTextField(labelWithString: "")
        batteryLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        batteryLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        batteryLabel.alignment = .right
        batteryLabel.frame = NSRect(x: view.bounds.width - 180, y: 25, width: 100, height: 20)
        batteryLabel.autoresizingMask = [.minXMargin]
        headerView.addSubview(batteryLabel)

        // LED indicator
        ledIndicator = NSTextField(labelWithString: "")
        ledIndicator.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        ledIndicator.textColor = NSColor(white: 0.6, alpha: 1.0)
        ledIndicator.alignment = .right
        ledIndicator.frame = NSRect(x: view.bounds.width - 70, y: 25, width: 60, height: 20)
        ledIndicator.autoresizingMask = [.minXMargin]
        headerView.addSubview(ledIndicator)

        view.addSubview(headerView)
        return view.bounds.height - headerHeight
    }

    private func setupModeTabs(below yPosition: CGFloat) -> CGFloat {
        let tabHeight: CGFloat = 50
        let tabsView = NSView(frame: NSRect(
            x: 0,
            y: yPosition - tabHeight,
            width: view.bounds.width,
            height: tabHeight
        ))
        tabsView.autoresizingMask = [.width, .minYMargin]
        tabsView.wantsLayer = true
        tabsView.layer?.backgroundColor = NSColor(white: 0.9, alpha: 1.0).cgColor

        let tabWidth: CGFloat = 150
        let spacing: CGFloat = 10
        let startX: CGFloat = 20

        // Mouse Tab
        mouseTabButton = createTabButton(
            title: "🖱️ Mouse",
            frame: NSRect(x: startX, y: 10, width: tabWidth, height: 30),
            tag: 0
        )
        tabsView.addSubview(mouseTabButton)

        // Keyboard Tab
        keyboardTabButton = createTabButton(
            title: "⌨️ Keyboard",
            frame: NSRect(x: startX + tabWidth + spacing, y: 10, width: tabWidth, height: 30),
            tag: 1
        )
        tabsView.addSubview(keyboardTabButton)

        // Voice Tab
        voiceTabButton = createTabButton(
            title: "🎤 Voice",
            frame: NSRect(x: startX + (tabWidth + spacing) * 2, y: 10, width: tabWidth, height: 30),
            tag: 2
        )
        tabsView.addSubview(voiceTabButton)

        view.addSubview(tabsView)
        return yPosition - tabHeight
    }

    private func createTabButton(title: String, frame: NSRect, tag: Int) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(tabButtonClicked(_:))
        button.tag = tag
        return button
    }

    private func setupConfigurationPanels(below yPosition: CGFloat) -> CGFloat {
        let configHeight: CGFloat = 300

        // Mouse Config Panel
        mouseConfigPanel = createMouseConfigPanel(
            frame: NSRect(x: 0, y: yPosition - configHeight, width: view.bounds.width, height: configHeight)
        )
        mouseConfigPanel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(mouseConfigPanel)

        // Keyboard Config Panel
        keyboardConfigPanel = createKeyboardConfigPanel(
            frame: NSRect(x: 0, y: yPosition - configHeight, width: view.bounds.width, height: configHeight)
        )
        keyboardConfigPanel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(keyboardConfigPanel)

        // Voice Config Panel
        voiceConfigPanel = createVoiceConfigPanel(
            frame: NSRect(x: 0, y: yPosition - configHeight, width: view.bounds.width, height: configHeight)
        )
        voiceConfigPanel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(voiceConfigPanel)

        return yPosition - configHeight
    }

    private func createMouseConfigPanel(frame: NSRect) -> NSView {
        let panel = NSView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor

        var y: CGFloat = frame.height - 40

        // Title
        let titleLabel = NSTextField(labelWithString: "Mouse Control Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y -= 50

        // Sensitivity Slider
        let sensitivityTitleLabel = NSTextField(labelWithString: "Sensitivity:")
        sensitivityTitleLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        sensitivityTitleLabel.isBezeled = false
        sensitivityTitleLabel.isEditable = false
        sensitivityTitleLabel.drawsBackground = false
        panel.addSubview(sensitivityTitleLabel)

        sensitivitySlider = NSSlider(frame: NSRect(x: 130, y: y, width: 300, height: 20))
        sensitivitySlider.minValue = 0.5
        sensitivitySlider.maxValue = 3.0
        sensitivitySlider.doubleValue = Double(settings.mouseSensitivity)
        sensitivitySlider.target = self
        sensitivitySlider.action = #selector(sensitivityChanged(_:))
        panel.addSubview(sensitivitySlider)

        sensitivityLabel = NSTextField(labelWithString: String(format: "%.1fx", settings.mouseSensitivity))
        sensitivityLabel.frame = NSRect(x: 440, y: y, width: 60, height: 20)
        sensitivityLabel.isBezeled = false
        sensitivityLabel.isEditable = false
        sensitivityLabel.drawsBackground = false
        panel.addSubview(sensitivityLabel)
        y -= 35

        // Deadzone Slider
        let deadzoneTitleLabel = NSTextField(labelWithString: "Deadzone:")
        deadzoneTitleLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        deadzoneTitleLabel.isBezeled = false
        deadzoneTitleLabel.isEditable = false
        deadzoneTitleLabel.drawsBackground = false
        panel.addSubview(deadzoneTitleLabel)

        deadzoneSlider = NSSlider(frame: NSRect(x: 130, y: y, width: 300, height: 20))
        deadzoneSlider.minValue = 0.0
        deadzoneSlider.maxValue = 0.3
        deadzoneSlider.doubleValue = Double(settings.stickDeadzone)
        deadzoneSlider.target = self
        deadzoneSlider.action = #selector(deadzoneChanged(_:))
        panel.addSubview(deadzoneSlider)

        deadzoneLabel = NSTextField(labelWithString: String(format: "%.0f%%", settings.stickDeadzone * 100))
        deadzoneLabel.frame = NSRect(x: 440, y: y, width: 60, height: 20)
        deadzoneLabel.isBezeled = false
        deadzoneLabel.isEditable = false
        deadzoneLabel.drawsBackground = false
        panel.addSubview(deadzoneLabel)
        y -= 40

        // Checkboxes
        invertYCheckbox = NSButton(checkboxWithTitle: "Invert Y-Axis", target: self, action: #selector(invertYChanged(_:)))
        invertYCheckbox.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        invertYCheckbox.state = settings.invertY ? .on : .off
        panel.addSubview(invertYCheckbox)

        accelerationCheckbox = NSButton(checkboxWithTitle: "Acceleration", target: self, action: #selector(accelerationChanged(_:)))
        accelerationCheckbox.frame = NSRect(x: 200, y: y, width: 150, height: 20)
        accelerationCheckbox.state = settings.mouseAcceleration ? .on : .off
        panel.addSubview(accelerationCheckbox)
        y -= 50

        // Status info
        let statusLabel = NSTextField(wrappingLabelWithString: "Mouse control is always active when a Joy-Con is connected.\nUse the left stick to move the cursor.")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 20, width: frame.width - 40, height: 40)
        panel.addSubview(statusLabel)

        return panel
    }

    private func createKeyboardConfigPanel(frame: NSRect) -> NSView {
        let panel = NSView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor

        var y: CGFloat = frame.height - 40

        // Title
        let titleLabel = NSTextField(labelWithString: "Keyboard Layout & Mapping")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y -= 50

        // Layout Preset
        let presetLabel = NSTextField(labelWithString: "Layout Preset:")
        presetLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        presetLabel.isBezeled = false
        presetLabel.isEditable = false
        presetLabel.drawsBackground = false
        panel.addSubview(presetLabel)

        keyboardPresetPopup = NSPopUpButton(frame: NSRect(x: 130, y: y - 5, width: 250, height: 25))
        keyboardPresetPopup.addItems(withTitles: [
            "Gaming (WASD + Space/Jump)",
            "Text Editing (Arrow keys, Delete)",
            "Media Controls (Play/Pause, Volume)",
            "Custom Mapping"
        ])
        keyboardPresetPopup.selectItem(at: 3) // Default to custom
        keyboardPresetPopup.target = self
        keyboardPresetPopup.action = #selector(keyboardPresetChanged(_:))
        panel.addSubview(keyboardPresetPopup)
        y -= 50

        // Button mapping guide
        let mappingLabel = NSTextField(wrappingLabelWithString: """
        Desktop + Terminal Profile:
        A → Enter    B → Escape    X → Tab    Y → Enter
        D-Pad → Number Keys 1-4    L → Cmd    R → Shift
        R+X → Shift+Tab    L+X → Cmd+Tab    L+R+X → Cmd+Shift+Tab
        ZL → Cmd+Shift+[    ZR → Cmd+Shift+]    ZL+ZR → Voice Input
        Minus → Backspace    L+A → Cmd+Click
        """)
        mappingLabel.font = NSFont.systemFont(ofSize: 11)
        mappingLabel.frame = NSRect(x: 20, y: y - 80, width: frame.width - 40, height: 80)
        panel.addSubview(mappingLabel)

        // Status info
        let statusLabel = NSTextField(wrappingLabelWithString: "Keyboard control is always active when a Joy-Con is connected.\nButtons send key presses immediately.")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 20, width: frame.width - 40, height: 40)
        panel.addSubview(statusLabel)

        return panel
    }

    private func createVoiceConfigPanel(frame: NSRect) -> NSView {
        let panel = NSView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor

        var y: CGFloat = frame.height - 40

        // Title
        let titleLabel = NSTextField(labelWithString: "Voice Recognition")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y -= 40

        // Permission Status
        let hasPermissions = VoiceInputManager.checkVoiceInputPermissions()
        let permissionLabel = NSTextField(labelWithString: hasPermissions ? "✅ Permissions Granted" : "⚠️ Permissions Required")
        permissionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        permissionLabel.textColor = hasPermissions ? NSColor.systemGreen : NSColor.systemOrange
        permissionLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        permissionLabel.isBezeled = false
        permissionLabel.isEditable = false
        permissionLabel.drawsBackground = false
        panel.addSubview(permissionLabel)

        // Grant Permissions button (if not granted)
        if !hasPermissions {
            let grantButton = NSButton(frame: NSRect(x: 320, y: y - 2, width: 150, height: 24))
            grantButton.title = "Grant Permissions"
            grantButton.bezelStyle = .rounded
            grantButton.target = self
            grantButton.action = #selector(grantVoicePermissionsClicked)
            panel.addSubview(grantButton)
        }
        y -= 40

        // Status
        voiceStatusLabel = NSTextField(labelWithString: "Status: ⏸️ Ready")
        voiceStatusLabel.font = NSFont.systemFont(ofSize: 13)
        voiceStatusLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        voiceStatusLabel.isBezeled = false
        voiceStatusLabel.isEditable = false
        voiceStatusLabel.drawsBackground = false
        panel.addSubview(voiceStatusLabel)
        y -= 40

        // Activation method
        let activationLabel = NSTextField(labelWithString: "Activation Method:")
        activationLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        activationLabel.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        activationLabel.isBezeled = false
        activationLabel.isEditable = false
        activationLabel.drawsBackground = false
        panel.addSubview(activationLabel)
        y -= 30

        // Create radio buttons using NSMatrix (legacy but simple for radio groups)
        voiceActivationMatrix = NSMatrix(frame: NSRect(x: 30, y: y - 80, width: 400, height: 80))
        voiceActivationMatrix.cellSize = NSSize(width: 400, height: 20)
        voiceActivationMatrix.prototype = NSButtonCell()
        voiceActivationMatrix.addRow()
        voiceActivationMatrix.addRow()
        voiceActivationMatrix.addRow()

        // Configure radio buttons
        for row in 0..<voiceActivationMatrix.numberOfRows {
            if let cell = voiceActivationMatrix.cell(atRow: row, column: 0) as? NSButtonCell {
                cell.setButtonType(.radio)
                switch row {
                case 0:
                    cell.title = "Hold [ZL + ZR] to speak (recommended)"
                    cell.state = .on
                case 1:
                    cell.title = "Always listening (experimental)"
                case 2:
                    cell.title = "Wake word: \"Hey Mac\" (not implemented)"
                    cell.isEnabled = false
                default:
                    break
                }
            }
        }

        panel.addSubview(voiceActivationMatrix)
        y -= 100

        // Info text
        let infoLabel = NSTextField(wrappingLabelWithString: "Voice input is text-only. Speak naturally and your words will be typed automatically.")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: y - 30, width: frame.width - 40, height: 30)
        panel.addSubview(infoLabel)

        // Status info
        let statusLabel = NSTextField(wrappingLabelWithString: "Hold ZL + ZR on your Joy-Con to activate voice input.\nSpeak naturally and release to type your words.")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 20, width: frame.width - 40, height: 40)
        panel.addSubview(statusLabel)

        return panel
    }

    private func setupBottomBarAndDebugLog(below yPosition: CGFloat) {
        // Bottom bar with debug toggle
        let bottomBarHeight: CGFloat = 40
        let bottomBar = NSView(frame: NSRect(
            x: 0,
            y: yPosition - bottomBarHeight,
            width: view.bounds.width,
            height: bottomBarHeight
        ))
        bottomBar.autoresizingMask = [.width, .minYMargin]
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor(white: 0.9, alpha: 1.0).cgColor

        debugLogButton = NSButton(frame: NSRect(x: view.bounds.width - 150, y: 5, width: 130, height: 30))
        debugLogButton.title = "▼ Debug Log"
        debugLogButton.bezelStyle = .rounded
        debugLogButton.target = self
        debugLogButton.action = #selector(toggleDebugLog(_:))
        debugLogButton.autoresizingMask = [.minXMargin]
        bottomBar.addSubview(debugLogButton)

        view.addSubview(bottomBar)

        // Debug log container
        let logHeight: CGFloat = 150
        debugLogContainer = NSView(frame: NSRect(
            x: 0,
            y: yPosition - bottomBarHeight - logHeight,
            width: view.bounds.width,
            height: logHeight
        ))
        debugLogContainer.autoresizingMask = [.width, .minYMargin]

        scrollView = NSScrollView(frame: debugLogContainer.bounds)
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
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor(white: 0.85, alpha: 1.0)
        textView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView
        debugLogContainer.addSubview(scrollView)
        view.addSubview(debugLogContainer)

        // Start with log expanded
        debugLogContainer.isHidden = false
    }

    // MARK: - UI Actions

    @objc private func tabButtonClicked(_ sender: NSButton) {
        switch sender.tag {
        case 0: switchToTab(.mouse)
        case 1: switchToTab(.keyboard)
        case 2: switchToTab(.voice)
        default: break
        }
    }

    private func switchToTab(_ tab: ControlModeTab) {
        currentTab = tab

        // Update button states
        mouseTabButton.state = (tab == .mouse) ? .on : .off
        keyboardTabButton.state = (tab == .keyboard) ? .on : .off
        voiceTabButton.state = (tab == .voice) ? .on : .off

        // Show/hide panels
        mouseConfigPanel.isHidden = (tab != .mouse)
        keyboardConfigPanel.isHidden = (tab != .keyboard)
        voiceConfigPanel.isHidden = (tab != .voice)

        log("Switched to \(tab.rawValue) tab")
    }

    @objc private func sensitivityChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        settings.mouseSensitivity = value
        sensitivityLabel.stringValue = String(format: "%.1fx", value)
    }

    @objc private func deadzoneChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        settings.stickDeadzone = value
        deadzoneLabel.stringValue = String(format: "%.0f%%", value * 100)
    }

    @objc private func invertYChanged(_ sender: NSButton) {
        settings.invertY = (sender.state == .on)
        log("Invert Y: \(settings.invertY)")
    }

    @objc private func accelerationChanged(_ sender: NSButton) {
        settings.mouseAcceleration = (sender.state == .on)
        log("Mouse acceleration: \(settings.mouseAcceleration)")
    }

    @objc private func keyboardPresetChanged(_ sender: NSPopUpButton) {
        let presetName = sender.titleOfSelectedItem ?? "Unknown"
        log("Keyboard preset changed to: \(presetName)")
    }

    @objc private func grantVoicePermissionsClicked() {
        log("Requesting voice input permissions...")
        VoiceInputManager.requestVoiceInputPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.log("✅ Voice input permissions granted!")
                    self?.voiceManager.isAuthorized = true
                    // Recreate the voice panel to update UI
                    if let panel = self?.voiceConfigPanel {
                        panel.removeFromSuperview()
                        self?.voiceConfigPanel = self?.createVoiceConfigPanel(
                            frame: NSRect(x: 0, y: panel.frame.minY, width: panel.frame.width, height: panel.frame.height)
                        )
                        self?.voiceConfigPanel.autoresizingMask = [.width, .minYMargin]
                        self?.voiceConfigPanel.isHidden = (self?.currentTab != .voice)
                        self?.view.addSubview(self?.voiceConfigPanel ?? NSView())
                    }
                } else {
                    self?.log("❌ Voice input permissions denied")
                }
            }
        }
    }

    @objc private func toggleDebugLog(_ sender: NSButton) {
        isDebugLogExpanded = !isDebugLogExpanded

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            debugLogContainer.animator().isHidden = !isDebugLogExpanded
        }, completionHandler: {
            self.debugLogButton.title = self.isDebugLogExpanded ? "▼ Debug Log" : "▶ Debug Log"
        })
    }

    // MARK: - Input Setup

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
            self?.log("🎤 \(transcript)")
            self?.voiceStatusLabel.stringValue = "Status: 🎤 Listening... \"\(transcript)\""
        }
        voiceManager.onFinalTranscript = { [weak self] transcript in
            guard let self = self else { return }
            self.voiceManager.typeCurrentTranscript()
            self.voiceStatusLabel.stringValue = "Status: ✅ Typed"
        }
        voiceManager.onError = { [weak self] error in
            self?.log("❌ Voice Error: \(error)")
            self?.voiceStatusLabel.stringValue = "Status: ❌ Error"
        }
    }

    // MARK: - Logging

    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textView = self.textView else { return }

            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)\n"

            let attrString = NSAttributedString(string: logMessage, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor(white: 0.85, alpha: 1.0)
            ])

            textView.textStorage?.append(attrString)
            textView.scrollToEndOfDocument(nil)
        }
    }

    // MARK: - Controller Connection (JoyConSwift)

    func joyConConnected(_ controller: Controller) {
        controllers.append(controller)

        let name = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
        log("✅ Controller Connected: \(name)")

        updateConnectionDisplay()
        setupJoyConHandlers(controller)

        // Set player lights
        let playerIndex = controllers.count - 1
        switch playerIndex {
        case 0: controller.setPlayerLights(l1: .on, l2: .off, l3: .off, l4: .off)
        case 1: controller.setPlayerLights(l1: .off, l2: .on, l3: .off, l4: .off)
        default: controller.setPlayerLights(l1: .on, l2: .on, l3: .off, l4: .off)
        }
    }

    func joyConDisconnected(_ controller: Controller) {
        controllers.removeAll { $0 === controller }
        let name = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
        log("❌ Controller Disconnected: \(name)")
        updateConnectionDisplay()
    }

    private func updateConnectionDisplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.controllers.isEmpty {
                self.connectionLabel.stringValue = "🔍 No Joy-Con detected"
                self.connectionLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
                self.batteryLabel.stringValue = ""
                self.ledIndicator.stringValue = ""
            } else {
                let names = self.controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
                self.connectionLabel.stringValue = "✅ Connected: \(names.joined(separator: " + "))"
                self.connectionLabel.textColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

                // Battery (placeholder - JoyConSwift doesn't expose battery easily)
                if !self.controllers.isEmpty {
                    self.batteryLabel.stringValue = "🔋 ---%"
                }

                // LED indicator
                let count = self.controllers.count
                self.ledIndicator.stringValue = "🔵 LED \(count)"
            }
        }
    }

    // MARK: - JoyConSwift Handlers

    private func setupJoyConHandlers(_ controller: Controller) {
        log("   Setting up button handlers...")

        controller.enableIMU(enable: true)
        controller.setInputMode(mode: .standardFull)

        controller.buttonPressHandler = { [weak self] button in
            guard let self = self else { return }

            switch button {
            case .A:
                self.handleButtonA()
            case .B:
                self.handleButtonB()
            case .X:
                self.handleButtonX()
            case .Y:
                self.log("🕹️ Button Y → Enter")
                self.inputController.pressEnter(modifiers: self.modifiers)
            case .L:
                self.modifiers.command = true
                self.updateSpecialMode()
            case .R:
                self.modifiers.shift = true
                self.updateSpecialMode()
            case .ZL:
                // If ZR is not held, this is a single ZL press → Cmd+Shift+[ (previous tab)
                if !self.isZRHeld {
                    self.log("🕹️ ZL → Cmd+Shift+[ (previous tab)")
                    var mods = ModifierState()
                    mods.command = true
                    mods.shift = true
                    self.inputController.pressKey(CGKeyCode(kVK_ANSI_LeftBracket), modifiers: mods)
                }
                self.isZLHeld = true
                self.updateSpecialMode()
            case .ZR:
                // If ZL is not held, this is a single ZR press → Cmd+Shift+] (next tab)
                if !self.isZLHeld {
                    self.log("🕹️ ZR → Cmd+Shift+] (next tab)")
                    var mods = ModifierState()
                    mods.command = true
                    mods.shift = true
                    self.inputController.pressKey(CGKeyCode(kVK_ANSI_RightBracket), modifiers: mods)
                }
                self.isZRHeld = true
                self.updateSpecialMode()
            case .Up:
                self.handleDpadButton(direction: "up")
            case .Down:
                self.handleDpadButton(direction: "down")
            case .Left:
                self.handleDpadButton(direction: "left")
            case .Right:
                self.handleDpadButton(direction: "right")
            case .Minus:
                self.log("🕹️ Button Minus → Backspace")
                self.inputController.pressBackspace(modifiers: self.modifiers)
            default:
                break
            }
        }

        controller.buttonReleaseHandler = { [weak self] button in
            guard let self = self else { return }

            switch button {
            case .L:
                self.modifiers.command = false
                self.updateSpecialMode()
            case .R:
                self.modifiers.shift = false
                self.updateSpecialMode()
            case .ZL:
                self.isZLHeld = false
                self.updateSpecialMode()
            case .ZR:
                self.isZRHeld = false
                self.updateSpecialMode()
            default:
                break
            }
        }

        controller.leftStickPosHandler = { [weak self] pos in
            self?.handleLeftStick(x: Float(pos.x), y: Float(pos.y))
        }

        controller.rightStickPosHandler = { [weak self] pos in
            self?.handleRightStick(x: Float(pos.x), y: Float(pos.y))
        }

        log("   ✅ Handlers configured")
    }

    private func handleDpadButton(direction: String) {
        // New mapping: D-Pad → Number keys 1-4 for menu options
        switch direction {
        case "up":
            log("🕹️ D-Pad Up → 1 key")
            inputController.pressKey(CGKeyCode(kVK_ANSI_1), modifiers: modifiers)
        case "down":
            log("🕹️ D-Pad Down → 2 key")
            inputController.pressKey(CGKeyCode(kVK_ANSI_2), modifiers: modifiers)
        case "left":
            log("🕹️ D-Pad Left → 3 key")
            inputController.pressKey(CGKeyCode(kVK_ANSI_3), modifiers: modifiers)
        case "right":
            log("🕹️ D-Pad Right → 4 key")
            inputController.pressKey(CGKeyCode(kVK_ANSI_4), modifiers: modifiers)
        default:
            break
        }
    }

    private func handleButtonA() {
        if modifiers.command {
            log("🕹️ L+A → Cmd+Click")
            inputController.leftClick(modifiers: modifiers)
        } else {
            log("🕹️ Button A → Click")
            inputController.leftClick()
        }
    }

    private func handleButtonB() {
        if modifiers.command {
            log("🕹️ Button B + Cmd → Interrupt (Ctrl+C)")
            inputController.interruptProcess()
        } else {
            log("🕹️ Button B → Escape")
            inputController.pressEscape()
        }
    }

    private func handleButtonX() {
        // New mapping:
        // X alone → Tab
        // R + X → Shift+Tab (always/reverse)
        // L + X → Cmd+Tab (app switcher)
        // L + R + X → Cmd+Shift+Tab (reverse app switch)

        if modifiers.command && modifiers.shift {
            log("🕹️ L+R+X → Cmd+Shift+Tab (reverse app switch)")
            inputController.pressTab(modifiers: modifiers)
        } else if modifiers.command {
            log("🕹️ L+X → Cmd+Tab (app switcher)")
            inputController.pressTab(modifiers: modifiers)
        } else if modifiers.shift {
            log("🕹️ R+X → Shift+Tab (always/reverse)")
            inputController.pressTab(modifiers: modifiers)
        } else {
            log("🕹️ X → Tab")
            inputController.pressTab()
        }
    }

    private func handleLeftStick(x: Float, y: Float) {
        inputController.setMouseDelta(x: x, y: y)
    }

    private func handleRightStick(x: Float, y: Float) {
        inputController.setScrollDelta(x: x, y: y)
    }

    // MARK: - Special Mode Management

    private func updateSpecialMode() {
        let newMode: SpecialInputMode

        if isZLHeld && isZRHeld {
            newMode = .voice
        } else if modifiers.option && modifiers.shift {
            newMode = .precision
        } else {
            newMode = .none
        }

        if newMode != specialMode {
            specialMode = newMode
            handleSpecialModeChange(to: newMode)
        }
    }

    private func handleSpecialModeChange(to mode: SpecialInputMode) {
        switch mode {
        case .voice:
            log("🎤 Voice input activated - speak now")
            voiceManager.startListening()
            voiceStatusLabel.stringValue = "Status: 🎤 Listening..."

        case .precision:
            log("✨ Precision mode activated")
            inputController.setPrecisionMode(true)

        case .none:
            if specialMode == .voice {
                voiceManager.stopListening()
                if !voiceManager.currentTranscript.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.voiceManager.typeCurrentTranscript()
                    }
                }
                voiceStatusLabel.stringValue = "Status: ⏸️ Ready"
            }
            if specialMode == .precision {
                inputController.setPrecisionMode(false)
            }
        }
    }
}
