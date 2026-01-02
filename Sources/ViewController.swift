import Cocoa
import JoyConSwift
import Carbon.HIToolbox

// FlippedView: Custom view with flipped coordinates (y=0 at top)
class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

enum ControlModeTab: String {
    case mouse = "Mouse"
    case keyboard = "Keyboard"
    case voice = "Voice"
}

class ViewController: NSViewController, NSTabViewDelegate {
    // MARK: - UI Components

    // Header
    private var connectionLabel: NSTextField!
    private var batteryLabel: NSTextField!
    private var ledIndicator: NSTextField!
    private var helpButton: NSButton!

    // Layout containers
    private var mainStackView: NSStackView!
    private var contentSplitView: NSSplitView!

    // Mode Tabs - Using native NSTabView
    private var tabView: NSTabView!
    private var mouseTabViewItem: NSTabViewItem!
    private var keyboardTabViewItem: NSTabViewItem!
    private var voiceTabViewItem: NSTabViewItem!

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
    private var voiceLanguagePopup: NSPopUpButton!

    // Bottom Bar & Debug Log
    private var debugLogButton: NSButton!
    private var debugLogContainer: NSView!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var isDebugLogExpanded: Bool = false
    private var hasPerformedInitialLayout: Bool = false

    // MARK: - Controllers & State

    var controllers: [Controller] = []
    private var currentMode: ControlMode = .unified
    private var specialMode: SpecialInputMode = .none
    private var modifiers = ModifierState()
    private var isZLHeld: Bool = false
    private var isZRHeld: Bool = false
    private var isMinusHeld: Bool = false  // For quick profile switching

    // Track if shoulder buttons were used in a chord (to suppress individual actions)
    private var wasZLInChord: Bool = false
    private var wasZRInChord: Bool = false

    // Managers
    private let inputController = InputController.shared
    private let voiceManager = VoiceInputManager.shared
    private let settings = InputSettings.shared
    private let profileManager = ProfileManager.shared

    // Profile editing state
    private var editingProfile: ButtonProfile?  // Temporary copy during editing
    private var isProfileDirty: Bool = false    // Track unsaved changes
    private var keyCaptureWindow: NSWindow?     // Retain the key capture window

