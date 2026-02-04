import Cocoa
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
    private var invertYCheckbox: NSControl!  // NSSwitch
    private var accelerationCheckbox: NSControl!  // NSSwitch
    private var leftStickFunctionPopup: NSPopUpButton!
    private var rightStickFunctionPopup: NSPopUpButton!

    // Sticky Mouse Controls
    private var stickyMouseCheckbox: NSControl!  // NSSwitch
    private var stickyStrengthPopup: NSPopUpButton!
    private var stickyOverlayCheckbox: NSControl!  // NSSwitch

    // Keyboard Controls
    private var keyboardPresetPopup: NSPopUpButton!

    // Debug Controls
    #if DEBUG
    private var debugModeCheckbox: NSControl!  // NSSwitch
    #endif

    // Voice Controls
    private var voiceStatusLabel: NSTextField!
    private var voiceLanguagePopup: NSPopUpButton!

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
        log("berrry-joyful initialized - waiting for controllers...")
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        hasPerformedInitialLayout = true
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

        // Add to split view
        contentSplitView.addArrangedSubview(tabView)

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
        connectionLabel = NSTextField(labelWithString: "No Joy-Con detected\(debugSuffix)")
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
        batteryLabel.font = DesignSystem.Typography.bodyMedium
        batteryLabel.textColor = DesignSystem.Colors.tertiaryText
        batteryLabel.alignment = .right
        batteryLabel.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
        batteryLabel.isHidden = true
        headerView.addSubview(batteryLabel)

        // LED indicator (removed to make space for battery display)
        ledIndicator = NSTextField(labelWithString: "")
        ledIndicator.font = DesignSystem.Typography.bodyMedium
        ledIndicator.textColor = DesignSystem.Colors.tertiaryText
        ledIndicator.alignment = .right
        ledIndicator.frame = NSRect(x: 0, y: 0, width: 0, height: 0)  // Hidden
        ledIndicator.autoresizingMask = [.minXMargin]
        ledIndicator.isHidden = true
        headerView.addSubview(ledIndicator)

        return headerView
    }

    // MARK: - System Settings Style Row Helpers

    /// Create a horizontal slider row (System Settings style)
    private func createSliderRow(
        label: String,
        slider: inout NSSlider?,
        valueLabel: inout NSTextField?,
        value: Double,
        minValue: Double,
        maxValue: Double,
        formatString: String,
        action: Selector,
        yPosition: CGFloat,
        width: CGFloat,
        labelWidth: CGFloat
    ) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: yPosition, width: width, height: 32))
        row.autoresizingMask = [.width]

        // Label on left (x=0 since content is already offset by contentLeftInset)
        let labelView = NSTextField(labelWithString: label)
        labelView.font = DesignSystem.Typography.bodyMedium
        labelView.textColor = DesignSystem.Colors.text
        labelView.alignment = .left
        labelView.frame = NSRect(x: 0, y: 6, width: labelWidth, height: 20)
        labelView.autoresizingMask = [.maxXMargin]
        row.addSubview(labelView)

        // Value label on far right (60px from right edge)
        let valueLbl = NSTextField(labelWithString: String(format: formatString, value))
        valueLbl.font = DesignSystem.Typography.bodyMedium
        valueLbl.textColor = DesignSystem.Colors.secondaryText
        valueLbl.alignment = .right
        valueLbl.frame = NSRect(x: width - 60 - DesignSystem.Spacing.lg, y: 6, width: 60, height: 20)
        valueLbl.autoresizingMask = [.minXMargin]
        row.addSubview(valueLbl)
        valueLabel = valueLbl

        // Slider in the middle (between label and value)
        let sldr = NSSlider(frame: NSRect(x: labelWidth + DesignSystem.Spacing.md, y: 6, width: width - labelWidth - 60 - DesignSystem.Spacing.lg - DesignSystem.Spacing.md, height: 20))
        sldr.minValue = minValue
        sldr.maxValue = maxValue
        sldr.doubleValue = value
        sldr.target = self
        sldr.action = action
        sldr.autoresizingMask = [.width]  // Grow with window
        row.addSubview(sldr)
        slider = sldr

        return row
    }

    /// Create a horizontal switch row (System Settings style)
    private func createCheckboxRow(
        label: String,
        checkbox: inout NSControl?,
        isChecked: Bool,
        action: Selector,
        yPosition: CGFloat,
        width: CGFloat,
        labelWidth: CGFloat
    ) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: yPosition, width: width, height: 28))
        row.autoresizingMask = [.width]

        // Label on left (x=0 since content is already offset by contentLeftInset)
        let labelView = NSTextField(labelWithString: label)
        labelView.font = DesignSystem.Typography.bodyMedium
        labelView.textColor = DesignSystem.Colors.text
        labelView.alignment = .left
        labelView.frame = NSRect(x: 0, y: 4, width: labelWidth, height: 20)
        labelView.autoresizingMask = [.maxXMargin]
        row.addSubview(labelView)

        // Switch on right (iOS-style toggle)
        let toggle = NSSwitch()
        toggle.state = isChecked ? .on : .off
        toggle.target = self
        toggle.action = action
        toggle.frame = NSRect(x: width - 60, y: 2, width: 50, height: 24)
        toggle.autoresizingMask = [.minXMargin]
        row.addSubview(toggle)

        // Store as NSControl (NSSwitch inherits from NSControl)
        checkbox = toggle

        return row
    }

    /// Create a horizontal popup button row (System Settings style)
    private func createPopupRow(
        label: String,
        popup: inout NSPopUpButton?,
        items: [String],
        selectedItem: String?,
        action: Selector,
        yPosition: CGFloat,
        width: CGFloat,
        labelWidth: CGFloat
    ) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: yPosition, width: width, height: 32))
        row.autoresizingMask = [.width]

        // Label on left (x=0 since content is already offset by contentLeftInset)
        let labelView = NSTextField(labelWithString: label)
        labelView.font = DesignSystem.Typography.bodyMedium
        labelView.textColor = DesignSystem.Colors.text
        labelView.alignment = .left
        labelView.frame = NSRect(x: 0, y: 6, width: labelWidth, height: 20)
        labelView.autoresizingMask = [.maxXMargin]
        row.addSubview(labelView)

        // Popup on right
        let pop = NSPopUpButton(frame: NSRect(x: width - 180 - DesignSystem.Spacing.lg, y: 3, width: 180, height: 25))
        pop.removeAllItems()
        pop.addItems(withTitles: items)
        if let selected = selectedItem {
            pop.selectItem(withTitle: selected)
        }
        pop.target = self
        pop.action = action
        pop.autoresizingMask = [.minXMargin]
        row.addSubview(pop)
        popup = pop

        return row
    }

    // MARK: - Section Box Helper

    /// Creates a visual section box with title and content
    /// - Parameter fillsRemainingHeight: If true, the section box will resize vertically with the window (for last section)
    private func createSectionBox(title: String, content: NSView, yPosition: inout CGFloat, panelWidth: CGFloat, fillsRemainingHeight: Bool = false) -> NSView {
        // System Settings style: title OUTSIDE box, content inside
        let contentHeight = content.bounds.height

        // Box height (no title inside)
        let boxHeight = DesignSystem.Layout.sectionBoxTopPadding +
                       contentHeight +
                       DesignSystem.Layout.sectionBoxBottomPadding

        // Total wrapper height: title + gap + box
        let totalHeight = DesignSystem.Layout.sectionBoxTitleHeight +
                         DesignSystem.Layout.sectionBoxTitleGap +
                         boxHeight

        // Wrapper view holds both title and box
        let wrapper = NSView(frame: NSRect(
            x: DesignSystem.Layout.sectionBoxHorizontalInset,
            y: yPosition,
            width: panelWidth - (DesignSystem.Layout.sectionBoxHorizontalInset * 2),
            height: totalHeight
        ))
        wrapper.autoresizingMask = fillsRemainingHeight ? [.width, .height] : [.width]

        // Section title (OUTSIDE the box, at top of wrapper)
        // Aligned with content inside box (same x offset)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignSystem.Typography.headlineMedium
        titleLabel.textColor = DesignSystem.Colors.text
        titleLabel.frame = NSRect(
            x: DesignSystem.Layout.contentLeftInset,
            y: totalHeight - DesignSystem.Layout.sectionBoxTitleHeight,
            width: wrapper.bounds.width - DesignSystem.Layout.contentLeftInset,
            height: DesignSystem.Layout.sectionBoxTitleHeight
        )
        // When filling remaining height, title stays at top (maxYMargin keeps distance from bottom flexible)
        titleLabel.autoresizingMask = fillsRemainingHeight ? [.width, .maxYMargin] : [.width]
        wrapper.addSubview(titleLabel)

        // Section box container (below title)
        let box = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: wrapper.bounds.width,
            height: boxHeight
        ))
        box.autoresizingMask = fillsRemainingHeight ? [.width, .height] : [.width]

        // System Settings exact colors (from Gemini analysis)
        // Background: #F2F2F2 @ 0.8 opacity, Border: #E5E5E5 @ 0.8 opacity
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(hex: "#F2F2F2").withAlphaComponent(0.8).cgColor
        box.layer?.cornerRadius = 8
        box.layer?.borderWidth = 0.5
        box.layer?.borderColor = NSColor(hex: "#E5E5E5").withAlphaComponent(0.8).cgColor

        // Position content inside box with padding
        content.frame.origin = NSPoint(x: DesignSystem.Layout.contentLeftInset, y: DesignSystem.Layout.sectionBoxBottomPadding)
        // Note: Don't override content's autoresizingMask - preserve what was set by caller
        box.addSubview(content)

        wrapper.addSubview(box)

        // Update y position for next section
        yPosition += totalHeight + DesignSystem.Layout.sectionBoxSpacing

        return wrapper
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
        let labelWidth: CGFloat = 200

        // Use proper content width calculation (accounts for all margins and padding)
        let contentWidth = DesignSystem.Layout.contentWidth(for: frame.width)

        // SECTION 1: Movement
        let movementContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 140))
        movementContent.autoresizingMask = [.width]
        var movementY: CGFloat = 0

        // Sensitivity Slider Row
        let sensitivityRow = createSliderRow(
            label: "Sensitivity",
            slider: &sensitivitySlider,
            valueLabel: &sensitivityLabel,
            value: Double(settings.mouseSensitivity),
            minValue: 0.5,
            maxValue: 20.0,
            formatString: "%.1fx",
            action: #selector(sensitivityChanged(_:)),
            yPosition: movementY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        movementContent.addSubview(sensitivityRow)
        movementY += 36

        // Scroll Speed Slider Row
        let scrollRow = createSliderRow(
            label: "Scroll Speed",
            slider: &scrollSensitivitySlider,
            valueLabel: &scrollSensitivityLabel,
            value: Double(settings.scrollSensitivity),
            minValue: 0.5,
            maxValue: 10.0,
            formatString: "%.1fx",
            action: #selector(scrollSensitivityChanged(_:)),
            yPosition: movementY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        movementContent.addSubview(scrollRow)
        movementY += 36

        // Invert Y-Axis Row
        let invertRow = createCheckboxRow(
            label: "Invert Y-Axis",
            checkbox: &invertYCheckbox,
            isChecked: settings.invertY,
            action: #selector(invertYChanged(_:)),
            yPosition: movementY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        movementContent.addSubview(invertRow)
        movementY += 32

        // Acceleration Row
        let accelRow = createCheckboxRow(
            label: "Acceleration",
            checkbox: &accelerationCheckbox,
            isChecked: settings.mouseAcceleration,
            action: #selector(accelerationChanged(_:)),
            yPosition: movementY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        movementContent.addSubview(accelRow)

        panel.addSubview(createSectionBox(title: "Movement", content: movementContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 2: Deadzone
        let deadzoneContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 72))
        deadzoneContent.autoresizingMask = [.width]
        var deadzoneY: CGFloat = 0

        // Left Stick Deadzone Row
        let leftDeadzoneRow = createSliderRow(
            label: "Left Stick",
            slider: &leftDeadzoneSlider,
            valueLabel: &leftDeadzoneLabel,
            value: Double(settings.leftStickDeadzone),
            minValue: 0.0,
            maxValue: 0.3,
            formatString: "%.0f%%",
            action: #selector(leftDeadzoneChanged(_:)),
            yPosition: deadzoneY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        // Custom formatter for percentage
        leftDeadzoneLabel?.stringValue = String(format: "%.0f%%", settings.leftStickDeadzone * 100)
        deadzoneContent.addSubview(leftDeadzoneRow)
        deadzoneY += 36

        // Right Stick Deadzone Row
        let rightDeadzoneRow = createSliderRow(
            label: "Right Stick",
            slider: &rightDeadzoneSlider,
            valueLabel: &rightDeadzoneLabel,
            value: Double(settings.rightStickDeadzone),
            minValue: 0.0,
            maxValue: 0.3,
            formatString: "%.0f%%",
            action: #selector(rightDeadzoneChanged(_:)),
            yPosition: deadzoneY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        // Custom formatter for percentage
        rightDeadzoneLabel?.stringValue = String(format: "%.0f%%", settings.rightStickDeadzone * 100)
        deadzoneContent.addSubview(rightDeadzoneRow)

        panel.addSubview(createSectionBox(title: "Deadzone", content: deadzoneContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 3: Stick Functions
        let stickFunctionContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 68))
        stickFunctionContent.autoresizingMask = [.width]
        var stickFunctionY: CGFloat = 0

        // Left Stick Function Row
        let leftStickRow = createPopupRow(
            label: "Left Stick",
            popup: &leftStickFunctionPopup,
            items: ["Mouse", "Scroll", "Arrow Keys", "WASD", "Disabled"],
            selectedItem: profileManager.activeProfile.leftStickFunction.rawValue,
            action: #selector(leftStickFunctionChanged(_:)),
            yPosition: stickFunctionY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        stickFunctionContent.addSubview(leftStickRow)
        stickFunctionY += 34

        // Right Stick Function Row
        let rightStickRow = createPopupRow(
            label: "Right Stick",
            popup: &rightStickFunctionPopup,
            items: ["Mouse", "Scroll", "Arrow Keys", "WASD", "Disabled"],
            selectedItem: profileManager.activeProfile.rightStickFunction.rawValue,
            action: #selector(rightStickFunctionChanged(_:)),
            yPosition: stickFunctionY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        stickFunctionContent.addSubview(rightStickRow)

        panel.addSubview(createSectionBox(title: "Stick Functions", content: stickFunctionContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 4: Sticky Mouse
        let stickyMouseContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 146))
        stickyMouseContent.autoresizingMask = [.width]
        var stickyMouseY: CGFloat = 0

        // Enable Sticky Mouse Row
        let enableRow = createCheckboxRow(
            label: "Enable sticky mouse",
            checkbox: &stickyMouseCheckbox,
            isChecked: StickyMouseManager.shared.isEnabled,
            action: #selector(stickyMouseToggled(_:)),
            yPosition: stickyMouseY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        stickyMouseContent.addSubview(enableRow)
        stickyMouseY += 32

        // Strength Row
        let strengthRow = createPopupRow(
            label: "Strength",
            popup: &stickyStrengthPopup,
            items: ["Weak", "Medium", "Strong"],
            selectedItem: StickyMouseManager.shared.magneticStrength.description,
            action: #selector(stickyStrengthChanged(_:)),
            yPosition: stickyMouseY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        stickyMouseContent.addSubview(strengthRow)
        stickyMouseY += 34

        // Show Visual Overlay Row
        let overlayRow = createCheckboxRow(
            label: "Show visual overlay",
            checkbox: &stickyOverlayCheckbox,
            isChecked: StickyMouseManager.shared.showVisualOverlay,
            action: #selector(stickyOverlayToggled(_:)),
            yPosition: stickyMouseY,
            width: contentWidth,
            labelWidth: labelWidth
        )
        stickyMouseContent.addSubview(overlayRow)
        stickyMouseY += 36

        // Info text (full-width below controls)
        let stickyInfoLabel = NSTextField(wrappingLabelWithString: "Slows cursor near buttons and text fields, making them easier to click. Toggle with L button, adjust strength with ZL+X.")
        stickyInfoLabel.font = DesignSystem.Typography.bodyMedium
        stickyInfoLabel.textColor = DesignSystem.Colors.secondaryText
        stickyInfoLabel.alignment = .left
        stickyInfoLabel.frame = NSRect(x: 0, y: stickyMouseY, width: contentWidth, height: 36)
        stickyInfoLabel.autoresizingMask = [.width]
        stickyMouseContent.addSubview(stickyInfoLabel)

        panel.addSubview(createSectionBox(title: "Sticky Mouse", content: stickyMouseContent, yPosition: &y, panelWidth: frame.width))

        // Debug mode toggle (only in debug builds)
        #if DEBUG
        let debugContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 60))
        debugContent.autoresizingMask = [.width]
        var debugY: CGFloat = 0

        // Debug Mode Row
        let debugRow = createCheckboxRow(
            label: "Debug Mode (skip system input events)",
            checkbox: &debugModeCheckbox,
            isChecked: inputController.debugMode,
            action: #selector(debugModeChanged(_:)),
            yPosition: debugY,
            width: contentWidth,
            labelWidth: 280
        )
        debugContent.addSubview(debugRow)
        debugY += 32

        // Info text
        let debugInfo = NSTextField(wrappingLabelWithString: "DEBUG MODE: Input events are logged but not sent to the system.")
        debugInfo.font = DesignSystem.Typography.bodyMedium
        debugInfo.textColor = DesignSystem.Colors.warning
        debugInfo.alignment = .left
        debugInfo.frame = NSRect(x: 0, y: debugY, width: contentWidth, height: 20)
        debugInfo.autoresizingMask = [.width]
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

        let contentWidth = DesignSystem.Layout.contentWidth(for: frame.width)
        var y: CGFloat = DesignSystem.Spacing.lg  // Start from top

        // SECTION 1: Profile Selection (8pt grid aligned)
        let profileContentHeight: CGFloat = 32 + 32 + 24  // popup row + buttons row + description (all 8pt multiples)
        let profileContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: profileContentHeight))
        var profileY: CGFloat = 0

        // Profile selection dropdown using helper
        let profileRow = createPopupRow(
            label: "Button Profile",
            popup: &keyboardPresetPopup,
            items: profileManager.getProfileNames(),
            selectedItem: profileManager.activeProfile.name,
            action: #selector(profileSelectionChanged(_:)),
            yPosition: profileY,
            width: profileContent.bounds.width,
            labelWidth: 150
        )
        profileContent.addSubview(profileRow)
        profileY += 32

        // Action buttons row
        let buttonsRow = NSView(frame: NSRect(x: 0, y: profileY, width: profileContent.bounds.width, height: 32))

        let resetButton = NSButton(frame: NSRect(x: 0, y: 2, width: 90, height: 25))
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetProfileToDefaults(_:))
        buttonsRow.addSubview(resetButton)

        let cloneButton = NSButton(frame: NSRect(x: 100, y: 2, width: 90, height: 25))
        cloneButton.title = "Clone"
        cloneButton.bezelStyle = .rounded
        cloneButton.target = self
        cloneButton.action = #selector(cloneProfile(_:))
        buttonsRow.addSubview(cloneButton)

        profileContent.addSubview(buttonsRow)
        profileY += 32

        // Profile description
        let descLabel = NSTextField(wrappingLabelWithString: profileManager.activeProfile.description)
        descLabel.font = DesignSystem.Typography.bodyMedium
        descLabel.textColor = DesignSystem.Colors.secondaryText
        descLabel.frame = NSRect(x: 0, y: profileY, width: profileContent.bounds.width, height: 24)
        descLabel.autoresizingMask = [.width]
        profileContent.addSubview(descLabel)

        panel.addSubview(createSectionBox(title: "Profile", content: profileContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 2: Button Mapping - rows added directly to content view
        var rowY: CGFloat = 0

        // Helper to create button row (8pt grid aligned)
        let mappingContent = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1000))  // Height set later
        mappingContent.autoresizingMask = [.width]

        let createRow: (String, ButtonAction, Int) -> Void = { buttonName, action, tag in
            let nameLabel = NSTextField(labelWithString: buttonName)
            nameLabel.frame = NSRect(x: 0, y: rowY, width: 100, height: 24)
            nameLabel.font = DesignSystem.Typography.bodyMedium
            nameLabel.textColor = DesignSystem.Colors.text
            mappingContent.addSubview(nameLabel)

            let mappingLabel = NSTextField(labelWithString: action.description)
            mappingLabel.frame = NSRect(x: 130, y: rowY, width: 250, height: 24)
            mappingLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            mappingLabel.textColor = DesignSystem.Colors.secondaryText
            mappingLabel.autoresizingMask = [.width]
            mappingContent.addSubview(mappingLabel)

            let editBtn = NSButton(frame: NSRect(x: contentWidth - 80, y: rowY, width: 70, height: 24))
            editBtn.title = "Edit"
            editBtn.bezelStyle = .rounded
            editBtn.font = DesignSystem.Typography.bodyMedium
            editBtn.tag = tag
            editBtn.target = self
            editBtn.action = #selector(self.editButtonMapping(_:))
            editBtn.autoresizingMask = [.minXMargin]
            mappingContent.addSubview(editBtn)

            rowY += 32
        }

        let createSectionHeader: (String) -> Void = { title in
            let header = NSTextField(labelWithString: title)
            header.frame = NSRect(x: 0, y: rowY, width: 250, height: 24)
            header.font = DesignSystem.Typography.headlineMedium
            header.textColor = DesignSystem.Colors.text
            mappingContent.addSubview(header)
            rowY += 32
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

        // Set final content height based on actual content
        mappingContent.frame = NSRect(x: 0, y: 0, width: contentWidth, height: rowY + 8)

        panel.addSubview(createSectionBox(title: "Button Mapping", content: mappingContent, yPosition: &y, panelWidth: frame.width))

        // Set panel height based on content
        let panelHeight = y + DesignSystem.Spacing.lg
        panel.frame = NSRect(x: 0, y: 0, width: frame.width, height: panelHeight)

        // Wrap in scroll view for vertical scrolling (like Mouse and Voice tabs)
        let scrollView = NSScrollView(frame: frame)
        scrollView.documentView = panel
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        return scrollView
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
        let permissionsContent = NSView(frame: NSRect(x: 0, y: 0, width: DesignSystem.Layout.contentWidth(for: frame.width), height: hasPermissions ? 20 : 50))
        var permissionsY: CGFloat = 0

        // Permission Status
        let permissionLabel = NSTextField(labelWithString: hasPermissions ? "Permissions Granted" : "Permissions Required")
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
        let settingsContent = NSView(frame: NSRect(x: 0, y: 0, width: DesignSystem.Layout.contentWidth(for: frame.width), height: 62))
        var settingsY: CGFloat = 0

        // Language Selection using helper
        let languageCodes = [
            "en-US", "en-GB", "en-AU", "es-ES", "fr-FR", "de-DE", "it-IT",
            "ja-JP", "zh-CN", "zh-TW", "ko-KR", "pt-PT", "ru-RU", "ar-SA"
        ]
        let languageNames = [
            "English (US)", "English (UK)", "English (Australia)",
            "Spanish", "French", "German", "Italian",
            "Japanese", "Chinese (Simplified)", "Chinese (Traditional)",
            "Korean", "Portuguese", "Russian", "Arabic"
        ]
        let selectedLanguage = languageNames[languageCodes.firstIndex(of: settings.voiceLanguage) ?? 0]

        let languageRow = createPopupRow(
            label: "Language",
            popup: &voiceLanguagePopup,
            items: languageNames,
            selectedItem: selectedLanguage,
            action: #selector(languageChanged),
            yPosition: settingsY,
            width: settingsContent.bounds.width,
            labelWidth: 150
        )
        settingsContent.addSubview(languageRow)
        settingsY += 32

        // Status - use horizontal row style
        let statusRow = NSView(frame: NSRect(x: 0, y: settingsY, width: settingsContent.bounds.width, height: 30))

        let statusLabel = NSTextField(labelWithString: "Status")
        statusLabel.font = DesignSystem.Typography.bodyMedium
        statusLabel.textColor = DesignSystem.Colors.text
        statusLabel.alignment = .left
        statusLabel.frame = NSRect(x: 0, y: 5, width: 150, height: 20)
        statusLabel.autoresizingMask = [.maxXMargin]
        statusRow.addSubview(statusLabel)

        voiceStatusLabel = NSTextField(labelWithString: "Ready")
        voiceStatusLabel.font = DesignSystem.Typography.bodyMedium
        voiceStatusLabel.textColor = DesignSystem.Colors.secondaryText
        voiceStatusLabel.alignment = .right
        voiceStatusLabel.frame = NSRect(x: settingsContent.bounds.width - 180 - DesignSystem.Spacing.lg, y: 5, width: 180, height: 20)
        voiceStatusLabel.autoresizingMask = [.minXMargin]
        statusRow.addSubview(voiceStatusLabel)

        settingsContent.addSubview(statusRow)

        panel.addSubview(createSectionBox(title: "Settings", content: settingsContent, yPosition: &y, panelWidth: frame.width))

        // SECTION 3: How to Use
        let howToContent = NSView(frame: NSRect(x: 0, y: 0, width: DesignSystem.Layout.contentWidth(for: frame.width), height: 135))
        var howToY: CGFloat = 12

        // Instructions
        let instructionsLabel = NSTextField(wrappingLabelWithString: "1. Hold ZL + ZR on your Joy-Con to activate voice input\n\n2. Speak naturally in your selected language\n\n3. Release ZL + ZR to type your words automatically")
        instructionsLabel.font = DesignSystem.Typography.bodyMedium
        instructionsLabel.textColor = DesignSystem.Colors.text
        instructionsLabel.frame = NSRect(x: 0, y: howToY, width: frame.width - 120, height: 75)
        instructionsLabel.autoresizingMask = [.width]  // Grow with window
        howToContent.addSubview(instructionsLabel)
        howToY += 80

        // Info text
        let infoLabel = NSTextField(wrappingLabelWithString: "Voice input converts your speech to text and types it automatically. Perfect for hands-free typing.")
        infoLabel.font = DesignSystem.Typography.bodyMedium
        infoLabel.textColor = DesignSystem.Colors.secondaryText
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
        log("Debug mode \(status) - input events will \(inputController.debugMode ? "NOT" : "") be sent to system")

        // Update header label
        let debugSuffix = inputController.debugMode ? " [DEBUG MODE]" : ""
        if controllers.isEmpty {
            connectionLabel.stringValue = "No Joy-Con detected\(debugSuffix)"
        } else {
            let names = controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
            connectionLabel.stringValue = "Connected: \(names.joined(separator: " + "))\(debugSuffix)"
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
        log("Profile changed to: \(profileName)")

        // Refresh the keyboard config panel to show new mapping
        refreshKeyboardPanel()
    }

    private func refreshKeyboardPanel() {
        // Recreate the keyboard tab content with correct dimensions
        let newKeyboardView = createKeyboardConfigPanel(frame: tabView.bounds)
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

        log("Editing \(buttonName)...")

        // Create mapping editor view
        let editorView = ButtonMappingEditor(
            buttonName: buttonName,
            currentMapping: currentAction.description
        )

        editorView.onActionSelected = { [weak self] action in
            self?.updateButtonAction(forTag: tag, newAction: action)
            self?.log("Updated \(buttonName) -> \(action.description)")
            self?.refreshKeyboardPanel()
            // Close the window
            self?.keyCaptureWindow?.close()
            self?.keyCaptureWindow = nil
        }

        editorView.onCancelled = { [weak self] in
            self?.log("Cancelled editing")
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
            self.log("Updated \(buttonName) -> \(newAction.description)")

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
                    self?.log("Voice input permissions granted!")
                    self?.voiceManager.isAuthorized = true
                    // Recreate the voice panel to update UI
                    guard let self = self else { return }
                    let newVoiceView = self.createVoiceConfigPanel(
                        frame: NSRect(x: 0, y: 0, width: self.view.bounds.width - 20, height: 300)
                    )
                    self.voiceTabViewItem.view = newVoiceView
                } else {
                    self?.log("Voice input permissions denied")
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
            log("Voice language changed to: \(sender.titleOfSelectedItem ?? languageCode)")
        }
    }

    @objc private func showConnectionHelp() {
        let alert = NSAlert()
        alert.messageText = "How to Connect Joy-Con Controllers"
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
        inputController.startMouseUpdates()
    }

    private func setupVoiceManager() {
        // The VoiceInputManager now initializes its own authorization state.
        // We just log the status on startup.
        if voiceManager.isAuthorized {
            log("Voice permissions already granted")
        } else {
            log("Voice permissions not yet granted")
        }

        voiceManager.onLog = { [weak self] message in
            self?.log(message)
        }
        voiceManager.onTranscriptUpdate = { [weak self] transcript in
            self?.log("[Voice] \(transcript)")
            self?.voiceStatusLabel.stringValue = "Status: Listening... \"\(transcript)\""
        }
        voiceManager.onFinalTranscript = { [weak self] transcript in
            guard let self = self, !transcript.isEmpty else { return }
            self.log("[Keyboard] Typing final transcript: \(transcript)")
            InputController.shared.typeText(transcript)
            // Add space after voice input for easier continuous typing
            InputController.shared.typeText(" ")
            self.voiceStatusLabel.stringValue = "Status: Typed"
        }
        voiceManager.onError = { [weak self] error in
            self?.log("Voice Error: \(error)")
            self?.voiceStatusLabel.stringValue = "Status: Error"
        }
    }

    // MARK: - Logging

    func log(_ message: String) {
        NSLog("%@", message)
    }

    // MARK: - Controller Connection (JoyConSwift)

    func joyConConnected(_ controller: Controller) {
        controllers.append(controller)

        let name = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
        log("Controller Connected: \(name)")

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
        log("Controller Disconnected: \(name)")
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
                self.connectionLabel.stringValue = "No Joy-Con detected\(debugSuffix)"
                self.connectionLabel.textColor = NSColor.secondaryLabelColor
                self.batteryProgressView.subviews.forEach { $0.removeFromSuperview() }
                self.ledIndicator.stringValue = ""
                self.helpButton?.isHidden = false  // Show help button when no controller
            } else {
                let names = self.controllers.map { $0.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)" }
                self.connectionLabel.stringValue = "Connected: \(names.joined(separator: " + "))\(debugSuffix)"
                self.connectionLabel.textColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

                // Update battery display
                self.updateBatteryDisplay()

                // LED indicator
                let count = self.controllers.count
                self.ledIndicator.stringValue = "LED \(count)"
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
            labelField.font = DesignSystem.Typography.bodyMedium
            labelField.textColor = DesignSystem.Colors.tertiaryText
            labelField.frame = NSRect(x: xOffset, y: 8, width: 15, height: 14)
            container.addSubview(labelField)
            xOffset += 18
        }

        let percentage = batteryPercentage(for: controller.battery)
        let color = batteryColor(for: controller.battery)

        if percentage >= 0 {
            // Charging indicator (remove emoji, use text)
            if controller.isCharging {
                let chargeLabel = NSTextField(labelWithString: "+")
                chargeLabel.font = DesignSystem.Typography.bodyMedium
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
            percentLabel.font = DesignSystem.Typography.bodyMedium
            percentLabel.textColor = color
            percentLabel.frame = NSRect(x: xOffset, y: 8, width: 35, height: 14)
            container.addSubview(percentLabel)
        } else {
            // Unknown battery state
            let unknownLabel = NSTextField(labelWithString: "---")
            unknownLabel.font = DesignSystem.Typography.bodyMedium
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
            log("Battery Critical! Please charge your Joy-Con soon")
        }
        if newState == .low && oldState == .medium {
            log("Battery Low (25%)")
        }
        if newState == .full && oldState != .unknown {
            log("Battery Full!")
        }
    }

    private func handleChargingChange(isCharging: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateBatteryDisplay()
        }
        log(isCharging ? "Charging started" : "Charging stopped")
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
            let profile = self.profileManager.activeProfile

            switch button {
            case .A:
                self.executeButtonRelease(profile.buttonA, buttonName: "A")
            case .B:
                self.executeButtonRelease(profile.buttonB, buttonName: "B")
            case .X:
                self.executeButtonRelease(profile.buttonX, buttonName: "X")
            case .Y:
                self.executeButtonRelease(profile.buttonY, buttonName: "Y")
            case .L:
                self.removeModifier(profile.bumperL)
                self.updateSpecialMode()
            case .R:
                self.removeModifier(profile.bumperR)
                self.updateSpecialMode()
            case .ZL:
                // Execute ZL action only if it was NOT used in a chord
                if !self.wasZLInChord {
                    self.executeButtonAction(profile.triggerZL, buttonName: "ZL")
                }
                self.isZLHeld = false
                self.wasZLInChord = false
                self.updateSpecialMode()
            case .ZR:
                // Execute ZR action only if it was NOT used in a chord
                if !self.wasZRInChord {
                    self.executeButtonAction(profile.triggerZR, buttonName: "ZR")
                }
                self.isZRHeld = false
                self.wasZRInChord = false
                self.updateSpecialMode()
            case .Up:
                self.executeButtonRelease(profile.dpadUp, buttonName: "D-Up")
            case .Down:
                self.executeButtonRelease(profile.dpadDown, buttonName: "D-Down")
            case .Left:
                self.executeButtonRelease(profile.dpadLeft, buttonName: "D-Left")
            case .Right:
                self.executeButtonRelease(profile.dpadRight, buttonName: "D-Right")
            case .Minus:
                self.executeButtonRelease(profile.buttonMinus, buttonName: "Minus")
                self.isMinusHeld = false
            case .Plus:
                if self.isPlusHeldForDriftMarking {
                    self.isPlusHeldForDriftMarking = false
                    self.log("🚩 Drift marking stopped")
                } else {
                    self.executeButtonRelease(profile.buttonPlus, buttonName: "Plus")
                }
            case .Home:
                self.executeButtonRelease(profile.buttonHome, buttonName: "Home")
            case .Capture:
                self.executeButtonRelease(profile.buttonCapture, buttonName: "Capture")
            case .LeftSL, .RightSL:
                self.executeButtonRelease(profile.buttonSL, buttonName: "SL")
            case .LeftSR, .RightSR:
                self.executeButtonRelease(profile.buttonSR, buttonName: "SR")
            case .LStick:
                self.executeButtonRelease(profile.leftStickClick, buttonName: "L-Stick")
            case .RStick:
                self.executeButtonRelease(profile.rightStickClick, buttonName: "R-Stick")
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

        log("   Handlers configured")
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

    /// Handle button release for actions that need up/down tracking (like mouseClick for drag)
    private func executeButtonRelease(_ action: ButtonAction, buttonName: String) {
        switch action {
        case .mouseClick:
            log("🕹️ \(buttonName) → Mouse Up")
            inputController.leftMouseUp(modifiers: modifiers)
        default:
            break  // Other actions don't need release handling
        }
    }

    private func executeButtonAction(_ action: ButtonAction, buttonName: String) {
        switch action {
        case .mouseClick:
            log("🕹️ \(buttonName) → Mouse Down")
            inputController.leftMouseDown(modifiers: modifiers)
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
            log("Quick Switch -> Profile \(profileIndex): \(profileManager.activeProfile.name)")

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
            log("Voice input activated - speak now")
            voiceManager.startListening()
            voiceStatusLabel.stringValue = "Status: Listening..."

        case .precision:
            log("Precision mode activated")
            inputController.setPrecisionMode(true)

        case .none:
            if oldMode == .voice {
                log("Voice mode ending - waiting for final transcript...")
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
