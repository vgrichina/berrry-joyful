import Cocoa

/// Represents a captured keyboard input
struct CapturedKey: Equatable {
    var keyCode: UInt16?  // nil for pure modifier presses
    var modifiers: NSEvent.ModifierFlags
    var description: String

    init(keyCode: UInt16?, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.description = CapturedKey.generateDescription(keyCode: keyCode, modifiers: modifiers)
    }

    static func generateDescription(keyCode: UInt16?, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        // Modifiers in standard order
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // Key name
        if let code = keyCode {
            parts.append(keyCodeToString(code))
        } else if !parts.isEmpty {
            // Pure modifier press (e.g., just "Cmd" or "Shift")
            let modParts = parts.joined(separator: "")
            let names = generateModifierNames(modifiers)
            return names.isEmpty ? modParts : names
        }

        return parts.isEmpty ? "None" : parts.joined()
    }

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x24: return "⏎"  // Return
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x30: return "⇥"  // Tab
        case 0x31: return "␣"  // Space
        case 0x32: return "`"
        case 0x33: return "⌫"  // Delete
        case 0x35: return "⎋"  // Escape
        case 0x7B: return "←"  // Left arrow
        case 0x7C: return "→"  // Right arrow
        case 0x7D: return "↓"  // Down arrow
        case 0x7E: return "↑"  // Up arrow
        case 0x73: return "↖"  // Home
        case 0x77: return "↘"  // End
        case 0x74: return "⇞"  // Page Up
        case 0x79: return "⇟"  // Page Down
        case 0x72: return "Help"
        case 0x75: return "⌦"  // Forward Delete
        case 0x7A...0x84: return "F\(Int(keyCode) - 0x7A + 1)"  // F1-F12
        default: return "Key(\(keyCode))"
        }
    }

    static func generateModifierNames(_ modifiers: NSEvent.ModifierFlags) -> String {
        var names: [String] = []
        if modifiers.contains(.control) { names.append("Control") }
        if modifiers.contains(.option) { names.append("Option") }
        if modifiers.contains(.shift) { names.append("Shift") }
        if modifiers.contains(.command) { names.append("Cmd") }
        return names.joined(separator: "+")
    }
}

/// View for capturing keyboard input with visual feedback
class KeyCaptureView: NSView {

    private let containerBox: NSBox
    private let titleLabel: NSTextField
    private let instructionLabel: NSTextField
    private let currentLabel: NSTextField
    private let newLabel: NSTextField
    private let buttonStack: NSStackView
    private let keepButton: NSButton
    private let tryAgainButton: NSButton
    private let cancelButton: NSButton

    private var isCapturing = false
    private var eventMonitor: Any?
    private var flagsMonitor: Any?

    private var originalKey: CapturedKey?
    var capturedKey: CapturedKey?

    var onKeyCaptured: ((CapturedKey) -> Void)?
    var onCancelled: (() -> Void)?

    init(buttonName: String, currentMapping: String) {
        // Create UI components
        containerBox = NSBox()
        titleLabel = NSTextField(labelWithString: "\(buttonName) - CAPTURING KEY...")
        instructionLabel = NSTextField(labelWithString: "Press any key or combination")
        currentLabel = NSTextField(labelWithString: "Current: \(currentMapping)")
        newLabel = NSTextField(labelWithString: "New: (waiting...)")

        keepButton = NSButton(title: "Keep", target: nil, action: #selector(keepPressed))
        tryAgainButton = NSButton(title: "Try Again", target: nil, action: #selector(tryAgainPressed))
        cancelButton = NSButton(title: "Cancel", target: nil, action: #selector(cancelPressed))

        buttonStack = NSStackView(views: [keepButton, tryAgainButton, cancelButton])

        super.init(frame: .zero)

        setupUI()
        keepButton.target = self
        tryAgainButton.target = self
        cancelButton.target = self

        // Start capturing
        startCapture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopCapture()
    }

    private func setupUI() {
        // Configure container box
        containerBox.boxType = .custom
        containerBox.borderType = .lineBorder
        containerBox.borderWidth = 2
        containerBox.borderColor = NSColor.systemBlue
        containerBox.cornerRadius = 8
        containerBox.fillColor = NSColor.controlBackgroundColor
        containerBox.contentViewMargins = NSSize(width: 20, height: 20)

        // Configure labels
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.alignment = .center

        instructionLabel.font = NSFont.systemFont(ofSize: 13)
        instructionLabel.alignment = .center

        currentLabel.font = NSFont.systemFont(ofSize: 11)
        currentLabel.textColor = NSColor.secondaryLabelColor

        newLabel.font = NSFont.boldSystemFont(ofSize: 13)
        newLabel.textColor = NSColor.labelColor

        // Configure buttons
        keepButton.isEnabled = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        // Layout
        let contentStack = NSStackView(views: [
            titleLabel,
            instructionLabel,
            currentLabel,
            newLabel,
            buttonStack
        ])
        contentStack.orientation = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .centerX

        containerBox.contentView = contentStack
        addSubview(containerBox)

        containerBox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerBox.topAnchor.constraint(equalTo: topAnchor),
            containerBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerBox.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerBox.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])
    }

    private func startCapture() {
        isCapturing = true

        // Monitor key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isCapturing else { return event }

            let key = CapturedKey(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection([.command, .shift, .option, .control])
            )

            self.handleCapturedKey(key)
            return nil  // Consume the event
        }

        // Monitor modifier flags changes to capture pure modifier presses
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self, self.isCapturing else { return event }

            // Only capture on key down (when modifiers are pressed, not released)
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if !modifiers.isEmpty && event.type == .flagsChanged {
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
        // Check for Escape to cancel
        if key.keyCode == 0x35 && key.modifiers.isEmpty {  // Escape
            cancelPressed()
            return
        }

        capturedKey = key
        newLabel.stringValue = "New: \(key.description)"
        newLabel.textColor = NSColor.systemGreen
        keepButton.isEnabled = true

        // Stop capturing after first key
        stopCapture()

        // Update UI
        titleLabel.stringValue = titleLabel.stringValue.replacingOccurrences(of: "CAPTURING", with: "KEY CAPTURED!")
        titleLabel.textColor = NSColor.systemGreen
        instructionLabel.stringValue = "Detected: \(key.description)"
    }

    @objc private func keepPressed() {
        if let key = capturedKey {
            onKeyCaptured?(key)
        }
    }

    @objc private func tryAgainPressed() {
        newLabel.stringValue = "New: (waiting...)"
        newLabel.textColor = NSColor.labelColor
        titleLabel.stringValue = titleLabel.stringValue.replacingOccurrences(of: "KEY CAPTURED!", with: "CAPTURING KEY...")
        titleLabel.textColor = NSColor.systemBlue
        instructionLabel.stringValue = "Press any key or combination"
        keepButton.isEnabled = false
        capturedKey = nil
        startCapture()
    }

    @objc private func cancelPressed() {
        stopCapture()
        onCancelled?()
    }
}
