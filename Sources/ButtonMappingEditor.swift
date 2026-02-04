import Cocoa
import Carbon.HIToolbox

/// Simplified editor for button mappings with dropdown presets and key capture
class ButtonMappingEditor: NSView {

    private let presetPopup: NSPopUpButton
    private let captureField: NSTextField
    private let applyButton: NSButton
    private let cancelButton: NSButton

    private var isCapturing = false
    private var eventMonitor: Any?
    private var capturedAction: ButtonAction?

    var onActionSelected: ((ButtonAction) -> Void)?
    var onCancelled: (() -> Void)?

    // All presets in one list
    private static let presets: [(String, ButtonAction)] = [
        // Common actions
        ("None", .none),
        ("Click", .mouseClick),
        ("Right Click", .rightClick),
        ("Enter", .pressEnter),
        ("Escape", .pressEscape),
        ("Tab", .pressTab),
        ("Space", .pressSpace),
        ("Backspace", .pressBackspace),
        ("Voice Input", .voiceInput),
        ("Mission Control", .missionControl),
        // Separator will be added in popup
        ("───────────", .none), // visual separator
        // System shortcuts
        ("⌘⇥ App Switch", .keyCombo(keyCode: UInt16(kVK_Tab), command: true, shift: false, option: false, control: false, description: "⌘⇥ App Switch")),
        ("⌘⇧⇥ Prev App", .keyCombo(keyCode: UInt16(kVK_Tab), command: true, shift: true, option: false, control: false, description: "⌘⇧⇥ Prev App")),
        ("⌘⇧[ Prev Tab", .keyCombo(keyCode: UInt16(kVK_ANSI_LeftBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧[ Prev Tab")),
        ("⌘⇧] Next Tab", .keyCombo(keyCode: UInt16(kVK_ANSI_RightBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧] Next Tab")),
        ("⌘⇧3 Screenshot", .keyCombo(keyCode: UInt16(kVK_ANSI_3), command: true, shift: true, option: false, control: false, description: "⌘⇧3 Screenshot")),
        ("⌘⇧4 Area Shot", .keyCombo(keyCode: UInt16(kVK_ANSI_4), command: true, shift: true, option: false, control: false, description: "⌘⇧4 Area Shot")),
        ("⌘⇧5 Screen Rec", .keyCombo(keyCode: UInt16(kVK_ANSI_5), command: true, shift: true, option: false, control: false, description: "⌘⇧5 Screen Rec")),
    ]

    init(buttonName: String, currentMapping: String) {
        presetPopup = NSPopUpButton()
        captureField = NSTextField()
        applyButton = NSButton(title: "Apply", target: nil, action: nil)
        cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

        super.init(frame: .zero)
        setupUI(buttonName: buttonName, currentMapping: currentMapping)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopCapture()
    }

    private func setupUI(buttonName: String, currentMapping: String) {
        // Container box with shadow
        let container = NSBox()
        container.boxType = .custom
        container.isTransparent = false
        container.borderWidth = 1
        container.borderColor = DesignSystem.Colors.separator
        container.cornerRadius = DesignSystem.CornerRadius.large
        container.fillColor = DesignSystem.Colors.secondaryBackground
        container.contentViewMargins = NSSize(width: DesignSystem.Spacing.lg, height: DesignSystem.Spacing.md)
        container.wantsLayer = true
        let shadowConfig = DesignSystem.Shadow.elevated
        container.shadow = NSShadow()
        container.shadow?.shadowColor = shadowConfig.color.withAlphaComponent(CGFloat(shadowConfig.opacity))
        container.shadow?.shadowBlurRadius = shadowConfig.radius
        container.shadow?.shadowOffset = shadowConfig.offset

        // Title section
        let titleLabel = NSTextField(labelWithString: "Edit \(buttonName)")
        titleLabel.font = DesignSystem.Typography.headlineMedium
        titleLabel.textColor = DesignSystem.Colors.text
        titleLabel.alignment = .center

        // Current mapping in a subtle box
        let currentBox = NSBox()
        currentBox.boxType = .custom
        currentBox.isTransparent = false
        currentBox.borderWidth = 0
        currentBox.cornerRadius = DesignSystem.CornerRadius.small
        currentBox.fillColor = DesignSystem.Colors.background
        currentBox.contentViewMargins = NSSize(width: DesignSystem.Spacing.sm, height: DesignSystem.Spacing.xxs)

        let currentLabel = NSTextField(labelWithString: "Current: \(currentMapping)")
        currentLabel.font = DesignSystem.Typography.bodySmall
        currentLabel.textColor = DesignSystem.Colors.secondaryText
        currentLabel.alignment = .center
        currentBox.contentView = currentLabel

        // Preset dropdown
        let presetLabel = NSTextField(labelWithString: "Preset:")
        presetLabel.font = DesignSystem.Typography.bodyMedium

        presetPopup.removeAllItems()
        for (index, (name, _)) in Self.presets.enumerated() {
            if name.hasPrefix("───") {
                presetPopup.menu?.addItem(NSMenuItem.separator())
            } else {
                presetPopup.addItem(withTitle: name)
                presetPopup.lastItem?.tag = index
            }
        }
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)

        // Select current if it matches a preset
        if let matchIndex = Self.presets.firstIndex(where: { $0.0 == currentMapping }) {
            presetPopup.selectItem(withTag: matchIndex)
        }

        let presetRow = NSStackView(views: [presetLabel, presetPopup])
        presetRow.orientation = .horizontal
        presetRow.spacing = DesignSystem.Spacing.xs

        // Separator
        let separator = NSTextField(labelWithString: "─── or capture custom key ───")
        separator.font = DesignSystem.Typography.caption
        separator.textColor = DesignSystem.Colors.tertiaryText
        separator.alignment = .center

        // Capture field
        captureField.isEditable = false
        captureField.isSelectable = false
        captureField.isBezeled = true
        captureField.bezelStyle = .roundedBezel
        captureField.alignment = .center
        captureField.font = DesignSystem.Typography.bodyMedium
        captureField.stringValue = "Click here, then press any key..."
        captureField.textColor = DesignSystem.Colors.secondaryText

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(captureClicked))
        captureField.addGestureRecognizer(clickGesture)

        // Buttons
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(applyPressed)

        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)

        let buttonRow = NSStackView(views: [cancelButton, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = DesignSystem.Spacing.sm

        // Main stack
        let mainStack = NSStackView(views: [
            titleLabel,
            currentBox,
            presetRow,
            separator,
            captureField,
            buttonRow
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = DesignSystem.Spacing.sm
        mainStack.alignment = .centerX

        container.contentView = mainStack
        addSubview(container)

        // Constraints
        container.translatesAutoresizingMaskIntoConstraints = false
        captureField.translatesAutoresizingMaskIntoConstraints = false
        presetPopup.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: 280),
            captureField.widthAnchor.constraint(equalToConstant: 220),
            presetPopup.widthAnchor.constraint(equalToConstant: 180),
        ])
    }

    @objc private func presetChanged() {
        // Clear any captured key when preset is selected
        capturedAction = nil
        captureField.stringValue = "Click here, then press any key..."
        captureField.textColor = NSColor.secondaryLabelColor
        stopCapture()
    }

    @objc private func captureClicked() {
        startCapture()
    }

    private func startCapture() {
        isCapturing = true
        captureField.stringValue = "Press any key..."
        captureField.textColor = DesignSystem.Colors.info

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isCapturing else { return event }

            // Escape cancels capture
            if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty {
                self.stopCapture()
                self.captureField.stringValue = "Click here, then press any key..."
                self.captureField.textColor = DesignSystem.Colors.secondaryText
                self.capturedAction = nil
                return nil
            }

            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let key = CapturedKey(keyCode: event.keyCode, modifiers: modifiers)

            self.stopCapture()
            self.captureField.stringValue = "Captured: \(key.description)"
            self.captureField.textColor = DesignSystem.Colors.success

            self.capturedAction = .keyCombo(
                keyCode: event.keyCode,
                command: modifiers.contains(.command),
                shift: modifiers.contains(.shift),
                option: modifiers.contains(.option),
                control: modifiers.contains(.control),
                description: key.description
            )

            // Select "None" when custom key is captured
            self.presetPopup.selectItem(withTag: 0)

            return nil
        }
    }

    private func stopCapture() {
        isCapturing = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func applyPressed() {
        stopCapture()

        // Prefer captured action, fall back to preset
        if let captured = capturedAction {
            onActionSelected?(captured)
        } else if let selectedTag = presetPopup.selectedItem?.tag,
                  selectedTag >= 0 && selectedTag < Self.presets.count {
            let (_, action) = Self.presets[selectedTag]
            onActionSelected?(action)
        }
    }

    @objc private func cancelPressed() {
        stopCapture()
        onCancelled?()
    }
}
