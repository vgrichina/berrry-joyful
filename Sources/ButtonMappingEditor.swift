import Cocoa
import Carbon.HIToolbox

/// Combined editor for button mappings with presets and key capture
class ButtonMappingEditor: NSView {

    private let containerBox: NSBox
    private let titleLabel: NSTextField
    private var captureLabel: NSTextField!
    private var captureStatusLabel: NSTextField!

    private var isCapturing = false
    private var eventMonitor: Any?
    private var flagsMonitor: Any?

    var onActionSelected: ((ButtonAction) -> Void)?
    var onCancelled: (() -> Void)?

    // System shortcuts that can't be captured
    private static let systemShortcuts: [(String, ButtonAction)] = [
        ("⌘⇥ App Switch", .keyCombo(keyCode: UInt16(kVK_Tab), command: true, shift: false, option: false, control: false, description: "⌘⇥ App Switch")),
        ("⌘⇧⇥ Prev App", .keyCombo(keyCode: UInt16(kVK_Tab), command: true, shift: true, option: false, control: false, description: "⌘⇧⇥ Prev App")),
        ("⌘⇧[ Prev Tab", .keyCombo(keyCode: UInt16(kVK_ANSI_LeftBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧[ Prev Tab")),
        ("⌘⇧] Next Tab", .keyCombo(keyCode: UInt16(kVK_ANSI_RightBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧] Next Tab")),
        ("⌘⇧3 Screenshot", .keyCombo(keyCode: UInt16(kVK_ANSI_3), command: true, shift: true, option: false, control: false, description: "⌘⇧3 Screenshot")),
        ("⌘⇧4 Area Shot", .keyCombo(keyCode: UInt16(kVK_ANSI_4), command: true, shift: true, option: false, control: false, description: "⌘⇧4 Area Shot")),
        ("⌘⇧5 Screen Rec", .keyCombo(keyCode: UInt16(kVK_ANSI_5), command: true, shift: true, option: false, control: false, description: "⌘⇧5 Screen Rec")),
    ]

    // Common actions
    private static let commonActions: [(String, ButtonAction)] = [
        ("None", .none),
        ("Click", .mouseClick),
        ("Right Click", .rightClick),
        ("Enter", .pressEnter),
        ("Escape", .pressEscape),
        ("Tab", .pressTab),
        ("Space", .pressSpace),
        ("Backspace", .pressBackspace),
        ("Voice Input", .voiceInput),
    ]

    init(buttonName: String, currentMapping: String) {
        containerBox = NSBox()
        titleLabel = NSTextField(labelWithString: "\(buttonName) - Edit Mapping")

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
        // Container
        containerBox.boxType = .custom
        containerBox.borderType = .lineBorder
        containerBox.borderWidth = 2
        containerBox.borderColor = NSColor.systemBlue
        containerBox.cornerRadius = 8
        containerBox.fillColor = NSColor.controlBackgroundColor
        containerBox.contentViewMargins = NSSize(width: 20, height: 20)

        // Title
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.alignment = .center

        // Current mapping
        let currentLabel = NSTextField(labelWithString: "Current: \(currentMapping)")
        currentLabel.font = NSFont.systemFont(ofSize: 11)
        currentLabel.textColor = NSColor.secondaryLabelColor
        currentLabel.alignment = .center

        // System shortcuts section
        let systemHeader = NSTextField(labelWithString: "System Shortcuts (can't capture)")
        systemHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        systemHeader.textColor = NSColor.secondaryLabelColor

        let systemButtonsStack = createButtonGrid(items: Self.systemShortcuts)

        // Common actions section
        let commonHeader = NSTextField(labelWithString: "Common Actions")
        commonHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        commonHeader.textColor = NSColor.secondaryLabelColor

        let commonButtonsStack = createButtonGrid(items: Self.commonActions)

        // Capture section
        let captureHeader = NSTextField(labelWithString: "Or Capture Custom Key")
        captureHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        captureHeader.textColor = NSColor.secondaryLabelColor

        let captureBox = NSBox()
        captureBox.boxType = .custom
        captureBox.borderType = .lineBorder
        captureBox.borderWidth = 1
        captureBox.borderColor = NSColor.separatorColor
        captureBox.cornerRadius = 6
        captureBox.fillColor = NSColor.textBackgroundColor
        captureBox.contentViewMargins = NSSize(width: 15, height: 10)

        captureLabel = NSTextField(labelWithString: "🎹 Click here, then press any key...")
        captureLabel.font = NSFont.systemFont(ofSize: 12)
        captureLabel.alignment = .center
        captureLabel.isSelectable = false

        captureStatusLabel = NSTextField(labelWithString: "")
        captureStatusLabel.font = NSFont.boldSystemFont(ofSize: 12)
        captureStatusLabel.textColor = NSColor.systemGreen
        captureStatusLabel.alignment = .center
        captureStatusLabel.isHidden = true

        let captureStack = NSStackView(views: [captureLabel, captureStatusLabel])
        captureStack.orientation = .vertical
        captureStack.spacing = 5
        captureBox.contentView = captureStack

        // Make capture box clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(startCaptureClicked))
        captureBox.addGestureRecognizer(clickGesture)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancelButton.bezelStyle = .rounded

        // Main stack
        let mainStack = NSStackView(views: [
            titleLabel,
            currentLabel,
            createSpacer(height: 10),
            systemHeader,
            systemButtonsStack,
            createSpacer(height: 10),
            commonHeader,
            commonButtonsStack,
            createSpacer(height: 10),
            captureHeader,
            captureBox,
            createSpacer(height: 15),
            cancelButton
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 8
        mainStack.alignment = .centerX

        containerBox.contentView = mainStack
        addSubview(containerBox)

        containerBox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerBox.topAnchor.constraint(equalTo: topAnchor),
            containerBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerBox.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerBox.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func createButtonGrid(items: [(String, ButtonAction)]) -> NSStackView {
        let rows: [[NSView]] = items.chunked(into: 3).map { rowItems in
            rowItems.map { (title, action) in
                let button = NSButton(title: title, target: self, action: #selector(presetButtonClicked(_:)))
                button.bezelStyle = .rounded
                button.font = NSFont.systemFont(ofSize: 11)
                button.setButtonType(.momentaryPushIn)
                // Store action in tag using hash - we'll look it up later
                button.tag = title.hashValue
                buttonActions[title.hashValue] = action
                return button
            }
        }

        let rowStacks = rows.map { rowViews -> NSStackView in
            let stack = NSStackView(views: rowViews)
            stack.orientation = .horizontal
            stack.spacing = 8
            stack.distribution = .fillEqually
            return stack
        }

        let mainStack = NSStackView(views: rowStacks)
        mainStack.orientation = .vertical
        mainStack.spacing = 6
        mainStack.alignment = .leading
        return mainStack
    }

    private var buttonActions: [Int: ButtonAction] = [:]

    private func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    @objc private func presetButtonClicked(_ sender: NSButton) {
        stopCapture()
        if let action = buttonActions[sender.tag] {
            onActionSelected?(action)
        }
    }

    @objc private func startCaptureClicked() {
        startCapture()
    }

    private func startCapture() {
        isCapturing = true
        captureLabel.stringValue = "🎹 Press any key or combination..."
        captureLabel.textColor = NSColor.systemBlue
        captureStatusLabel.isHidden = true

        // Monitor key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isCapturing else { return event }

            // Escape cancels capture mode
            if event.keyCode == 0x35 && event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty {
                self.stopCapture()
                self.captureLabel.stringValue = "🎹 Click here, then press any key..."
                self.captureLabel.textColor = NSColor.labelColor
                return nil
            }

            let key = CapturedKey(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection([.command, .shift, .option, .control])
            )

            self.handleCapturedKey(key)
            return nil
        }

        // Monitor modifier flags changes
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self, self.isCapturing else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if !modifiers.isEmpty {
                let key = CapturedKey(keyCode: nil, modifiers: modifiers)
                self.handleCapturedKey(key)
            }

            return nil
        }
    }

    private func stopCapture() {
        isCapturing = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    private func handleCapturedKey(_ key: CapturedKey) {
        stopCapture()

        captureLabel.stringValue = "✓ Captured: \(key.description)"
        captureLabel.textColor = NSColor.systemGreen

        captureStatusLabel.stringValue = "Click to use, or choose preset above"
        captureStatusLabel.isHidden = false

        // Make the captured key clickable to apply
        let action = ButtonAction.keyCombo(
            keyCode: key.keyCode,
            command: key.modifiers.contains(.command),
            shift: key.modifiers.contains(.shift),
            option: key.modifiers.contains(.option),
            control: key.modifiers.contains(.control),
            description: key.description
        )

        // Store for later use
        capturedAction = action

        // Add click gesture to apply captured key
        if captureClickGesture == nil {
            captureClickGesture = NSClickGestureRecognizer(target: self, action: #selector(applyCapturedKey))
            captureLabel.superview?.addGestureRecognizer(captureClickGesture!)
        }
    }

    private var capturedAction: ButtonAction?
    private var captureClickGesture: NSClickGestureRecognizer?

    @objc private func applyCapturedKey() {
        if let action = capturedAction {
            onActionSelected?(action)
        }
    }

    @objc private func cancelPressed() {
        stopCapture()
        onCancelled?()
    }
}

// Helper extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
