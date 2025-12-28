import Cocoa

/// Floating overlay window showing controller status and current mode
class StatusOverlayWindow: NSPanel {
    private var statusLabel: NSTextField!
    private var modeLabel: NSTextField!
    private var modifiersLabel: NSTextField!
    private var voiceLabel: NSTextField!
    private var voiceTranscriptLabel: NSTextField!
    private var batteryLabel: NSTextField!

    private var hideTimer: Timer?

    init() {
        let frame = NSRect(x: 0, y: 0, width: 300, height: 120)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupUI()
        positionWindow()
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12

        // Main container with padding
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        // Status label (controller connection)
        statusLabel = createLabel(fontSize: 13, bold: true)
        statusLabel.stringValue = "🎮 No Controller"
        stackView.addArrangedSubview(statusLabel)

        // Mode label
        modeLabel = createLabel(fontSize: 18, bold: true)
        modeLabel.stringValue = "🖱️ Mouse Mode"
        stackView.addArrangedSubview(modeLabel)

        // Modifiers label
        modifiersLabel = createLabel(fontSize: 14, bold: false)
        modifiersLabel.stringValue = ""
        modifiersLabel.textColor = NSColor.systemYellow
        stackView.addArrangedSubview(modifiersLabel)

        // Voice input label
        voiceLabel = createLabel(fontSize: 13, bold: false)
        voiceLabel.stringValue = ""
        voiceLabel.textColor = NSColor.systemGreen
        stackView.addArrangedSubview(voiceLabel)

        // Voice transcript
        voiceTranscriptLabel = createLabel(fontSize: 11, bold: false)
        voiceTranscriptLabel.stringValue = ""
        voiceTranscriptLabel.textColor = NSColor.systemGreen.withAlphaComponent(0.8)
        voiceTranscriptLabel.maximumNumberOfLines = 2
        voiceTranscriptLabel.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(voiceTranscriptLabel)

        // Battery label
        batteryLabel = createLabel(fontSize: 11, bold: false)
        batteryLabel.stringValue = ""
        batteryLabel.textColor = NSColor.secondaryLabelColor
        stackView.addArrangedSubview(batteryLabel)
    }

    private func createLabel(fontSize: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = bold
            ? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            : NSFont.systemFont(ofSize: fontSize, weight: .regular)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }

        // Position at bottom-right corner
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let x = screenFrame.maxX - windowFrame.width - 20
        let y = screenFrame.minY + 20

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Update Methods

    func updateConnectionStatus(connected: Bool, controllerName: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            if connected {
                let name = controllerName ?? "Controller"
                self?.statusLabel.stringValue = "🎮 \(name)"
                self?.statusLabel.textColor = .white
            } else {
                self?.statusLabel.stringValue = "🎮 No Controller"
                self?.statusLabel.textColor = NSColor.secondaryLabelColor
            }
        }
    }

    func updateMode(_ mode: ControlMode) {
        DispatchQueue.main.async { [weak self] in
            self?.modeLabel.stringValue = "\(mode.icon) \(mode.rawValue) Mode"
            self?.flashOverlay()
        }
    }

    func updateModifiers(_ modifiers: ModifierState) {
        DispatchQueue.main.async { [weak self] in
            if modifiers.isEmpty {
                self?.modifiersLabel.stringValue = ""
            } else {
                self?.modifiersLabel.stringValue = "Modifiers: \(modifiers.description)"
            }
        }
    }

    func updateVoiceStatus(listening: Bool, transcript: String = "") {
        DispatchQueue.main.async { [weak self] in
            if listening {
                self?.voiceLabel.stringValue = "🎤 Listening..."
                self?.voiceTranscriptLabel.stringValue = transcript.isEmpty ? "" : "\"\(transcript)\""
                self?.showPersistent()
            } else {
                self?.voiceLabel.stringValue = ""
                self?.voiceTranscriptLabel.stringValue = ""
            }
        }
    }

    func updateBattery(level: Float) {
        DispatchQueue.main.async { [weak self] in
            let percentage = Int(level * 100)
            let icon: String
            switch percentage {
            case 80...100: icon = "🔋"
            case 50..<80: icon = "🔋"
            case 20..<50: icon = "🪫"
            default: icon = "🪫"
            }
            self?.batteryLabel.stringValue = "\(icon) \(percentage)%"
        }
    }

    func showAction(_ action: String) {
        DispatchQueue.main.async { [weak self] in
            // Temporarily show action in modifiers label
            self?.modifiersLabel.stringValue = action
            self?.modifiersLabel.textColor = NSColor.systemCyan
            self?.flashOverlay()

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.modifiersLabel.textColor = NSColor.systemYellow
            }
        }
    }

    // MARK: - Visibility Control

    func show(autoHide: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.hideTimer?.invalidate()
            self.orderFront(nil)
            self.alphaValue = 1.0

            if autoHide {
                self.hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.fadeOut()
                }
            }
        }
    }

    func showPersistent() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.invalidate()
            self?.orderFront(nil)
            self?.alphaValue = 1.0
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.invalidate()
            self?.orderOut(nil)
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0.3
        })
    }

    private func flashOverlay() {
        showPersistent()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }
}

// MARK: - Help Overlay

class HelpOverlayWindow: NSPanel {
    init() {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Joy-Con Controls"
        self.level = .floating
        self.backgroundColor = NSColor.windowBackgroundColor

        setupUI()
        center()
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }

        let scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 800))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)

        let helpText = """
        🫐 berrry-joyful - Joy-Con Controller for Mac

        ════════════════════════════════════════════
        CONTROL MODES (Y to cycle)
        ════════════════════════════════════════════

        🖱️  MOUSE MODE
            Left Stick  → Move cursor
            Right Stick → Fine movement / Scroll
            ZR          → Left click (hold to drag)
            ZL          → Right click
            L3          → Middle click
            R3          → Toggle precision mode

        📜 SCROLL MODE
            Left Stick  → Scroll vertically
            Right Stick → Scroll horizontally
            D-Pad Up/Dn → Page Up / Page Down

        ⌨️  TEXT MODE (optimized for Claude Code)
            D-Pad       → Arrow keys
            D-Pad + L   → Word navigation (⌥+Arrow)
            D-Pad + ZL  → Line start/end (⌘+Arrow)

        ════════════════════════════════════════════
        COMMON BUTTONS (all modes)
        ════════════════════════════════════════════

        A           → Enter / Confirm
        B           → Escape / Cancel
        X           → Tab / Autocomplete
        Y           → Cycle control mode

        L           → Option (⌥) modifier
        R           → Shift (⇧) modifier
        L + R       → Control (⌃) modifier
        ZL (hold)   → Command (⌘) modifier

        ════════════════════════════════════════════
        SPECIAL ACTIONS
        ════════════════════════════════════════════

        Menu (+)    → Toggle voice input 🎤
        Options (-) → Show this help

        ZL + B      → Interrupt (⌃C)
        ZL + X      → New tab
        ZL + A      → Submit with newline

        ════════════════════════════════════════════
        VOICE COMMANDS
        ════════════════════════════════════════════

        Hold Menu (+) to speak, release to type.

        Commands: "enter", "escape", "tab", "click",
                  "scroll up/down", "delete", "stop"

        ════════════════════════════════════════════
        """

        textView.string = helpText
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
    }
}