    // Drift logging state
    private var previousLeftStick: (x: Float, y: Float)?
    private var previousRightStick: (x: Float, y: Float)?
    private var anyButtonPressed: Bool = false  // Track if any button is currently pressed
    private var isPlusHeldForDriftMarking: Bool = false  // Track if Plus is held to mark drift

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInputController()
        setupVoiceManager()
        log("🫐 berrry-joyful initialized - waiting for controllers...")
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Set initial split position after layout (only once)
        if !hasPerformedInitialLayout && contentSplitView.bounds.height > 0 {
            hasPerformedInitialLayout = true
            let splitHeight = contentSplitView.bounds.height

            if isDebugLogExpanded {
                // Start with debug log visible at 200px
                let dividerPosition = splitHeight - 200
                contentSplitView.setPosition(dividerPosition, ofDividerAt: 0)
                debugLogContainer.isHidden = false
            } else {
                // Start collapsed
                contentSplitView.setPosition(splitHeight - 1, ofDividerAt: 0)
                debugLogContainer.isHidden = true
            }
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Create main vertical stack view
        mainStackView = NSStackView(frame: view.bounds)
        mainStackView.orientation = .vertical
        mainStackView.spacing = 0
        mainStackView.distribution = .fill
        mainStackView.autoresizingMask = [.width, .height]

        // Create header (fixed height)
        let headerView = createHeaderView()

        // Create split view for tab view + debug log
        contentSplitView = NSSplitView()
        contentSplitView.isVertical = false  // Horizontal split
        contentSplitView.dividerStyle = .thin

        // Create tab view
        createTabView()

        // Create debug log container
        createDebugLogView()

        // Add to split view
        contentSplitView.addArrangedSubview(tabView)
        contentSplitView.addArrangedSubview(debugLogContainer)

        // Set holding priorities so tab view can shrink but debug log stays at preferred size
        contentSplitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)  // Tab view
        contentSplitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)  // Debug log

        // Add all to main stack (no bottom bar - merged into header)
        mainStackView.addArrangedSubview(headerView)
        mainStackView.addArrangedSubview(contentSplitView)

        // Set hugging priorities so header stays fixed size
        headerView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentSplitView.setContentHuggingPriority(.defaultLow, for: .vertical)

        view.addSubview(mainStackView)
    }

    private func createHeaderView() -> NSView {
        let headerHeight: CGFloat = 50
        let headerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: headerHeight))
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        headerView.heightAnchor.constraint(equalToConstant: headerHeight).isActive = true

        // Connection status (left side)
        #if DEBUG
        let debugSuffix = inputController.debugMode ? " [DEBUG MODE]" : ""
        #else
        let debugSuffix = ""
        #endif
        connectionLabel = NSTextField(labelWithString: "🔍 No Joy-Con detected\(debugSuffix)")
        connectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        connectionLabel.textColor = NSColor.secondaryLabelColor
        connectionLabel.frame = NSRect(x: 20, y: 15, width: 350, height: 20)
        headerView.addSubview(connectionLabel)

        // Help button (only shown when no controller connected)
        helpButton = NSButton(frame: NSRect(x: 380, y: 13, width: 80, height: 24))
        helpButton.title = "Need Help?"
        helpButton.bezelStyle = .rounded
        helpButton.target = self
        helpButton.action = #selector(showConnectionHelp)
        helpButton.autoresizingMask = [.minXMargin]
        helpButton.isHidden = true  // Hidden by default, shown when no controller
        headerView.addSubview(helpButton)

        // Battery indicator (right side)
        batteryLabel = NSTextField(labelWithString: "")
        batteryLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        batteryLabel.textColor = NSColor.tertiaryLabelColor
        batteryLabel.alignment = .right
        batteryLabel.frame = NSRect(x: 490, y: 17, width: 70, height: 16)
        batteryLabel.autoresizingMask = [.minXMargin]
        headerView.addSubview(batteryLabel)

        // LED indicator
        ledIndicator = NSTextField(labelWithString: "")
        ledIndicator.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        ledIndicator.textColor = NSColor.tertiaryLabelColor
        ledIndicator.alignment = .right
        ledIndicator.frame = NSRect(x: 570, y: 17, width: 50, height: 16)
        ledIndicator.autoresizingMask = [.minXMargin]
        headerView.addSubview(ledIndicator)

        // Debug Log button (right side)
        debugLogButton = NSButton(frame: NSRect(x: 640, y: 10, width: 140, height: 30))
        debugLogButton.title = "▶ Debug Log"  // Start collapsed
        debugLogButton.bezelStyle = .rounded
        debugLogButton.target = self
        debugLogButton.action = #selector(toggleDebugLog(_:))
        debugLogButton.autoresizingMask = [.minXMargin]
        headerView.addSubview(debugLogButton)

        return headerView
    }

    private func createTabView() {
        // Create NSTabView
        tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        tabView.tabViewType = .topTabsBezelBorder

        // Use tab view bounds for initial sizing - autoresizing will handle the rest
        let panelFrame = tabView.bounds

        // Create Mouse tab
        mouseTabViewItem = NSTabViewItem(identifier: "mouse")
        mouseTabViewItem.label = "Mouse"
        mouseTabViewItem.view = createMouseConfigPanel(frame: panelFrame)
        tabView.addTabViewItem(mouseTabViewItem)

        // Create Keyboard tab
        keyboardTabViewItem = NSTabViewItem(identifier: "keyboard")
        keyboardTabViewItem.label = "Keyboard"
        keyboardTabViewItem.view = createKeyboardConfigPanel(frame: panelFrame)
        tabView.addTabViewItem(keyboardTabViewItem)

        // Create Voice tab
        voiceTabViewItem = NSTabViewItem(identifier: "voice")
        voiceTabViewItem.label = "Voice"
        voiceTabViewItem.view = createVoiceConfigPanel(frame: panelFrame)
        tabView.addTabViewItem(voiceTabViewItem)

        // Log tab switch
        tabView.delegate = self
    }

    private func createMouseConfigPanel(frame: NSRect) -> NSView {
        // Use flipped view so y=0 is at top
        let panel = FlippedView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = 20  // Start from top

        // Title
        let titleLabel = NSTextField(labelWithString: "Mouse Control Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y += 35

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
        y += 30

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
        y += 30

        // Checkboxes
        invertYCheckbox = NSButton(checkboxWithTitle: "Invert Y-Axis", target: self, action: #selector(invertYChanged(_:)))
        invertYCheckbox.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        invertYCheckbox.state = settings.invertY ? .on : .off
        panel.addSubview(invertYCheckbox)

        accelerationCheckbox = NSButton(checkboxWithTitle: "Acceleration", target: self, action: #selector(accelerationChanged(_:)))
        accelerationCheckbox.frame = NSRect(x: 200, y: y, width: 150, height: 20)
        accelerationCheckbox.state = settings.mouseAcceleration ? .on : .off
        panel.addSubview(accelerationCheckbox)
        y += 30

        // Debug mode toggle (only in debug builds)
        #if DEBUG
        debugModeCheckbox = NSButton(checkboxWithTitle: "Debug Mode (skip system input events)", target: self, action: #selector(debugModeChanged(_:)))
        debugModeCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        debugModeCheckbox.state = inputController.debugMode ? .on : .off
        panel.addSubview(debugModeCheckbox)
        y += 30
        #endif

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
        statusLabel.frame = NSRect(x: 20, y: y, width: frame.width - 40, height: 60)
        panel.addSubview(statusLabel)

        return panel
    }

    private func createKeyboardConfigPanel(frame: NSRect) -> NSView {
        // Use flipped view so y=0 is at top
        let panel = FlippedView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = 20  // Start from top

        // Title
        let titleLabel = NSTextField(labelWithString: "Keyboard Layout & Mapping")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y += 35

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
        resetButton.autoresizingMask = [.minXMargin]
        panel.addSubview(resetButton)

        // Clone button
        let cloneButton = NSButton(frame: NSRect(x: 420, y: y - 5, width: 70, height: 25))
        cloneButton.title = "Clone"
        cloneButton.bezelStyle = .rounded
        cloneButton.target = self
        cloneButton.action = #selector(cloneProfile(_:))
        cloneButton.autoresizingMask = [.minXMargin]
        panel.addSubview(cloneButton)

        y += 30

        // Profile description
        let descLabel = NSTextField(wrappingLabelWithString: profileManager.activeProfile.description)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: y, width: frame.width - 40, height: 20)
        descLabel.autoresizingMask = [.width]
        panel.addSubview(descLabel)
        y += 30

        // Scrollable button mapping editor
        let scrollViewHeight: CGFloat = 250
        let scrollViewWidth: CGFloat = frame.width - 40
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: y, width: scrollViewWidth, height: scrollViewHeight))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false  // Always show for clarity
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]  // Resize with window

        // Use FlippedView for top-down coordinates (will set final height after adding content)
        let documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: scrollViewWidth - 20, height: 500))
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.white.cgColor
        documentView.autoresizingMask = [.width]  // Resize width with scroll view

        var rowY: CGFloat = 10  // Start from top

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
            editBtn.autoresizingMask = [.minXMargin]  // Keep on right when resizing
            documentView.addSubview(editBtn)

            // Debug log
            self.log("📝 Created Edit button for \(buttonName) at x:\(editBtn.frame.origin.x), visible in documentView width:\(documentView.bounds.width)")

            rowY += 25  // Move down for next row
        }

        // Face Buttons section
        let faceHeader = NSTextField(labelWithString: "▸ Face Buttons")
        faceHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        faceHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(faceHeader)
        rowY += 25

        createRow("A Button", profileManager.activeProfile.buttonA, 1)
        createRow("B Button", profileManager.activeProfile.buttonB, 2)
        createRow("X Button", profileManager.activeProfile.buttonX, 3)
        createRow("Y Button", profileManager.activeProfile.buttonY, 4)
        rowY += 10

        // D-Pad section
        let dpadHeader = NSTextField(labelWithString: "▸ D-Pad")
        dpadHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        dpadHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(dpadHeader)
        rowY += 25

        createRow("Up", profileManager.activeProfile.dpadUp, 5)
        createRow("Right", profileManager.activeProfile.dpadRight, 6)
        createRow("Down", profileManager.activeProfile.dpadDown, 7)
        createRow("Left", profileManager.activeProfile.dpadLeft, 8)
        rowY += 10

        // Triggers section
        let triggerHeader = NSTextField(labelWithString: "▸ Triggers & Bumpers")
        triggerHeader.frame = NSRect(x: 5, y: rowY, width: 200, height: 20)
        triggerHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        documentView.addSubview(triggerHeader)
        rowY += 25

        // Note: L/R bumpers are ModifierActions and handled separately
        createRow("ZL Trigger", profileManager.activeProfile.triggerZL, 11)
        createRow("ZR Trigger", profileManager.activeProfile.triggerZR, 12)
        createRow("ZL+ZR Combo", profileManager.activeProfile.triggerZLZR, 13)

        // Set final documentView height based on actual content
        let finalHeight = rowY + 20  // Add padding at bottom
        documentView.frame = NSRect(x: 0, y: 0, width: scrollViewWidth - 20, height: finalHeight)

        scrollView.documentView = documentView
        panel.addSubview(scrollView)

        return panel
    }

    private func createVoiceConfigPanel(frame: NSRect) -> NSView {
        // Use flipped view so y=0 is at top
        let panel = FlippedView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = 20  // Start from top

        // Title
        let titleLabel = NSTextField(labelWithString: "Voice Input Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 25)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        panel.addSubview(titleLabel)
        y += 35

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
        y += 35

        // Language Selection
        let languageLabel = NSTextField(labelWithString: "Recognition Language:")
        languageLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        languageLabel.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        languageLabel.isBezeled = false
        languageLabel.isEditable = false
        languageLabel.drawsBackground = false
        panel.addSubview(languageLabel)

        voiceLanguagePopup = NSPopUpButton(frame: NSRect(x: 180, y: y - 2, width: 250, height: 24))
        voiceLanguagePopup.addItems(withTitles: [
            "English (US)",
            "English (UK)",
            "English (Australia)",
            "Spanish",
            "French",
            "German",
            "Italian",
            "Japanese",
            "Chinese (Simplified)",
            "Chinese (Traditional)",
            "Korean",
            "Portuguese",
            "Russian",
            "Arabic"
        ])

        // Select current language
        let languageCodes = [
            "en-US", "en-GB", "en-AU", "es-ES", "fr-FR", "de-DE", "it-IT",
            "ja-JP", "zh-CN", "zh-TW", "ko-KR", "pt-PT", "ru-RU", "ar-SA"
        ]
        if let savedIndex = languageCodes.firstIndex(of: settings.voiceLanguage) {
            voiceLanguagePopup.selectItem(at: savedIndex)
        }

        voiceLanguagePopup.target = self
        voiceLanguagePopup.action = #selector(languageChanged)
        panel.addSubview(voiceLanguagePopup)
        y += 35

        // Status
        voiceStatusLabel = NSTextField(labelWithString: "Status: ⏸️ Ready")
        voiceStatusLabel.font = NSFont.systemFont(ofSize: 13)
        voiceStatusLabel.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        voiceStatusLabel.isBezeled = false
        voiceStatusLabel.isEditable = false
        voiceStatusLabel.drawsBackground = false
        panel.addSubview(voiceStatusLabel)
        y += 40

        // How to use
        let howToLabel = NSTextField(labelWithString: "How to Use:")
        howToLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        howToLabel.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        howToLabel.isBezeled = false
        howToLabel.isEditable = false
        howToLabel.drawsBackground = false
        panel.addSubview(howToLabel)
        y += 25

        // Instructions
        let instructionsLabel = NSTextField(wrappingLabelWithString: "1. Hold ZL + ZR on your Joy-Con to activate voice input\n2. Speak naturally in your selected language\n3. Release ZL + ZR to type your words automatically")
        instructionsLabel.font = NSFont.systemFont(ofSize: 11)
        instructionsLabel.textColor = NSColor.secondaryLabelColor
        instructionsLabel.frame = NSRect(x: 20, y: y, width: frame.width - 40, height: 60)
        panel.addSubview(instructionsLabel)
        y += 70

        // Info text
        let infoLabel = NSTextField(wrappingLabelWithString: "Voice input converts your speech to text and types it automatically. Perfect for hands-free typing!")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.tertiaryLabelColor
        infoLabel.alignment = .center
        infoLabel.frame = NSRect(x: 20, y: y, width: frame.width - 40, height: 30)
        panel.addSubview(infoLabel)

        return panel
    }


    private func createDebugLogView() {
        // Debug log container
        debugLogContainer = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))

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
    }

    // MARK: - UI Actions & Delegates

    // NSTabViewDelegate
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let identifier = tabViewItem?.identifier as? String else { return }
        log("Switched to \(identifier.capitalized) tab")
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
        let newMouseView = createMouseConfigPanel(
            frame: NSRect(x: 0, y: 0, width: view.bounds.width - 20, height: 300)
        )
        mouseTabViewItem.view = newMouseView
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
        // Recreate the keyboard tab content
        let newKeyboardView = createKeyboardConfigPanel(
            frame: NSRect(x: 0, y: 0, width: view.bounds.width - 20, height: 300)
        )
        keyboardTabViewItem.view = newKeyboardView
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
            self?.log("⌨️ Cancelled key capture")
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
                    guard let self = self else { return }
                    let newVoiceView = self.createVoiceConfigPanel(
                        frame: NSRect(x: 0, y: 0, width: self.view.bounds.width - 20, height: 300)
                    )
                    self.voiceTabViewItem.view = newVoiceView
                } else {
                    self?.log("❌ Voice input permissions denied")
                }
            }
        }
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let languageCodes = [
            "en-US", "en-GB", "en-AU", "es-ES", "fr-FR", "de-DE", "it-IT",
            "ja-JP", "zh-CN", "zh-TW", "ko-KR", "pt-PT", "ru-RU", "ar-SA"
        ]

        let selectedIndex = sender.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < languageCodes.count {
            let languageCode = languageCodes[selectedIndex]
            voiceManager.setLanguage(languageCode)
            settings.voiceLanguage = languageCode
            settings.saveToUserDefaults()
            log("🌍 Voice language changed to: \(sender.titleOfSelectedItem ?? languageCode)")
        }
    }

    @objc private func toggleDebugLog(_ sender: NSButton) {
        isDebugLogExpanded = !isDebugLogExpanded

        log("🐛 Debug Log toggle - expanding: \(isDebugLogExpanded)")
        log("🐛 Split view height: \(contentSplitView.bounds.height)")

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true

            if self.isDebugLogExpanded {
                // Expand: show debug log at 200px height
                let splitHeight = self.contentSplitView.bounds.height
                let dividerPosition = splitHeight - 200
                self.log("🐛 Expanding to position: \(dividerPosition)")
                self.contentSplitView.setPosition(dividerPosition, ofDividerAt: 0)
                self.debugLogButton.title = "▼ Debug Log"
                self.debugLogContainer.isHidden = false
            } else {
                // Collapse: hide debug log (position at max)
                let splitHeight = self.contentSplitView.bounds.height
                let collapsePosition = splitHeight - 1
                self.log("🐛 Collapsing to position: \(collapsePosition)")
                self.contentSplitView.setPosition(collapsePosition, ofDividerAt: 0)  // -1 to avoid divider
                self.debugLogButton.title = "▶ Debug Log"
                self.debugLogContainer.isHidden = true
            }
        }, completionHandler: nil)
    }

    @objc private func showConnectionHelp() {
        let alert = NSAlert()
        alert.messageText = "🎮 How to Connect Joy-Con Controllers"
        alert.informativeText = """
        1. Open System Settings → Bluetooth

        2. Put Joy-Con in pairing mode:
           • Hold the small sync button (on the rail)
           • LED will start flashing

        3. Click Connect when Joy-Con appears in Bluetooth list

        4. Return to berrry-joyful - controller will be detected automatically

        Supported Controllers:
        • Joy-Con (L) - Left controller
        • Joy-Con (R) - Right controller
        • Nintendo Pro Controller

        Note: Both Joy-Cons can be connected simultaneously for full control.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Bluetooth Settings")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Open Bluetooth preferences
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Input Setup

    private func setupInputController() {
        inputController.onLog = { [weak self] message in
            self?.log(message)
        }
        inputController.startMouseUpdates()
    }

    private func setupVoiceManager() {
        // The VoiceInputManager now initializes its own authorization state.
        // We just log the status on startup.
        if voiceManager.isAuthorized {
            log("🎤 Voice permissions already granted")
        } else {
            log("⚠️ Voice permissions not yet granted")
        }

        voiceManager.onLog = { [weak self] message in
            self?.log(message)
        }
        voiceManager.onTranscriptUpdate = { [weak self] transcript in
            self?.log("🎤 \(transcript)")
            self?.voiceStatusLabel.stringValue = "Status: 🎤 Listening... \"\(transcript)\""
        }
        voiceManager.onFinalTranscript = { [weak self] transcript in
            guard let self = self, !transcript.isEmpty else { return }
            self.log("⌨️ Typing final transcript: \(transcript)")
            InputController.shared.typeText(transcript)
            // Add space after voice input for easier continuous typing
            InputController.shared.typeText(" ")
            self.voiceStatusLabel.stringValue = "Status: ✅ Typed"
        }
        voiceManager.onError = { [weak self] error in
            self?.log("❌ Voice Error: \(error)")
            self?.voiceStatusLabel.stringValue = "Status: ❌ Error"
        }
    }

    // MARK: - Logging

    func log(_ message: String) {
        // Log to console (stdout)
        NSLog(message)

        // Log to UI
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

            #if DEBUG
            let debugSuffix = self.inputController.debugMode ? " [DEBUG MODE]" : ""
            #else
            let debugSuffix = ""
            #endif

            if self.controllers.isEmpty {
                self.connectionLabel.stringValue = "🔍 No Joy-Con detected\(debugSuffix)"
                self.connectionLabel.textColor = NSColor.secondaryLabelColor
                self.batteryLabel.stringValue = ""
                self.ledIndicator.stringValue = ""
                self.helpButton?.isHidden = false  // Show help button when no controller
            } else {
                let names = self.controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
                self.connectionLabel.stringValue = "✅ Connected: \(names.joined(separator: " + "))\(debugSuffix)"
                self.connectionLabel.textColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

                // Battery (placeholder - JoyConSwift doesn't expose battery easily)
                if !self.controllers.isEmpty {
                    self.batteryLabel.stringValue = "🔋 ---%"
                }

                // LED indicator
                let count = self.controllers.count
                self.ledIndicator.stringValue = "🔵 LED \(count)"
                self.helpButton?.isHidden = true  // Hide help button when connected
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

            // Track button state for drift logging
            self.anyButtonPressed = true

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
                // Mark as held
                self.isZLHeld = true
                // Check if this will form a chord with ZR
                if self.isZRHeld {
                    self.wasZLInChord = true
                    self.wasZRInChord = true
                }
                self.updateSpecialMode()
            case .ZR:
                // Mark as held
                self.isZRHeld = true
                // Check if this will form a chord with ZL
                if self.isZLHeld {
                    self.wasZLInChord = true
                    self.wasZRInChord = true
                }
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
                // Check if drift logging is active - if so, start marking drift while held
                if DriftLogger.shared.loggingEnabled {
                    self.isPlusHeldForDriftMarking = true
                    self.log("🚩 Marking drift (hold Plus)...")
                } else {
                    self.executeButtonAction(self.profileManager.activeProfile.buttonPlus, buttonName: "Plus")
                }
            default:
                break
            }
        }

        controller.buttonReleaseHandler = { [weak self] button in
            guard let self = self else { return }

            switch button {
            case .L:
                // L and R can participate in chords, so execute action on release
                self.removeModifier(self.profileManager.activeProfile.bumperL)
                self.updateSpecialMode()
            case .R:
                // L and R can participate in chords, so execute action on release
                self.removeModifier(self.profileManager.activeProfile.bumperR)
                self.updateSpecialMode()
            case .ZL:
                // Execute ZL action only if it was NOT used in a chord
                if !self.wasZLInChord {
                    self.executeButtonAction(self.profileManager.activeProfile.triggerZL, buttonName: "ZL")
                }
                self.isZLHeld = false
                self.wasZLInChord = false  // Reset chord tracking
                self.updateSpecialMode()
            case .ZR:
                // Execute ZR action only if it was NOT used in a chord
                if !self.wasZRInChord {
                    self.executeButtonAction(self.profileManager.activeProfile.triggerZR, buttonName: "ZR")
                }
                self.isZRHeld = false
                self.wasZRInChord = false  // Reset chord tracking
                self.updateSpecialMode()
            case .Minus:
                self.isMinusHeld = false
            case .Plus:
                // Stop marking drift when Plus is released
                if self.isPlusHeldForDriftMarking {
                    self.isPlusHeldForDriftMarking = false
                    self.log("🚩 Drift marking stopped")
                }
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
            if tabView.selectedTabViewItem === keyboardTabViewItem {
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

        // Log drift data for left stick
        logStickDrift(x: x, y: y, stickName: "LeftStick", previous: previousLeftStick)
        previousLeftStick = (x, y)
    }

    private func handleRightStick(x: Float, y: Float) {
        inputController.setScrollDelta(x: x, y: y)

        // Log drift data for right stick
        logStickDrift(x: x, y: y, stickName: "RightStick", previous: previousRightStick)
        previousRightStick = (x, y)
    }

    private func logStickDrift(x: Float, y: Float, stickName: String, previous: (x: Float, y: Float)?) {
        guard DriftLogger.shared.loggingEnabled else { return }

        // Determine if stick is idle (close to neutral position)
        let magnitude = sqrt(x * x + y * y)
        let isIdle = magnitude < 0.1  // Small threshold for idle detection

        // Get controller ID (use first controller or "unknown")
        let controllerId: String
        if let firstController = controllers.first {
            let objectId = ObjectIdentifier(firstController)
            controllerId = "\(firstController.type)-\(objectId)"
        } else {
            controllerId = "unknown"
        }

        // Get current mode
        let currentMode: String
        if specialMode == .voice {
            currentMode = "voice"
        } else if specialMode == .precision {
            currentMode = "precision"
        } else {
            currentMode = "unified"
        }

        // Create sample
        let sample = DriftLogger.StickSample(
            x: x,
            y: y,
            controllerId: "\(controllerId)-\(stickName)",
            isIdle: isIdle,
            buttonsPressed: anyButtonPressed ? 1 : 0,
            currentMode: currentMode,
            previousSample: previous,
            userMarkedDrift: isPlusHeldForDriftMarking  // Mark drift while Plus button is held
        )

        DriftLogger.shared.logSample(sample)
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

        log("🔘 ZL:\(isZLHeld) ZR:\(isZRHeld) → mode:\(newMode) (was:\(specialMode))")

        if newMode != specialMode {
            let oldMode = specialMode
            specialMode = newMode
            handleSpecialModeChange(from: oldMode, to: newMode)
        }
    }

    private func handleSpecialModeChange(from oldMode: SpecialInputMode, to newMode: SpecialInputMode) {
        switch newMode {
        case .voice:
            log("🎤 Voice input activated - speak now")
            voiceManager.startListening()
            voiceStatusLabel.stringValue = "Status: 🎤 Listening..."

        case .precision:
            log("✨ Precision mode activated")
            inputController.setPrecisionMode(true)

        case .none:
            if oldMode == .voice {
                log("🎤 Voice mode ending - waiting for final transcript...")
                // Just tell the manager to stop. The finalization and typing
                // will happen automatically via the onFinalTranscript callback.
                voiceManager.stopListening()
                voiceStatusLabel.stringValue = "Status: Processing..."
            }
            if oldMode == .precision {
                inputController.setPrecisionMode(false)
            }
        }
    }
}
