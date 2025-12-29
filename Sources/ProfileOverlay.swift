import Cocoa

/// Overlay window that displays a cheat sheet for the current button profile
class ProfileOverlay: NSWindow {

    private let containerView: NSView
    private let titleLabel: NSTextField
    private let contentStack: NSStackView
    private var autoHideTimer: Timer?

    init(profile: ButtonProfile) {
        // Create window positioned at center of screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 500
        let windowRect = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        containerView = NSView()
        titleLabel = NSTextField()
        contentStack = NSStackView()

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        displayProfile(profile)
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = NSColor.clear
        level = .floating
        ignoresMouseEvents = false
        hasShadow = true
        isMovableByWindowBackground = false

        // Make window accept key events for dismissal
        makeKey()
    }

    func displayProfile(_ profile: ButtonProfile) {
        // Clear existing content
        contentView?.subviews.forEach { $0.removeFromSuperview() }

        // Create main container with background
        let mainBox = NSBox()
        mainBox.boxType = .custom
        mainBox.borderType = .noBorder
        mainBox.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
        mainBox.cornerRadius = 16
        mainBox.contentViewMargins = NSSize(width: 30, height: 30)

        // Title
        titleLabel.stringValue = "🎮  \(profile.name.uppercased())"
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.alignment = .center
        titleLabel.textColor = NSColor.labelColor

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: profile.description)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = NSColor.secondaryLabelColor

        // Create two-column layout for mappings
        let leftColumn = createMappingsColumn(profile: profile, section: .left)
        let rightColumn = createMappingsColumn(profile: profile, section: .right)

        let columnsStack = NSStackView(views: [leftColumn, rightColumn])
        columnsStack.orientation = .horizontal
        columnsStack.spacing = 30
        columnsStack.distribution = .fillEqually
        columnsStack.alignment = .top

        // Tips section
        let tipsLabel = createTipsLabel(profile: profile)

        // Dismiss instruction
        let dismissLabel = NSTextField(labelWithString: "Press - to dismiss")
        dismissLabel.font = NSFont.systemFont(ofSize: 11)
        dismissLabel.alignment = .center
        dismissLabel.textColor = NSColor.tertiaryLabelColor

        // Main stack
        let mainStack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            columnsStack,
            tipsLabel,
            dismissLabel
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.alignment = .centerX

        mainBox.contentView = mainStack
        contentView = mainBox

        // Auto-hide after 5 seconds
        scheduleAutoHide()
    }

    private enum MappingSection {
        case left
        case right
    }

    private func createMappingsColumn(profile: ButtonProfile, section: MappingSection) -> NSView {
        let sectionBox = NSBox()
        sectionBox.boxType = .custom
        sectionBox.borderType = .lineBorder
        sectionBox.borderWidth = 1
        sectionBox.borderColor = NSColor.separatorColor
        sectionBox.cornerRadius = 8
        sectionBox.fillColor = NSColor.controlBackgroundColor
        sectionBox.contentViewMargins = NSSize(width: 15, height: 15)

        var rows: [NSView] = []

        if section == .left {
            // Face buttons section
            rows.append(createSectionHeader("FACE BUTTONS"))
            rows.append(createMappingRow("A", action: profile.buttonA))
            rows.append(createMappingRow("B", action: profile.buttonB))
            rows.append(createMappingRow("X", action: profile.buttonX))
            rows.append(createMappingRow("Y", action: profile.buttonY))

            rows.append(createSpacer())

            // D-Pad section
            rows.append(createSectionHeader("D-PAD"))
            rows.append(createMappingRow("↑", action: profile.dpadUp))
            rows.append(createMappingRow("→", action: profile.dpadRight))
            rows.append(createMappingRow("↓", action: profile.dpadDown))
            rows.append(createMappingRow("←", action: profile.dpadLeft))

        } else {
            // Triggers & Bumpers section
            rows.append(createSectionHeader("TRIGGERS & BUMPERS"))
            rows.append(createModifierRow("L", modifier: profile.bumperL))
            rows.append(createModifierRow("R", modifier: profile.bumperR))
            rows.append(createMappingRow("ZL", action: profile.triggerZL))
            rows.append(createMappingRow("ZR", action: profile.triggerZR))

            rows.append(createSpacer())

            // System section
            rows.append(createSectionHeader("SYSTEM"))
            rows.append(createMappingRow("+", action: profile.buttonPlus))
            rows.append(createMappingRow("-", action: profile.buttonMinus))
            rows.append(createInfoRow("Hold - + D-Pad", description: "Switch Profile"))
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        sectionBox.contentView = stack
        return sectionBox
    }

    private func createSectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 10)
        label.textColor = NSColor.secondaryLabelColor
        return label
    }

    private func createMappingRow(_ button: String, action: ButtonAction) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8

        let buttonLabel = NSTextField(labelWithString: "\(button)  →")
        buttonLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        buttonLabel.textColor = NSColor.secondaryLabelColor
        buttonLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let actionLabel = NSTextField(labelWithString: action.description)
        actionLabel.font = NSFont.systemFont(ofSize: 11)
        actionLabel.textColor = NSColor.labelColor

        stack.addArrangedSubview(buttonLabel)
        stack.addArrangedSubview(actionLabel)

        return stack
    }

    private func createModifierRow(_ button: String, modifier: ModifierAction) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8

        let buttonLabel = NSTextField(labelWithString: "\(button)  →")
        buttonLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        buttonLabel.textColor = NSColor.secondaryLabelColor
        buttonLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let actionLabel = NSTextField(labelWithString: "\(modifier.description) (hold)")
        actionLabel.font = NSFont.systemFont(ofSize: 11)
        actionLabel.textColor = NSColor.labelColor

        stack.addArrangedSubview(buttonLabel)
        stack.addArrangedSubview(actionLabel)

        return stack
    }

    private func createInfoRow(_ label: String, description: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8

        let keyLabel = NSTextField(labelWithString: label)
        keyLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        keyLabel.textColor = NSColor.secondaryLabelColor
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = NSColor.labelColor

        stack.addArrangedSubview(keyLabel)
        stack.addArrangedSubview(descLabel)

        return stack
    }

    private func createSpacer() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        return spacer
    }

    private func createTipsLabel(profile: ButtonProfile) -> NSTextField {
        var tips: [String] = []

        if profile.enableSmartTabbing {
            tips.append("L+R Modifiers Stack: L+R+X = Cmd+Shift+Tab")
        }

        if profile.leftStickFunction == .mouse {
            tips.append("Left Stick = Mouse")
        }
        if profile.rightStickFunction == .scroll {
            tips.append("Right Stick = Scroll")
        }

        let tipsText = tips.isEmpty ? "" : "💡 " + tips.joined(separator: " • ")

        let label = NSTextField(labelWithString: tipsText)
        label.font = NSFont.systemFont(ofSize: 11)
        label.alignment = .center
        label.textColor = NSColor.secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping

        return label
    }

    private func scheduleAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.dismissOverlay()
        }
    }

    func dismissOverlay() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.close()
        })
    }

    // MARK: - Show Overlay

    static func show(profile: ButtonProfile) {
        let overlay = ProfileOverlay(profile: profile)
        overlay.orderFront(nil)

        // Fade in animation
        overlay.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            overlay.animator().alphaValue = 1
        })
    }
}
