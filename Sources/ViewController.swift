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

    // Debug Controls
    #if DEBUG
    private var debugModeCheckbox: NSButton!
    #endif

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
    private var isMinusHeld: Bool = false  // For quick profile switching

    // Managers
    private let inputController = InputController.shared
    private let voiceManager = VoiceInputManager.shared
    private let settings = InputSettings.shared
    private let profileManager = ProfileManager.shared

    // Profile editing state
    private var editingProfile: ButtonProfile?  // Temporary copy during editing
    private var isProfileDirty: Bool = false    // Track unsaved changes
    private var keyCaptureWindow: NSWindow?     // Retain the key capture window

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
        #if DEBUG
        let debugSuffix = inputController.debugMode ? " [DEBUG MODE]" : ""
        #else
        let debugSuffix = ""
        #endif
        connectionLabel = NSTextField(labelWithString: "🔍 No Joy-Con detected\(debugSuffix)")
        connectionLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        connectionLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        connectionLabel.frame = NSRect(x: 20, y: 20, width: 500, height: 25)
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
        #if DEBUG
        let statusText = inputController.debugMode ?
            "⚠️ DEBUG MODE: Input events are logged but not sent to the system.\nNo accessibility permissions needed for testing." :
            "Mouse control is always active when a Joy-Con is connected.\nUse the left stick to move the cursor."
        #else
        let statusText = "Mouse control is always active when a Joy-Con is connected.\nUse the left stick to move the cursor."
        #endif
        let statusLabel = NSTextField(wrappingLabelWithString: statusText)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 20, width: frame.width - 40, height: 40)
        panel.addSubview(statusLabel)

        // Debug mode toggle (only in debug builds)
        #if DEBUG
        debugModeCheckbox = NSButton(checkboxWithTitle: "Debug Mode (skip system input events)", target: self, action: #selector(debugModeChanged(_:)))
        debugModeCheckbox.frame = NSRect(x: 20, y: y - 30, width: 300, height: 20)
        debugModeCheckbox.state = inputController.debugMode ? .on : .off
        panel.addSubview(debugModeCheckbox)
        #endif

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

        // Profile Selection
        let profileLabel = NSTextField(labelWithString: "Button Profile:")
        profileLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        profileLabel.isBezeled = false
        profileLabel.isEditable = false
        profileLabel.drawsBackground = false
        panel.addSubview(profileLabel)

        keyboardPresetPopup = NSPopUpButton(frame: NSRect(x: 130, y: y - 5, width: 200, height: 25))
        keyboardPresetPopup.addItems(withTitles: profileManager.getProfileNames())
        if let activeIndex = profileManager.getProfileNames().firstIndex(of: profileManager.activeProfile.name) {
            keyboardPresetPopup.selectItem(at: activeIndex)
        }
        keyboardPresetPopup.target = self
        keyboardPresetPopup.action = #selector(profileSelectionChanged(_:))
        panel.addSubview(keyboardPresetPopup)

        // Reset button
        let resetButton = NSButton(frame: NSRect(x: 340, y: y - 5, width: 70, height: 25))
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetProfileToDefaults(_:))
        panel.addSubview(resetButton)

        // Clone button
        let cloneButton = NSButton(frame: NSRect(x: 420, y: y - 5, width: 70, height: 25))
        cloneButton.title = "Clone"
        cloneButton.bezelStyle = .rounded
        cloneButton.target = self
        cloneButton.action = #selector(cloneProfile(_:))
        panel.addSubview(cloneButton)

        y -= 50

        // Profile description
        let descLabel = NSTextField(wrappingLabelWithString: profileManager.activeProfile.description)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: y - 20, width: frame.width - 40, height: 20)
        panel.addSubview(descLabel)
        y -= 40

        // Scrollable button mapping editor
        let scrollViewHeight: CGFloat = 180
        let scrollViewWidth: CGFloat = frame.width - 40
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: scrollViewWidth, height: scrollViewHeight))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false  // Always show for clarity
        scrollView.borderType = .bezelBorder

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: scrollViewWidth - 20, height: 420))
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.white.cgColor

        var rowY: CGFloat = 380  // Start from top

        // Helper to create button row
        let createRow: (String, ButtonAction, Int) -> Void = { buttonName, action, tag in
            // Button name label
            let nameLabel = NSTextField(labelWithString: buttonName)
            nameLabel.frame = NSRect(x: 10, y: rowY, width: 100, height: 20)
            nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            documentView.addSubview(nameLabel)

            // Current mapping label
            let mappingLabel = NSTextField(labelWithString: action.description)
            mappingLabel.frame = NSRect(x: 120, y: rowY, width: 280, height: 20)
            mappingLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            mappingLabel.textColor = NSColor.secondaryLabelColor
            documentView.addSubview(mappingLabel)

            // Edit button (positioned on right side)
            let editBtn = NSButton(frame: NSRect(x: documentView.bounds.width - 70, y: rowY - 2, width: 60, height: 22))
            editBtn.title = "✏️ Edit"
            editBtn.bezelStyle = .rounded
            editBtn.font = NSFont.systemFont(ofSize: 10)
            editBtn.tag = tag
            editBtn.target = self
            editBtn.action = #selector(self.editButtonMapping(_:))
            documentView.addSubview(editBtn)

            // Debug log
            print("📝 Created Edit button for \(buttonName) at x:\(editBtn.frame.origin.x), visible in documentView width:\(documentView.bounds.width)")

            rowY -= 25
        }

        // Face Buttons section
        let faceHeader = NSTextField(labelWithString: "▸ Face Buttons")
        faceHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        faceHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(faceHeader)
        rowY -= 25

        createRow("A Button", profileManager.activeProfile.buttonA, 1)
        createRow("B Button", profileManager.activeProfile.buttonB, 2)
        createRow("X Button", profileManager.activeProfile.buttonX, 3)
        createRow("Y Button", profileManager.activeProfile.buttonY, 4)
        rowY -= 10

        // D-Pad section
        let dpadHeader = NSTextField(labelWithString: "▸ D-Pad")
        dpadHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        dpadHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(dpadHeader)
        rowY -= 25

        createRow("Up", profileManager.activeProfile.dpadUp, 5)
        createRow("Right", profileManager.activeProfile.dpadRight, 6)
        createRow("Down", profileManager.activeProfile.dpadDown, 7)
        createRow("Left", profileManager.activeProfile.dpadLeft, 8)
        rowY -= 10

        // Triggers section
        let triggerHeader = NSTextField(labelWithString: "▸ Triggers & Bumpers")
        triggerHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        triggerHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(triggerHeader)
        rowY -= 25

        // Note: L/R bumpers are ModifierActions and handled separately
        createRow("ZL Trigger", profileManager.activeProfile.triggerZL, 11)
        createRow("ZR Trigger", profileManager.activeProfile.triggerZR, 12)
        createRow("ZL+ZR Combo", profileManager.activeProfile.triggerZLZR, 13)

        scrollView.documentView = documentView
        panel.addSubview(scrollView)

        // Status info at bottom
        let statusLabel = NSTextField(wrappingLabelWithString: "Click Edit to customize any button mapping. Changes take effect immediately.")
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 20, width: frame.width - 40, height: 30)
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

    #if DEBUG
    @objc private func debugModeChanged(_ sender: NSButton) {
        inputController.debugMode = (sender.state == .on)
        let status = inputController.debugMode ? "enabled" : "disabled"
        log("🐛 Debug mode \(status) - input events will \(inputController.debugMode ? "NOT" : "") be sent to system")

        // Update header label
        let debugSuffix = inputController.debugMode ? " [DEBUG MODE]" : ""
        if controllers.isEmpty {
            connectionLabel.stringValue = "🔍 No Joy-Con detected\(debugSuffix)"
        } else {
            let names = controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
            connectionLabel.stringValue = "✅ Connected: \(names.joined(separator: " + "))\(debugSuffix)"
        }

        // Refresh mouse config panel to update status text
        mouseConfigPanel.removeFromSuperview()
        let yPosition = mouseConfigPanel.frame.minY
        mouseConfigPanel = createMouseConfigPanel(
            frame: NSRect(x: 0, y: yPosition, width: view.bounds.width, height: 300)
        )
        mouseConfigPanel.autoresizingMask = [.width, .minYMargin]
        mouseConfigPanel.isHidden = (currentTab != .mouse)
        view.addSubview(mouseConfigPanel)
    }
    #endif

    @objc private func profileSelectionChanged(_ sender: NSPopUpButton) {
        guard let profileName = sender.titleOfSelectedItem else { return }
        profileManager.setActiveProfile(named: profileName)
        log("✅ Profile changed to: \(profileName)")

        // Refresh the keyboard config panel to show new mapping
        refreshKeyboardPanel()
    }

    private func refreshKeyboardPanel() {
        keyboardConfigPanel.removeFromSuperview()
        let yPosition = mouseConfigPanel.frame.minY
        keyboardConfigPanel = createKeyboardConfigPanel(
            frame: NSRect(x: 0, y: yPosition, width: view.bounds.width, height: 300)
        )
        keyboardConfigPanel.autoresizingMask = [.width, .minYMargin]
        keyboardConfigPanel.isHidden = (currentTab != .keyboard)
        view.addSubview(keyboardConfigPanel)
    }

    private func generateMappingText(for profile: ButtonProfile) -> String {
        return """
        A: \(profile.buttonA.description)  B: \(profile.buttonB.description)  X: \(profile.buttonX.description)  Y: \(profile.buttonY.description)
        D-Pad: ↑\(profile.dpadUp.description)  ↓\(profile.dpadDown.description)  ←\(profile.dpadLeft.description)  →\(profile.dpadRight.description)
        L: \(profile.bumperL.description)  R: \(profile.bumperR.description)
        ZL: \(profile.triggerZL.description)  ZR: \(profile.triggerZR.description)  ZL+ZR: \(profile.triggerZLZR.description)
        Minus: \(profile.buttonMinus.description)  Plus: \(profile.buttonPlus.description)
        Left Stick: \(profile.leftStickFunction.rawValue)  Right Stick: \(profile.rightStickFunction.rawValue)
        """
    }

    @objc private func resetProfileToDefaults(_ sender: NSButton) {
        let currentProfileName = profileManager.activeProfile.name

        let alert = NSAlert()
        alert.messageText = "Reset Profile to Defaults?"
        alert.informativeText = "This will reset \"\(currentProfileName)\" to its default button mappings. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            profileManager.resetProfileToDefault(named: currentProfileName)
            log("🔄 Profile \"\(currentProfileName)\" reset to defaults")
            refreshKeyboardPanel()
        }
    }

    @objc private func cloneProfile(_ sender: NSButton) {
        let currentProfileName = profileManager.activeProfile.name

        let alert = NSAlert()
        alert.messageText = "Clone Profile"
        alert.informativeText = "Enter a name for the new profile:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = "\(currentProfileName) Copy"
        inputField.placeholderString = "Profile name"
        alert.accessoryView = inputField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = inputField.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                profileManager.duplicateProfile(named: currentProfileName, newName: newName)
                log("📋 Cloned profile \"\(currentProfileName)\" to \"\(newName)\"")

                // Switch to the new profile
                profileManager.setActiveProfile(named: newName)

                // Refresh the keyboard panel to show new profile in dropdown
                refreshKeyboardPanel()
            }
        }
    }

    @objc private func editButtonMapping(_ sender: NSButton) {
        let tag = sender.tag

        // Map tag to button name and current action
        let (buttonName, currentAction) = getButtonInfo(forTag: tag)

        log("🎹 Editing \(buttonName)...")

        // Create key capture view
        let captureView = KeyCaptureView(
            buttonName: buttonName,
            currentMapping: currentAction.description
        )

        captureView.onKeyCaptured = { [weak self] capturedKey in
            self?.handleKeyCaptured(capturedKey, forTag: tag, buttonName: buttonName)
            // Close the window
            self?.keyCaptureWindow?.close()
            self?.keyCaptureWindow = nil
        }

        captureView.onCancelled = { [weak self] in
            print("Cancelled key capture")
            // Close the window
            self?.keyCaptureWindow?.close()
            self?.keyCaptureWindow = nil
        }

        // Show as a modal window
        keyCaptureWindow = NSWindow(contentViewController: NSViewController())
        keyCaptureWindow!.contentView = captureView
        keyCaptureWindow!.styleMask = [.titled, .closable]
        keyCaptureWindow!.setContentSize(NSSize(width: 400, height: 250))
        keyCaptureWindow!.title = "Capture Key for \(buttonName)"
        keyCaptureWindow!.center()
        keyCaptureWindow!.makeKeyAndOrderFront(nil)
        keyCaptureWindow!.level = .floating

        // Make the window respond to Esc key for closing
        keyCaptureWindow!.standardWindowButton(.closeButton)?.isEnabled = true
    }

    private func getButtonInfo(forTag tag: Int) -> (String, ButtonAction) {
        let profile = profileManager.activeProfile
        switch tag {
        case 1: return ("A Button", profile.buttonA)
        case 2: return ("B Button", profile.buttonB)
        case 3: return ("X Button", profile.buttonX)
        case 4: return ("Y Button", profile.buttonY)
        case 5: return ("D-Pad Up", profile.dpadUp)
        case 6: return ("D-Pad Right", profile.dpadRight)
        case 7: return ("D-Pad Down", profile.dpadDown)
        case 8: return ("D-Pad Left", profile.dpadLeft)
        case 11: return ("ZL Trigger", profile.triggerZL)
        case 12: return ("ZR Trigger", profile.triggerZR)
        case 13: return ("ZL+ZR Combo", profile.triggerZLZR)
        default: return ("Unknown", .none)
        }
    }

    private func handleKeyCaptured(_ capturedKey: CapturedKey, forTag tag: Int, buttonName: String) {
        // Convert CapturedKey to ButtonAction
        let newAction = ButtonAction.keyCombo(
            keyCode: capturedKey.keyCode,
            command: capturedKey.modifiers.contains(.command),
            shift: capturedKey.modifiers.contains(.shift),
            option: capturedKey.modifiers.contains(.option),
            control: capturedKey.modifiers.contains(.control),
            description: capturedKey.description
        )

        // Update the profile on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.updateButtonAction(forTag: tag, newAction: newAction)
            self.log("✅ Updated \(buttonName) → \(newAction.description)")

            // Refresh the keyboard panel to show new mapping
            self.refreshKeyboardPanel()
        }
    }

    private func updateButtonAction(forTag tag: Int, newAction: ButtonAction) {
        // Get mutable copy of active profile
        var updatedProfile = profileManager.activeProfile

        // Update the specific button based on tag
        switch tag {
        case 1: updatedProfile.buttonA = newAction
        case 2: updatedProfile.buttonB = newAction
        case 3: updatedProfile.buttonX = newAction
        case 4: updatedProfile.buttonY = newAction
        case 5: updatedProfile.dpadUp = newAction
        case 6: updatedProfile.dpadRight = newAction
        case 7: updatedProfile.dpadDown = newAction
        case 8: updatedProfile.dpadLeft = newAction
        case 11: updatedProfile.triggerZL = newAction
        case 12: updatedProfile.triggerZR = newAction
        case 13: updatedProfile.triggerZLZR = newAction
        default: break
        }

        // Save back to profile manager
        profileManager.updateProfile(updatedProfile)
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
                self.handleButtonY()
            case .L:
                self.applyModifier(self.profileManager.activeProfile.bumperL)
                self.updateSpecialMode()
            case .R:
                self.applyModifier(self.profileManager.activeProfile.bumperR)
                self.updateSpecialMode()
            case .ZL:
                // If ZR is not held, execute single ZL action
                if !self.isZRHeld {
                    self.executeButtonAction(self.profileManager.activeProfile.triggerZL, buttonName: "ZL")
                }
                self.isZLHeld = true
                self.updateSpecialMode()
            case .ZR:
                // If ZL is not held, execute single ZR action
                if !self.isZLHeld {
                    self.executeButtonAction(self.profileManager.activeProfile.triggerZR, buttonName: "ZR")
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
                self.isMinusHeld = true
                self.executeButtonAction(self.profileManager.activeProfile.buttonMinus, buttonName: "Minus")
            case .Plus:
                self.executeButtonAction(self.profileManager.activeProfile.buttonPlus, buttonName: "Plus")
            default:
                break
            }
        }

        controller.buttonReleaseHandler = { [weak self] button in
            guard let self = self else { return }

            switch button {
            case .L:
                self.removeModifier(self.profileManager.activeProfile.bumperL)
                self.updateSpecialMode()
            case .R:
                self.removeModifier(self.profileManager.activeProfile.bumperR)
                self.updateSpecialMode()
            case .ZL:
                self.isZLHeld = false
                self.updateSpecialMode()
            case .ZR:
                self.isZRHeld = false
                self.updateSpecialMode()
            case .Minus:
                self.isMinusHeld = false
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

    // MARK: - Profile-based Button Execution

    private func applyModifier(_ modifier: ModifierAction) {
        switch modifier {
        case .command: modifiers.command = true
        case .option: modifiers.option = true
        case .shift: modifiers.shift = true
        case .control: modifiers.control = true
        case .none: break
        }
    }

    private func removeModifier(_ modifier: ModifierAction) {
        switch modifier {
        case .command: modifiers.command = false
        case .option: modifiers.option = false
        case .shift: modifiers.shift = false
        case .control: modifiers.control = false
        case .none: break
        }
    }

    private func executeButtonAction(_ action: ButtonAction, buttonName: String) {
        switch action {
        case .mouseClick:
            log("🕹️ \(buttonName) → Click")
            inputController.leftClick(modifiers: modifiers)
        case .rightClick:
            log("🕹️ \(buttonName) → Right Click")
            inputController.rightClick()
        case .pressKey(let keyCode, let requiresShift):
            var mods = modifiers
            if requiresShift {
                mods.shift = true
                mods.command = true
            }
            log("🕹️ \(buttonName) → Key(\(keyCode))")
            inputController.pressKey(CGKeyCode(keyCode), modifiers: mods)
        case .pressEnter:
            log("🕹️ \(buttonName) → Enter")
            inputController.pressEnter(modifiers: modifiers)
        case .pressEscape:
            log("🕹️ \(buttonName) → Escape")
            inputController.pressEscape()
        case .pressTab:
            log("🕹️ \(buttonName) → Tab")
            inputController.pressTab(modifiers: modifiers)
        case .pressSpace:
            log("🕹️ \(buttonName) → Space")
            inputController.pressSpace(modifiers: modifiers)
        case .pressBackspace:
            log("🕹️ \(buttonName) → Backspace")
            inputController.pressBackspace(modifiers: modifiers)
        case .customKey(let keyCode, let desc):
            log("🕹️ \(buttonName) → \(desc)")
            inputController.pressKey(CGKeyCode(keyCode), modifiers: modifiers)
        case .keyCombo(let keyCode, let cmd, let shift, let opt, let ctrl, let desc):
            log("🕹️ \(buttonName) → \(desc)")
            inputController.pressKeyCombo(keyCode: keyCode, command: cmd, shift: shift, option: opt, control: ctrl)
        case .voiceInput:
            log("🕹️ \(buttonName) → Voice Input")
            // Voice input is handled separately through ZL+ZR combo
            break
        case .none:
            break
        }
    }

    private func handleDpadButton(direction: String) {
        // Check for quick profile switch: Minus + D-Pad
        if isMinusHeld {
            let profileIndex: Int
            switch direction {
            case "up": profileIndex = 0      // Desktop+Terminal
            case "right": profileIndex = 1   // Gaming
            case "down": profileIndex = 2    // Media
            case "left": profileIndex = 3    // Classic
            default: return
            }

            profileManager.switchToProfileAtIndex(profileIndex)
            log("🎮 Quick Switch → Profile \(profileIndex): \(profileManager.activeProfile.name)")

            // Show profile overlay with cheat sheet
            ProfileOverlay.show(profile: profileManager.activeProfile)

            // Refresh keyboard panel if on keyboard tab
            if currentTab == .keyboard {
                refreshKeyboardPanel()
            }

            return
        }

        // Normal D-Pad behavior
        let profile = profileManager.activeProfile
        switch direction {
        case "up": executeButtonAction(profile.dpadUp, buttonName: "D-Pad Up")
        case "down": executeButtonAction(profile.dpadDown, buttonName: "D-Pad Down")
        case "left": executeButtonAction(profile.dpadLeft, buttonName: "D-Pad Left")
        case "right": executeButtonAction(profile.dpadRight, buttonName: "D-Pad Right")
        default: break
        }
    }

    private func handleButtonA() {
        let profile = profileManager.activeProfile
        // Handle L+A → Cmd+Click combo if enabled in profile
        if modifiers.command && profile.enableCmdClick {
            log("🕹️ L+A → Cmd+Click")
            inputController.leftClick(modifiers: modifiers)
        } else {
            executeButtonAction(profile.buttonA, buttonName: "A")
        }
    }

    private func handleButtonB() {
        executeButtonAction(profileManager.activeProfile.buttonB, buttonName: "B")
    }

    private func handleButtonX() {
        let profile = profileManager.activeProfile

        // Handle smart tabbing if enabled in profile
        if profile.enableSmartTabbing {
            if modifiers.command && modifiers.shift {
                log("🕹️ L+R+X → Cmd+Shift+Tab")
                inputController.pressTab(modifiers: modifiers)
            } else if modifiers.command {
                log("🕹️ L+X → Cmd+Tab")
                inputController.pressTab(modifiers: modifiers)
            } else if modifiers.shift {
                log("🕹️ R+X → Shift+Tab")
                inputController.pressTab(modifiers: modifiers)
            } else {
                executeButtonAction(profile.buttonX, buttonName: "X")
            }
        } else {
            executeButtonAction(profile.buttonX, buttonName: "X")
        }
    }

    private func handleButtonY() {
        executeButtonAction(profileManager.activeProfile.buttonY, buttonName: "Y")
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
