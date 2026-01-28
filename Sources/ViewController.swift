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
    private var batteryProgressView: NSView!  // Container for battery progress bars
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
    private var scrollSensitivitySlider: NSSlider!
    private var scrollSensitivityLabel: NSTextField!
    private var leftDeadzoneSlider: NSSlider!
    private var leftDeadzoneLabel: NSTextField!
    private var rightDeadzoneSlider: NSSlider!
    private var rightDeadzoneLabel: NSTextField!
    private var invertYCheckbox: NSButton!
    private var accelerationCheckbox: NSButton!
    private var leftStickFunctionPopup: NSPopUpButton!
    private var rightStickFunctionPopup: NSPopUpButton!

    // Sticky Mouse Controls
    private var stickyMouseCheckbox: NSButton!
    private var stickyStrengthPopup: NSPopUpButton!
    private var stickyOverlayCheckbox: NSButton!

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: DesignSystem.Layout.defaultWindowWidth, height: DesignSystem.Layout.defaultWindowHeight))
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
                let dividerPosition = max(splitHeight - 200, 100)
                contentSplitView.setPosition(dividerPosition, ofDividerAt: 0)
                debugLogContainer.isHidden = false
            } else {
                // Start collapsed - position divider at the very bottom
                contentSplitView.setPosition(splitHeight, ofDividerAt: 0)
                debugLogContainer.isHidden = true
            }

            // Ensure button state is synchronized with actual visibility
            syncDebugLogButtonState()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = DesignSystem.Colors.background.cgColor

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
        contentSplitView.wantsLayer = true  // Enable layer-backing for smooth animation

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

        // Add all to main stack - header at BOTTOM
        mainStackView.addArrangedSubview(contentSplitView)
        mainStackView.addArrangedSubview(headerView)

        // Set hugging priorities so header stays fixed size
        contentSplitView.setContentHuggingPriority(.defaultLow, for: .vertical)
        headerView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        view.addSubview(mainStackView)
    }

    private func createHeaderView() -> NSView {
        let headerHeight = DesignSystem.Layout.headerHeight
        let headerView = NSView(frame: NSRect(x: 0, y: 0, width: DesignSystem.Layout.defaultWindowWidth, height: headerHeight))
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = DesignSystem.Colors.secondaryBackground.cgColor
        headerView.heightAnchor.constraint(equalToConstant: headerHeight).isActive = true

        // Connection status (left side)
        #if DEBUG
        let debugSuffix = inputController.debugMode ? " [DEBUG MODE]" : ""
        #else
        let debugSuffix = ""
        #endif
        connectionLabel = NSTextField(labelWithString: "🔍 No Joy-Con detected\(debugSuffix)")
        connectionLabel.font = DesignSystem.Typography.headlineMedium
        connectionLabel.textColor = DesignSystem.Colors.secondaryText
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

        // Battery indicator container (right side)
        batteryProgressView = NSView(frame: NSRect(x: 380, y: 12, width: 240, height: 26))
        batteryProgressView.autoresizingMask = [.minXMargin]
        headerView.addSubview(batteryProgressView)

        // Hidden text label (kept for compatibility)
        batteryLabel = NSTextField(labelWithString: "")
        batteryLabel.font = DesignSystem.Typography.bodySmall
        batteryLabel.textColor = DesignSystem.Colors.tertiaryText
        batteryLabel.alignment = .right
        batteryLabel.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
        batteryLabel.isHidden = true
        headerView.addSubview(batteryLabel)

        // LED indicator (removed to make space for battery display)
        ledIndicator = NSTextField(labelWithString: "")
        ledIndicator.font = DesignSystem.Typography.bodySmall
        ledIndicator.textColor = DesignSystem.Colors.tertiaryText
        ledIndicator.alignment = .right
        ledIndicator.frame = NSRect(x: 0, y: 0, width: 0, height: 0)  // Hidden
        ledIndicator.autoresizingMask = [.minXMargin]
        ledIndicator.isHidden = true
        headerView.addSubview(ledIndicator)

        // Debug Log button (right side)
        debugLogButton = NSButton(frame: NSRect(x: 640, y: 10, width: 140, height: 30))
        debugLogButton.title = "▶ Debug Log"  // Initial title (will be synced in viewDidLayout)
        debugLogButton.bezelStyle = .rounded
        debugLogButton.target = self
        debugLogButton.action = #selector(toggleDebugLog(_:))
        debugLogButton.autoresizingMask = [.minXMargin]
        headerView.addSubview(debugLogButton)

        return headerView
    }

    // MARK: - Section Box Helper

    /// Creates a visual section box with title and content
    private func createSectionBox(title: String, content: NSView, yPosition: inout CGFloat, panelWidth: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: DesignSystem.Spacing.lg, y: yPosition, width: panelWidth - (DesignSystem.Spacing.lg * 2), height: content.bounds.height + 60))
        container.autoresizingMask = [.width]  // Allow horizontal resizing

        // Section box with rounded corners and border
        let box = NSBox(frame: container.bounds)
        box.autoresizingMask = [.width, .height]  // Resize with container
        box.boxType = .custom
        box.isTransparent = false
        box.borderWidth = 1
        box.borderColor = DesignSystem.Colors.separator
        box.cornerRadius = DesignSystem.CornerRadius.large
        box.fillColor = DesignSystem.Colors.secondaryBackground
        box.contentViewMargins = NSSize(width: DesignSystem.Spacing.md, height: DesignSystem.Spacing.md)

        // Apply subtle shadow
        box.wantsLayer = true
        let shadowConfig = DesignSystem.Shadow.card
        box.shadow = NSShadow()
        box.shadow?.shadowColor = shadowConfig.color.withAlphaComponent(CGFloat(shadowConfig.opacity))
        box.shadow?.shadowBlurRadius = shadowConfig.radius
        box.shadow?.shadowOffset = shadowConfig.offset

        // Section title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignSystem.Typography.headlineMedium
        titleLabel.textColor = DesignSystem.Colors.text
        titleLabel.frame = NSRect(x: DesignSystem.Spacing.md, y: content.bounds.height + 30, width: container.bounds.width - (DesignSystem.Spacing.md * 2), height: 20)
        titleLabel.autoresizingMask = [.width]  // Resize with container

        // Position content below title
        content.frame.origin = NSPoint(x: DesignSystem.Spacing.md, y: DesignSystem.Spacing.md)
        content.autoresizingMask = [.width]  // Resize with container

        box.addSubview(titleLabel)
        box.addSubview(content)
        container.addSubview(box)

        // Update y position for next section
        yPosition += container.bounds.height + DesignSystem.Spacing.md

        return container
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
        panel.layer?.backgroundColor = DesignSystem.Colors.background.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = DesignSystem.Spacing.lg  // Start from top

        // SECTION 1: Movement
        let movementContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 130))
        var movementY: CGFloat = 0

        // Sensitivity Slider
        let sensitivityTitleLabel = NSTextField(labelWithString: "Sensitivity")
        sensitivityTitleLabel.font = DesignSystem.Typography.bodyMedium
        sensitivityTitleLabel.frame = NSRect(x: 0, y: movementY, width: 100, height: 20)
        movementContent.addSubview(sensitivityTitleLabel)

        sensitivitySlider = NSSlider(frame: NSRect(x: 110, y: movementY, width: 250, height: 20))
        sensitivitySlider.autoresizingMask = [.width]  // Grow with window
        sensitivitySlider.minValue = 0.5
        sensitivitySlider.maxValue = 20.0
        sensitivitySlider.doubleValue = Double(settings.mouseSensitivity)
        sensitivitySlider.target = self
        sensitivitySlider.action = #selector(sensitivityChanged(_:))
        sensitivitySlider.setAccessibilityLabel("Mouse sensitivity slider")
        sensitivitySlider.setAccessibilityValue(String(format: "%.1fx", settings.mouseSensitivity))
        movementContent.addSubview(sensitivitySlider)

        sensitivityLabel = NSTextField(labelWithString: String(format: "%.1fx", settings.mouseSensitivity))
        sensitivityLabel.font = DesignSystem.Typography.bodyMedium
        sensitivityLabel.frame = NSRect(x: 370, y: movementY, width: 60, height: 20)
        sensitivityLabel.autoresizingMask = [.minXMargin]  // Stay anchored to right
        movementContent.addSubview(sensitivityLabel)
        movementY += 30

        // Scroll Sensitivity Slider
        let scrollSensitivityTitleLabel = NSTextField(labelWithString: "Scroll Speed")
        scrollSensitivityTitleLabel.font = DesignSystem.Typography.bodyMedium
        scrollSensitivityTitleLabel.frame = NSRect(x: 0, y: movementY, width: 100, height: 20)
        movementContent.addSubview(scrollSensitivityTitleLabel)

        scrollSensitivitySlider = NSSlider(frame: NSRect(x: 110, y: movementY, width: 250, height: 20))
        scrollSensitivitySlider.autoresizingMask = [.width]  // Grow with window
        scrollSensitivitySlider.minValue = 0.5
        scrollSensitivitySlider.maxValue = 10.0
        scrollSensitivitySlider.doubleValue = Double(settings.scrollSensitivity)
        scrollSensitivitySlider.target = self
        scrollSensitivitySlider.action = #selector(scrollSensitivityChanged(_:))
        scrollSensitivitySlider.setAccessibilityLabel("Scroll speed slider")
        scrollSensitivitySlider.setAccessibilityValue(String(format: "%.1fx", settings.scrollSensitivity))
        movementContent.addSubview(scrollSensitivitySlider)

        scrollSensitivityLabel = NSTextField(labelWithString: String(format: "%.1fx", settings.scrollSensitivity))
        scrollSensitivityLabel.font = DesignSystem.Typography.bodyMedium
        scrollSensitivityLabel.frame = NSRect(x: 370, y: movementY, width: 60, height: 20)
        scrollSensitivityLabel.autoresizingMask = [.minXMargin]  // Stay anchored to right
        movementContent.addSubview(scrollSensitivityLabel)
        movementY += 35

        // Checkboxes
        invertYCheckbox = NSButton(checkboxWithTitle: "Invert Y-Axis", target: self, action: #selector(invertYChanged(_:)))
        invertYCheckbox.font = DesignSystem.Typography.bodyMedium
        invertYCheckbox.frame = NSRect(x: 0, y: movementY, width: 150, height: 20)
        invertYCheckbox.state = settings.invertY ? .on : .off
        invertYCheckbox.setAccessibilityLabel("Invert Y-Axis for scrolling")
        movementContent.addSubview(invertYCheckbox)

        accelerationCheckbox = NSButton(checkboxWithTitle: "Acceleration", target: self, action: #selector(accelerationChanged(_:)))
        accelerationCheckbox.font = DesignSystem.Typography.bodyMedium
        accelerationCheckbox.frame = NSRect(x: 160, y: movementY, width: 150, height: 20)
        accelerationCheckbox.state = settings.mouseAcceleration ? .on : .off
        accelerationCheckbox.setAccessibilityLabel("Enable mouse acceleration")
        movementContent.addSubview(accelerationCheckbox)

        panel.addSubview(createSectionBox(title: "Movement", content: movementContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 2: Deadzone
        let deadzoneContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 70))
        var deadzoneY: CGFloat = 0

        // Left Stick Deadzone Slider
        let leftDeadzoneTitleLabel = NSTextField(labelWithString: "Left Stick")
        leftDeadzoneTitleLabel.font = DesignSystem.Typography.bodyMedium
        leftDeadzoneTitleLabel.frame = NSRect(x: 0, y: deadzoneY, width: 100, height: 20)
        deadzoneContent.addSubview(leftDeadzoneTitleLabel)

        leftDeadzoneSlider = NSSlider(frame: NSRect(x: 110, y: deadzoneY, width: 250, height: 20))
        leftDeadzoneSlider.autoresizingMask = [.width]  // Grow with window
        leftDeadzoneSlider.minValue = 0.0
        leftDeadzoneSlider.maxValue = 0.3
        leftDeadzoneSlider.doubleValue = Double(settings.leftStickDeadzone)
        leftDeadzoneSlider.target = self
        leftDeadzoneSlider.action = #selector(leftDeadzoneChanged(_:))
        deadzoneContent.addSubview(leftDeadzoneSlider)

        leftDeadzoneLabel = NSTextField(labelWithString: String(format: "%.0f%%", settings.leftStickDeadzone * 100))
        leftDeadzoneLabel.font = DesignSystem.Typography.bodyMedium
        leftDeadzoneLabel.frame = NSRect(x: 370, y: deadzoneY, width: 60, height: 20)
        leftDeadzoneLabel.autoresizingMask = [.minXMargin]  // Stay anchored to right
        deadzoneContent.addSubview(leftDeadzoneLabel)
        deadzoneY += 30

        // Right Stick Deadzone Slider
        let rightDeadzoneTitleLabel = NSTextField(labelWithString: "Right Stick")
        rightDeadzoneTitleLabel.font = DesignSystem.Typography.bodyMedium
        rightDeadzoneTitleLabel.frame = NSRect(x: 0, y: deadzoneY, width: 100, height: 20)
        deadzoneContent.addSubview(rightDeadzoneTitleLabel)

        rightDeadzoneSlider = NSSlider(frame: NSRect(x: 110, y: deadzoneY, width: 250, height: 20))
        rightDeadzoneSlider.autoresizingMask = [.width]  // Grow with window
        rightDeadzoneSlider.minValue = 0.0
        rightDeadzoneSlider.maxValue = 0.3
        rightDeadzoneSlider.doubleValue = Double(settings.rightStickDeadzone)
        rightDeadzoneSlider.target = self
        rightDeadzoneSlider.action = #selector(rightDeadzoneChanged(_:))
        deadzoneContent.addSubview(rightDeadzoneSlider)

        rightDeadzoneLabel = NSTextField(labelWithString: String(format: "%.0f%%", settings.rightStickDeadzone * 100))
        rightDeadzoneLabel.font = DesignSystem.Typography.bodyMedium
        rightDeadzoneLabel.frame = NSRect(x: 370, y: deadzoneY, width: 60, height: 20)
        rightDeadzoneLabel.autoresizingMask = [.minXMargin]  // Stay anchored to right
        deadzoneContent.addSubview(rightDeadzoneLabel)

        panel.addSubview(createSectionBox(title: "Deadzone", content: deadzoneContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 3: Stick Functions
        let stickFunctionContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 70))
        var stickFunctionY: CGFloat = 0

        // Left Stick Function
        let leftStickLabel = NSTextField(labelWithString: "Left Stick")
        leftStickLabel.font = DesignSystem.Typography.bodyMedium
        leftStickLabel.frame = NSRect(x: 0, y: stickFunctionY, width: 100, height: 20)
        stickFunctionContent.addSubview(leftStickLabel)

        leftStickFunctionPopup = NSPopUpButton(frame: NSRect(x: 110, y: stickFunctionY - 2, width: 150, height: 25))
        leftStickFunctionPopup.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        leftStickFunctionPopup.removeAllItems()
        leftStickFunctionPopup.addItems(withTitles: ["Mouse", "Scroll", "Arrow Keys", "WASD", "Disabled"])
        leftStickFunctionPopup.selectItem(withTitle: profileManager.activeProfile.leftStickFunction.rawValue)
        leftStickFunctionPopup.target = self
        leftStickFunctionPopup.action = #selector(leftStickFunctionChanged(_:))
        stickFunctionContent.addSubview(leftStickFunctionPopup)
        stickFunctionY += 30

        // Right Stick Function
        let rightStickLabel = NSTextField(labelWithString: "Right Stick")
        rightStickLabel.font = DesignSystem.Typography.bodyMedium
        rightStickLabel.frame = NSRect(x: 0, y: stickFunctionY, width: 100, height: 20)
        stickFunctionContent.addSubview(rightStickLabel)

        rightStickFunctionPopup = NSPopUpButton(frame: NSRect(x: 110, y: stickFunctionY - 2, width: 150, height: 25))
        rightStickFunctionPopup.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        rightStickFunctionPopup.removeAllItems()
        rightStickFunctionPopup.addItems(withTitles: ["Mouse", "Scroll", "Arrow Keys", "WASD", "Disabled"])
        rightStickFunctionPopup.selectItem(withTitle: profileManager.activeProfile.rightStickFunction.rawValue)
        rightStickFunctionPopup.target = self
        rightStickFunctionPopup.action = #selector(rightStickFunctionChanged(_:))
        stickFunctionContent.addSubview(rightStickFunctionPopup)

        panel.addSubview(createSectionBox(title: "Stick Functions", content: stickFunctionContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 4: Sticky Mouse
        let stickyMouseContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 135))
        var stickyMouseY: CGFloat = 0

        // Sticky Mouse Enable Checkbox
        stickyMouseCheckbox = NSButton(checkboxWithTitle: "Enable sticky mouse", target: self, action: #selector(stickyMouseToggled(_:)))
        stickyMouseCheckbox.font = DesignSystem.Typography.bodyMedium
        stickyMouseCheckbox.frame = NSRect(x: 0, y: stickyMouseY, width: 300, height: 20)
        stickyMouseCheckbox.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        stickyMouseCheckbox.state = StickyMouseManager.shared.isEnabled ? .on : .off
        stickyMouseContent.addSubview(stickyMouseCheckbox)
        stickyMouseY += 25

        // Magnetic Strength Popup
        let strengthLabel = NSTextField(labelWithString: "Strength")
        strengthLabel.font = DesignSystem.Typography.bodyMedium
        strengthLabel.frame = NSRect(x: 0, y: stickyMouseY, width: 100, height: 20)
        stickyMouseContent.addSubview(strengthLabel)

        stickyStrengthPopup = NSPopUpButton(frame: NSRect(x: 110, y: stickyMouseY - 2, width: 120, height: 25))
        stickyStrengthPopup.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        stickyStrengthPopup.removeAllItems()
        stickyStrengthPopup.addItems(withTitles: ["Weak", "Medium", "Strong"])
        stickyStrengthPopup.selectItem(withTitle: StickyMouseManager.shared.magneticStrength.description)
        stickyStrengthPopup.target = self
        stickyStrengthPopup.action = #selector(stickyStrengthChanged(_:))
        stickyMouseContent.addSubview(stickyStrengthPopup)
        stickyMouseY += 30

        // Visual Overlay Checkbox
        stickyOverlayCheckbox = NSButton(checkboxWithTitle: "Show visual overlay", target: self, action: #selector(stickyOverlayToggled(_:)))
        stickyOverlayCheckbox.font = DesignSystem.Typography.bodyMedium
        stickyOverlayCheckbox.frame = NSRect(x: 0, y: stickyMouseY, width: 300, height: 20)
        stickyOverlayCheckbox.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        stickyOverlayCheckbox.state = StickyMouseManager.shared.showVisualOverlay ? .on : .off
        stickyMouseContent.addSubview(stickyOverlayCheckbox)
        stickyMouseY += 30

        // Sticky Mouse Info
        let stickyInfoLabel = NSTextField(wrappingLabelWithString: "ℹ️ Slows cursor near buttons and text fields, making them easier to click. Toggle with L button, adjust strength with ZL+X.")
        stickyInfoLabel.font = DesignSystem.Typography.caption
        stickyInfoLabel.textColor = DesignSystem.Colors.tertiaryText
        stickyInfoLabel.alignment = .left
        stickyInfoLabel.frame = NSRect(x: 0, y: stickyMouseY, width: frame.width - 120, height: 30)
        stickyInfoLabel.autoresizingMask = [.width]  // Grow with window
        stickyMouseContent.addSubview(stickyInfoLabel)

        panel.addSubview(createSectionBox(title: "Sticky Mouse", content: stickyMouseContent, yPosition: &y, panelWidth: frame.width))

        // Debug mode toggle (only in debug builds)
        #if DEBUG
        let debugContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 50))
        debugModeCheckbox = NSButton(checkboxWithTitle: "Debug Mode (skip system input events)", target: self, action: #selector(debugModeChanged(_:)))
        debugModeCheckbox.font = DesignSystem.Typography.bodyMedium
        debugModeCheckbox.frame = NSRect(x: 0, y: 0, width: 350, height: 20)
        debugModeCheckbox.autoresizingMask = [.maxXMargin]  // Stay anchored to left
        debugModeCheckbox.state = inputController.debugMode ? .on : .off
        debugContent.addSubview(debugModeCheckbox)

        let debugInfo = NSTextField(wrappingLabelWithString: "⚠️ DEBUG MODE: Input events are logged but not sent to the system.")
        debugInfo.font = DesignSystem.Typography.caption
        debugInfo.textColor = DesignSystem.Colors.warning
        debugInfo.frame = NSRect(x: 0, y: 25, width: frame.width - 120, height: 20)
        debugInfo.autoresizingMask = [.width]  // Grow with window
        debugContent.addSubview(debugInfo)

        panel.addSubview(createSectionBox(title: "Debug", content: debugContent, yPosition: &y, panelWidth: frame.width))
        #endif

        // Set panel height based on content
        let contentHeight = y + DesignSystem.Spacing.lg
        panel.frame = NSRect(x: 0, y: 0, width: frame.width, height: contentHeight)

        // Wrap in scroll view for vertical scrolling
        let scrollView = NSScrollView(frame: frame)
        scrollView.documentView = panel
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        return scrollView
    }

    private func createKeyboardConfigPanel(frame: NSRect) -> NSView {
        // Use flipped view so y=0 is at top
        let panel = FlippedView(frame: frame)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = DesignSystem.Colors.background.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = 20  // Start from top

        // Title
        let titleLabel = NSTextField(labelWithString: "Keyboard Layout & Mapping")
        titleLabel.font = DesignSystem.Typography.headlineLarge
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

        keyboardPresetPopup = NSPopUpButton(frame: NSRect(x: 130, y: y - 5, width: 180, height: 25))
        keyboardPresetPopup.addItems(withTitles: profileManager.getProfileNames())
        if let activeIndex = profileManager.getProfileNames().firstIndex(of: profileManager.activeProfile.name) {
            keyboardPresetPopup.selectItem(at: activeIndex)
        }
        keyboardPresetPopup.target = self
        keyboardPresetPopup.action = #selector(profileSelectionChanged(_:))
        panel.addSubview(keyboardPresetPopup)

        // Reset button (with better spacing)
        let resetButton = NSButton(frame: NSRect(x: 330, y: y - 5, width: 70, height: 25))
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetProfileToDefaults(_:))
        resetButton.autoresizingMask = [.minXMargin]
        panel.addSubview(resetButton)

        // Clone button (adjusted for new spacing)
        let cloneButton = NSButton(frame: NSRect(x: 410, y: y - 5, width: 70, height: 25))
        cloneButton.title = "Clone"
        cloneButton.bezelStyle = .rounded
        cloneButton.target = self
        cloneButton.action = #selector(cloneProfile(_:))
        cloneButton.autoresizingMask = [.minXMargin]
        panel.addSubview(cloneButton)

        y += 30

        // Profile description
        let descLabel = NSTextField(wrappingLabelWithString: profileManager.activeProfile.description)
        descLabel.font = DesignSystem.Typography.bodySmall
        descLabel.textColor = DesignSystem.Colors.secondaryText
        descLabel.frame = NSRect(x: 20, y: y, width: frame.width - 40, height: 20)
        descLabel.autoresizingMask = [.width]
        panel.addSubview(descLabel)
        y += 30

        // Scrollable button mapping editor - fills remaining space
        let scrollViewHeight: CGFloat = frame.height - y - 20  // 20 = bottom padding
        let scrollViewWidth: CGFloat = frame.width - 40
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: y, width: scrollViewWidth, height: scrollViewHeight))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false  // Always show for clarity
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]  // Resize with window

        // Use FlippedView for top-down coordinates (will set final height after adding content)
        // Subtract scroller width to prevent dark bar on right side
        let contentWidth = scrollView.contentSize.width
        let documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 500))
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = DesignSystem.Colors.background.cgColor
        documentView.autoresizingMask = [.width]  // Resize width with scroll view

        var rowY: CGFloat = 10  // Start from top

        // Helper to create button row
        let createRow: (String, ButtonAction, Int) -> Void = { buttonName, action, tag in
            // Button name label
            let nameLabel = NSTextField(labelWithString: buttonName)
            nameLabel.frame = NSRect(x: DesignSystem.Spacing.sm, y: rowY, width: 100, height: 20)
            nameLabel.font = DesignSystem.Typography.bodyMedium
            nameLabel.textColor = DesignSystem.Colors.text
            documentView.addSubview(nameLabel)

            // Current mapping label
            let mappingLabel = NSTextField(labelWithString: action.description)
            mappingLabel.frame = NSRect(x: 130, y: rowY, width: 250, height: 20)
            mappingLabel.font = DesignSystem.Typography.codeSmall
            mappingLabel.textColor = DesignSystem.Colors.secondaryText
            mappingLabel.autoresizingMask = [.width]  // Grow with window
            documentView.addSubview(mappingLabel)

            // Edit button (positioned on right side)
            let editBtn = NSButton(frame: NSRect(x: documentView.bounds.width - 80, y: rowY - 2, width: 70, height: 24))
            editBtn.title = "Edit"
            editBtn.bezelStyle = .rounded
            editBtn.font = DesignSystem.Typography.bodySmall
            editBtn.tag = tag
            editBtn.target = self
            editBtn.action = #selector(self.editButtonMapping(_:))
            editBtn.autoresizingMask = [.minXMargin]  // Keep on right when resizing
            documentView.addSubview(editBtn)

            rowY += 28  // Move down for next row (improved spacing)
        }

        // Helper to create section header
        let createSectionHeader: (String) -> Void = { title in
            let header = NSTextField(labelWithString: title)
            header.frame = NSRect(x: DesignSystem.Spacing.xs, y: rowY, width: 250, height: 22)
            header.font = DesignSystem.Typography.headlineMedium
            header.textColor = DesignSystem.Colors.text
            documentView.addSubview(header)
            rowY += 30
        }

        // Face Buttons section
        createSectionHeader("Face Buttons")
        createRow("A Button", profileManager.activeProfile.buttonA, 1)
        createRow("B Button", profileManager.activeProfile.buttonB, 2)
        createRow("X Button", profileManager.activeProfile.buttonX, 3)
        createRow("Y Button", profileManager.activeProfile.buttonY, 4)
        rowY += DesignSystem.Spacing.md

        // D-Pad section
        createSectionHeader("D-Pad")
        createRow("Up", profileManager.activeProfile.dpadUp, 5)
        createRow("Right", profileManager.activeProfile.dpadRight, 6)
        createRow("Down", profileManager.activeProfile.dpadDown, 7)
        createRow("Left", profileManager.activeProfile.dpadLeft, 8)
        rowY += DesignSystem.Spacing.md

        // Triggers section
        createSectionHeader("Triggers & Bumpers")
        // Note: L/R bumpers are ModifierActions and handled separately
        createRow("ZL Trigger", profileManager.activeProfile.triggerZL, 11)
        createRow("ZR Trigger", profileManager.activeProfile.triggerZR, 12)
        createRow("ZL+ZR Combo", profileManager.activeProfile.triggerZLZR, 13)
        rowY += DesignSystem.Spacing.md

        // System Buttons section
        createSectionHeader("System Buttons")
        createRow("Minus", profileManager.activeProfile.buttonMinus, 14)
        createRow("Plus", profileManager.activeProfile.buttonPlus, 15)
        createRow("Home", profileManager.activeProfile.buttonHome, 16)
        createRow("Capture", profileManager.activeProfile.buttonCapture, 17)
        rowY += DesignSystem.Spacing.md

        // Stick Clicks section
        createSectionHeader("Stick Clicks")
        createRow("L-Stick Click", profileManager.activeProfile.leftStickClick, 18)
        createRow("R-Stick Click", profileManager.activeProfile.rightStickClick, 19)
        rowY += DesignSystem.Spacing.md

        // Side Buttons section (Joy-Con sideways mode)
        createSectionHeader("Side Buttons (SL/SR)")
        createRow("SL", profileManager.activeProfile.buttonSL, 20)
        createRow("SR", profileManager.activeProfile.buttonSR, 21)

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
        panel.layer?.backgroundColor = DesignSystem.Colors.background.cgColor
        panel.autoresizingMask = [.width, .height]

        var y: CGFloat = DesignSystem.Spacing.lg  // Start from top

        // SECTION 1: Permissions
        let hasPermissions = VoiceInputManager.checkVoiceInputPermissions()
        let permissionsContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: hasPermissions ? 20 : 50))
        var permissionsY: CGFloat = 0

        // Permission Status
        let permissionLabel = NSTextField(labelWithString: hasPermissions ? "✅ Permissions Granted" : "⚠️ Permissions Required")
        permissionLabel.font = DesignSystem.Typography.bodyMedium
        permissionLabel.textColor = hasPermissions ? DesignSystem.Colors.success : DesignSystem.Colors.warning
        permissionLabel.frame = NSRect(x: 0, y: permissionsY, width: 200, height: 20)
        permissionsContent.addSubview(permissionLabel)

        // Grant Permissions button (if not granted)
        if !hasPermissions {
            let grantButton = NSButton(frame: NSRect(x: 0, y: permissionsY + 25, width: 150, height: 24))
            grantButton.title = "Grant Permissions"
            grantButton.bezelStyle = .rounded
            grantButton.autoresizingMask = [.maxXMargin]  // Stay anchored to left
            grantButton.target = self
            grantButton.action = #selector(grantVoicePermissionsClicked)
            permissionsContent.addSubview(grantButton)
        }

        panel.addSubview(createSectionBox(title: "Permissions", content: permissionsContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 2: Settings
        let settingsContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 60))
        var settingsY: CGFloat = 0

        // Language Selection
        let languageLabel = NSTextField(labelWithString: "Language")
        languageLabel.font = DesignSystem.Typography.bodyMedium
        languageLabel.frame = NSRect(x: 0, y: settingsY, width: 100, height: 20)
        settingsContent.addSubview(languageLabel)

        voiceLanguagePopup = NSPopUpButton(frame: NSRect(x: 110, y: settingsY - 2, width: 250, height: 24))
        voiceLanguagePopup.autoresizingMask = [.maxXMargin]  // Stay anchored to left
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
        settingsContent.addSubview(voiceLanguagePopup)
        settingsY += 30

        // Status
        voiceStatusLabel = NSTextField(labelWithString: "⏸️ Ready")
        voiceStatusLabel.font = DesignSystem.Typography.bodyMedium
        voiceStatusLabel.textColor = DesignSystem.Colors.secondaryText
        voiceStatusLabel.frame = NSRect(x: 0, y: settingsY, width: 400, height: 20)
        voiceStatusLabel.autoresizingMask = [.width]  // Grow with window
        settingsContent.addSubview(voiceStatusLabel)

        panel.addSubview(createSectionBox(title: "Settings", content: settingsContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 3: How to Use
        let howToContent = NSView(frame: NSRect(x: 0, y: 0, width: frame.width - 100, height: 90))
        var howToY: CGFloat = 0

        // Instructions
        let instructionsLabel = NSTextField(wrappingLabelWithString: "1. Hold ZL + ZR on your Joy-Con to activate voice input\n\n2. Speak naturally in your selected language\n\n3. Release ZL + ZR to type your words automatically")
        instructionsLabel.font = DesignSystem.Typography.bodySmall
        instructionsLabel.textColor = DesignSystem.Colors.text
        instructionsLabel.frame = NSRect(x: 0, y: howToY, width: frame.width - 120, height: 75)
        instructionsLabel.autoresizingMask = [.width]  // Grow with window
        howToContent.addSubview(instructionsLabel)
        howToY += 80

        // Info text
        let infoLabel = NSTextField(wrappingLabelWithString: "ℹ️ Voice input converts your speech to text and types it automatically. Perfect for hands-free typing!")
        infoLabel.font = DesignSystem.Typography.caption
        infoLabel.textColor = DesignSystem.Colors.tertiaryText
        infoLabel.frame = NSRect(x: 0, y: howToY, width: frame.width - 120, height: 30)
        infoLabel.autoresizingMask = [.width]  // Grow with window
        howToContent.addSubview(infoLabel)

        panel.addSubview(createSectionBox(title: "How to Use", content: howToContent, yPosition: &y, panelWidth: frame.width))

        // Set panel height based on content
        let contentHeight = y + DesignSystem.Spacing.lg
        panel.frame = NSRect(x: 0, y: 0, width: frame.width, height: contentHeight)

        // Wrap in scroll view for vertical scrolling
        let scrollView = NSScrollView(frame: frame)
        scrollView.documentView = panel
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        return scrollView
    }


    private func createDebugLogView() {
        // Debug log container
        debugLogContainer = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        debugLogContainer.isHidden = true  // Start hidden (matches isDebugLogExpanded = false)
        debugLogContainer.wantsLayer = true  // Enable layer-backing for smooth animation

        scrollView = NSScrollView(frame: debugLogContainer.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = DesignSystem.Colors.debugBackground

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
        textView.font = DesignSystem.Typography.codeMedium
        textView.textColor = DesignSystem.Colors.debugText
        textView.backgroundColor = DesignSystem.Colors.debugBackground
        textView.textContainerInset = NSSize(width: DesignSystem.Spacing.xs, height: DesignSystem.Spacing.xs)

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
        settings.saveToUserDefaults()
    }

    @objc private func scrollSensitivityChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        settings.scrollSensitivity = value
        scrollSensitivityLabel.stringValue = String(format: "%.1fx", value)
        settings.saveToUserDefaults()
    }

    @objc private func leftDeadzoneChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        settings.leftStickDeadzone = value
        leftDeadzoneLabel.stringValue = String(format: "%.0f%%", value * 100)
        settings.saveToUserDefaults()
    }

    @objc private func rightDeadzoneChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        settings.rightStickDeadzone = value
        rightDeadzoneLabel.stringValue = String(format: "%.0f%%", value * 100)
        settings.saveToUserDefaults()
    }

    @objc private func invertYChanged(_ sender: NSButton) {
        settings.invertY = (sender.state == .on)
        settings.saveToUserDefaults()
        log("Invert Y: \(settings.invertY)")
    }

    @objc private func accelerationChanged(_ sender: NSButton) {
        settings.mouseAcceleration = (sender.state == .on)
        settings.saveToUserDefaults()
        log("Mouse acceleration: \(settings.mouseAcceleration)")
    }

    @objc private func leftStickFunctionChanged(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.titleOfSelectedItem,
              let function = ButtonProfile.StickFunction(rawValue: selectedTitle) else { return }

        var profile = profileManager.activeProfile
        profile.leftStickFunction = function
        profileManager.updateProfile(profile)
        log("Left stick function changed to: \(function.rawValue)")
    }

    @objc private func rightStickFunctionChanged(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.titleOfSelectedItem,
              let function = ButtonProfile.StickFunction(rawValue: selectedTitle) else { return }

        var profile = profileManager.activeProfile
        profile.rightStickFunction = function
        profileManager.updateProfile(profile)
        log("Right stick function changed to: \(function.rawValue)")
    }

    @objc private func stickyMouseToggled(_ sender: NSButton) {
        StickyMouseManager.shared.isEnabled = (sender.state == .on)
        log("🧲 Sticky Mouse: \(StickyMouseManager.shared.isEnabled ? "ON" : "OFF")")
    }

    @objc private func stickyStrengthChanged(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.titleOfSelectedItem else { return }

        switch selectedTitle {
        case "Weak":
            StickyMouseManager.shared.magneticStrength = .weak
        case "Strong":
            StickyMouseManager.shared.magneticStrength = .strong
        default:
            StickyMouseManager.shared.magneticStrength = .medium
        }

        log("🧲 Magnetic strength: \(StickyMouseManager.shared.magneticStrength.description)")
    }

    @objc private func stickyOverlayToggled(_ sender: NSButton) {
        StickyMouseManager.shared.showVisualOverlay = (sender.state == .on)
        log("🧲 Visual overlay: \(StickyMouseManager.shared.showVisualOverlay ? "ON" : "OFF")")
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

        // Create mapping editor view
        let editorView = ButtonMappingEditor(
            buttonName: buttonName,
            currentMapping: currentAction.description
        )

        editorView.onActionSelected = { [weak self] action in
            self?.updateButtonAction(forTag: tag, newAction: action)
            self?.log("✅ Updated \(buttonName) → \(action.description)")
            self?.refreshKeyboardPanel()
            // Close the window
            self?.keyCaptureWindow?.close()
            self?.keyCaptureWindow = nil
        }

        editorView.onCancelled = { [weak self] in
            self?.log("⌨️ Cancelled editing")
            // Close the window
            self?.keyCaptureWindow?.close()
            self?.keyCaptureWindow = nil
        }

        // Show as a modal window
        keyCaptureWindow = NSWindow(contentViewController: NSViewController())
        keyCaptureWindow!.contentView = editorView
        keyCaptureWindow!.styleMask = [.titled, .closable]
        keyCaptureWindow!.setContentSize(NSSize(width: 300, height: 180))
        keyCaptureWindow!.title = "Edit \(buttonName)"
        keyCaptureWindow!.center()
        keyCaptureWindow!.makeKeyAndOrderFront(nil)
        keyCaptureWindow!.level = .floating
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
        case 14: return ("Minus", profile.buttonMinus)
        case 15: return ("Plus", profile.buttonPlus)
        case 16: return ("Home", profile.buttonHome)
        case 17: return ("Capture", profile.buttonCapture)
        case 18: return ("L-Stick Click", profile.leftStickClick)
        case 19: return ("R-Stick Click", profile.rightStickClick)
        case 20: return ("SL", profile.buttonSL)
        case 21: return ("SR", profile.buttonSR)
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
        case 14: updatedProfile.buttonMinus = newAction
        case 15: updatedProfile.buttonPlus = newAction
        case 16: updatedProfile.buttonHome = newAction
        case 17: updatedProfile.buttonCapture = newAction
        case 18: updatedProfile.leftStickClick = newAction
        case 19: updatedProfile.rightStickClick = newAction
        case 20: updatedProfile.buttonSL = newAction
        case 21: updatedProfile.buttonSR = newAction
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

    // MARK: - Debug Log Toggle

    /// Synchronizes the debug log button state with the actual visibility
    private func syncDebugLogButtonState() {
        debugLogButton.title = isDebugLogExpanded ? "▼ Debug Log" : "▶ Debug Log"
    }

    @objc private func toggleDebugLog(_ sender: NSButton) {
        isDebugLogExpanded = !isDebugLogExpanded

        if isDebugLogExpanded {
            // Expand: show debug log at 200px height
            debugLogContainer.isHidden = false
            syncDebugLogButtonState()

            let splitHeight = contentSplitView.bounds.height
            let targetPosition = max(splitHeight - 200, 100)  // Ensure minimum tab view size

            // Use implicit animation - AppKit will animate the layer geometry changes
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true

                // Call setPosition directly - implicit animation will handle it
                self.contentSplitView.setPosition(targetPosition, ofDividerAt: 0)
            })
        } else {
            // Collapse: hide debug log
            syncDebugLogButtonState()

            let splitHeight = contentSplitView.bounds.height

            // Use implicit animation - AppKit will animate the layer geometry changes
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true

                // Call setPosition directly - implicit animation will handle it
                self.contentSplitView.setPosition(splitHeight, ofDividerAt: 0)
            }, completionHandler: {
                self.debugLogContainer.isHidden = true
            })
        }
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
                .font: DesignSystem.Typography.codeMedium,
                .foregroundColor: DesignSystem.Colors.debugText
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
                self.batteryProgressView.subviews.forEach { $0.removeFromSuperview() }
                self.ledIndicator.stringValue = ""
                self.helpButton?.isHidden = false  // Show help button when no controller
            } else {
                let names = self.controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
                self.connectionLabel.stringValue = "✅ Connected: \(names.joined(separator: " + "))\(debugSuffix)"
                self.connectionLabel.textColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

                // Update battery display
                self.updateBatteryDisplay()

                // LED indicator
                let count = self.controllers.count
                self.ledIndicator.stringValue = "🔵 LED \(count)"
                self.helpButton?.isHidden = true  // Hide help button when connected
            }
        }
    }

    private func updateBatteryDisplay() {
        // Clear existing battery UI
        batteryProgressView.subviews.forEach { $0.removeFromSuperview() }

        if controllers.count == 1 {
            // Single controller - full width display
            let controller = controllers[0]
            createBatteryIndicator(
                for: controller,
                label: nil,
                frame: NSRect(x: 0, y: 0, width: 240, height: 26)
            )
        } else if controllers.count == 2 {
            // Two controllers - split display
            let left = controllers.first { $0.type == .JoyConL }
            let right = controllers.first { $0.type == .JoyConR }

            if let left = left {
                createBatteryIndicator(
                    for: left,
                    label: "L",
                    frame: NSRect(x: 0, y: 0, width: 110, height: 26)
                )
            }

            if let right = right {
                createBatteryIndicator(
                    for: right,
                    label: "R",
                    frame: NSRect(x: 130, y: 0, width: 110, height: 26)
                )
            }
        }
    }

    private func createBatteryIndicator(for controller: Controller, label: String?, frame: NSRect) {
        let container = NSView(frame: frame)

        var xOffset: CGFloat = 0

        // Controller label (L/R) if provided
        if let label = label {
            let labelField = NSTextField(labelWithString: "\(label):")
            labelField.font = DesignSystem.Typography.bodySmall
            labelField.textColor = DesignSystem.Colors.tertiaryText
            labelField.frame = NSRect(x: xOffset, y: 8, width: 15, height: 14)
            container.addSubview(labelField)
            xOffset += 18
        }

        let percentage = batteryPercentage(for: controller.battery)
        let color = batteryColor(for: controller.battery)

        if percentage >= 0 {
            // Charging indicator
            if controller.isCharging {
                let chargeLabel = NSTextField(labelWithString: "⚡")
                chargeLabel.font = DesignSystem.Typography.bodySmall
                chargeLabel.textColor = DesignSystem.Colors.warning
                chargeLabel.frame = NSRect(x: xOffset, y: 6, width: 15, height: 16)
                container.addSubview(chargeLabel)
                xOffset += 16
            }

            // Progress bar
            let progressBar = NSProgressIndicator(frame: NSRect(x: xOffset, y: 8, width: 50, height: 10))
            progressBar.style = .bar
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = 100
            progressBar.doubleValue = Double(percentage)
            container.addSubview(progressBar)
            xOffset += 55

            // Percentage label
            let percentLabel = NSTextField(labelWithString: "\(percentage)%")
            percentLabel.font = DesignSystem.Typography.bodySmall
            percentLabel.textColor = color
            percentLabel.frame = NSRect(x: xOffset, y: 8, width: 35, height: 14)
            container.addSubview(percentLabel)
        } else {
            // Unknown battery state
            let unknownLabel = NSTextField(labelWithString: "---")
            unknownLabel.font = DesignSystem.Typography.bodySmall
            unknownLabel.textColor = DesignSystem.Colors.tertiaryText
            unknownLabel.frame = NSRect(x: xOffset, y: 8, width: 30, height: 14)
            container.addSubview(unknownLabel)
        }

        batteryProgressView.addSubview(container)
    }

    private func batteryPercentage(for battery: JoyCon.BatteryStatus) -> Int {
        switch battery {
        case .full: return 100
        case .medium: return 50
        case .low: return 25
        case .critical: return 10
        case .empty: return 0
        case .unknown: return -1
        }
    }

    private func batteryColor(for battery: JoyCon.BatteryStatus) -> NSColor {
        switch battery {
        case .full, .medium:
            return DesignSystem.Colors.success
        case .low:
            return DesignSystem.Colors.warning
        case .critical, .empty:
            return DesignSystem.Colors.error
        case .unknown:
            return DesignSystem.Colors.tertiaryText
        }
    }

    private func handleBatteryChange(newState: JoyCon.BatteryStatus, oldState: JoyCon.BatteryStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.updateBatteryDisplay()
        }

        // Log significant battery events
        if newState == .critical && oldState != .empty {
            log("⚠️ Battery Critical! Please charge your Joy-Con soon")
        }
        if newState == .low && oldState == .medium {
            log("🔋 Battery Low (25%)")
        }
        if newState == .full && oldState != .unknown {
            log("✅ Battery Full!")
        }
    }

    private func handleChargingChange(isCharging: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateBatteryDisplay()
        }
        log(isCharging ? "⚡ Charging started" : "⚡ Charging stopped")
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
                #if DEBUG
                // Check if drift logging is active - if so, start marking drift while held
                if DriftLogger.shared.loggingEnabled {
                    self.isPlusHeldForDriftMarking = true
                    self.log("🚩 Marking drift (hold Plus)...")
                } else {
                    self.executeButtonAction(self.profileManager.activeProfile.buttonPlus, buttonName: "Plus")
                }
                #else
                self.executeButtonAction(self.profileManager.activeProfile.buttonPlus, buttonName: "Plus")
                #endif
            case .Home:
                self.executeButtonAction(self.profileManager.activeProfile.buttonHome, buttonName: "Home")
            case .Capture:
                self.executeButtonAction(self.profileManager.activeProfile.buttonCapture, buttonName: "Capture")
            case .LeftSL, .RightSL:
                self.executeButtonAction(self.profileManager.activeProfile.buttonSL, buttonName: "SL")
            case .LeftSR, .RightSR:
                self.executeButtonAction(self.profileManager.activeProfile.buttonSR, buttonName: "SR")
            case .LStick:
                self.executeButtonAction(self.profileManager.activeProfile.leftStickClick, buttonName: "L-Stick")
            case .RStick:
                self.executeButtonAction(self.profileManager.activeProfile.rightStickClick, buttonName: "R-Stick")
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

        // Battery monitoring
        controller.batteryChangeHandler = { [weak self] newState, oldState in
            self?.handleBatteryChange(newState: newState, oldState: oldState)
        }

        controller.isChargingChangeHandler = { [weak self] isCharging in
            self?.handleChargingChange(isCharging: isCharging)
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
        // Send real modifier key press (like holding Cmd on keyboard)
        inputController.pressModifier(modifier)
    }

    private func removeModifier(_ modifier: ModifierAction) {
        // Send real modifier key release first
        inputController.releaseModifier(modifier)

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
        let profile = profileManager.activeProfile
        handleStickInput(x: x, y: y, function: profile.leftStickFunction, stick: .left)

        #if DEBUG
        // Log drift data for left stick
        logStickDrift(x: x, y: y, stickName: "LeftStick", previous: previousLeftStick)
        #endif
        previousLeftStick = (x, y)
    }

    private func handleRightStick(x: Float, y: Float) {
        let profile = profileManager.activeProfile
        handleStickInput(x: x, y: y, function: profile.rightStickFunction, stick: .right)

        #if DEBUG
        // Log drift data for right stick
        logStickDrift(x: x, y: y, stickName: "RightStick", previous: previousRightStick)
        #endif
        previousRightStick = (x, y)
    }

    private func handleStickInput(x: Float, y: Float, function: ButtonProfile.StickFunction, stick: InputController.Stick) {
        switch function {
        case .mouse:
            inputController.setMouseDelta(x: x, y: y, stick: stick)
        case .scroll:
            inputController.setScrollDelta(x: x, y: y, stick: stick)
        case .arrowKeys:
            handleStickAsArrowKeys(x: x, y: y)
        case .wasd:
            handleStickAsWASD(x: x, y: y)
        case .disabled:
            break
        }
    }

    private func handleStickAsArrowKeys(x: Float, y: Float) {
        let threshold: Float = 0.5
        if abs(x) > threshold || abs(y) > threshold {
            if abs(x) > abs(y) {
                if x > threshold {
                    inputController.pressArrowRight()
                } else if x < -threshold {
                    inputController.pressArrowLeft()
                }
            } else {
                if y > threshold {
                    inputController.pressArrowUp()
                } else if y < -threshold {
                    inputController.pressArrowDown()
                }
            }
        }
    }

    private func handleStickAsWASD(x: Float, y: Float) {
        let threshold: Float = 0.5
        if abs(x) > threshold || abs(y) > threshold {
            if abs(x) > abs(y) {
                if x > threshold {
                    inputController.pressKey(CGKeyCode(kVK_ANSI_D))  // Right
                } else if x < -threshold {
                    inputController.pressKey(CGKeyCode(kVK_ANSI_A))  // Left
                }
            } else {
                if y > threshold {
                    inputController.pressKey(CGKeyCode(kVK_ANSI_W))  // Up
                } else if y < -threshold {
                    inputController.pressKey(CGKeyCode(kVK_ANSI_S))  // Down
                }
            }
        }
    }

    #if DEBUG
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
    #endif

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
