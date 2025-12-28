import Cocoa
import ApplicationServices

/// First-launch permissions screen with user-friendly explanations
class PermissionsViewController: NSViewController {

    // MARK: - UI Elements

    private let titleLabel = NSTextField(labelWithString: "🎮 berrry-joyful")
    private let subtitleLabel = NSTextField(labelWithString: "Welcome to Joy-Con Mac Control")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "To use berrry-joyful, we need a few permissions:")

    // Accessibility Permission Card
    private let accessibilityCard = NSView()
    private let accessibilityTitleLabel = NSTextField(labelWithString: "🖱️  Accessibility Access")
    private let accessibilityDescLabel = NSTextField(wrappingLabelWithString: "Required to control your mouse and keyboard with Joy-Con controllers. This allows button presses to simulate clicks and stick movements to move your cursor.")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "Status: ⚠️  Not Granted")
    private let accessibilityGrantButton = NSButton(title: "GRANT", target: nil, action: #selector(grantAccessibilityClicked))

    // Microphone Permission Card
    private let microphoneCard = NSView()
    private let microphoneTitleLabel = NSTextField(labelWithString: "🎤  Speech Recognition")
    private let microphoneDescLabel = NSTextField(wrappingLabelWithString: "Optional. Enables voice input mode where you can speak to type text. Hold ZL+ZR on your Joy-Con to activate. You can enable this later.")
    private let microphoneStatusLabel = NSTextField(labelWithString: "Status: ⏸️  Not Requested")
    private let microphoneSkipButton = NSButton(title: "SKIP", target: nil, action: #selector(skipMicrophoneClicked))
    private let microphoneGrantButton = NSButton(title: "GRANT", target: nil, action: #selector(grantMicrophoneClicked))

    // Continue Button
    private let continueButton = NSButton(title: "Continue", target: nil, action: #selector(continueClicked))
    private let tipLabel = NSTextField(wrappingLabelWithString: "💡 Tip: Click \"Grant\" to open System Settings. Enable berrry-joyful in the Accessibility section, then return here.")

    // Completion handler
    var onPermissionsGranted: (() -> Void)?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPermissionStatuses()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Description
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = NSColor.labelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionLabel)

        // Setup permission cards
        setupAccessibilityCard()
        setupMicrophoneCard()

        // Continue button
        continueButton.bezelStyle = .rounded
        continueButton.target = self
        continueButton.isEnabled = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(continueButton)

        // Tip label
        tipLabel.font = NSFont.systemFont(ofSize: 12)
        tipLabel.textColor = NSColor.secondaryLabelColor
        tipLabel.maximumNumberOfLines = 2
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Description
            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Accessibility card
            accessibilityCard.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            accessibilityCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            accessibilityCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            accessibilityCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Microphone card
            microphoneCard.topAnchor.constraint(equalTo: accessibilityCard.bottomAnchor, constant: 20),
            microphoneCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            microphoneCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            microphoneCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Continue button
            continueButton.topAnchor.constraint(equalTo: microphoneCard.bottomAnchor, constant: 30),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 200),
            continueButton.heightAnchor.constraint(equalToConstant: 36),

            // Tip label
            tipLabel.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 30),
            tipLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            tipLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
        ])
    }

    private func setupAccessibilityCard() {
        accessibilityCard.wantsLayer = true
        accessibilityCard.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        accessibilityCard.layer?.cornerRadius = 8
        accessibilityCard.layer?.borderWidth = 1
        accessibilityCard.layer?.borderColor = NSColor.separatorColor.cgColor
        accessibilityCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(accessibilityCard)

        // Title
        accessibilityTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        accessibilityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        accessibilityCard.addSubview(accessibilityTitleLabel)

        // Grant button
        accessibilityGrantButton.bezelStyle = .rounded
        accessibilityGrantButton.translatesAutoresizingMaskIntoConstraints = false
        accessibilityCard.addSubview(accessibilityGrantButton)

        // Description
        accessibilityDescLabel.font = NSFont.systemFont(ofSize: 12)
        accessibilityDescLabel.textColor = NSColor.secondaryLabelColor
        accessibilityDescLabel.maximumNumberOfLines = 3
        accessibilityDescLabel.translatesAutoresizingMaskIntoConstraints = false
        accessibilityCard.addSubview(accessibilityDescLabel)

        // Status
        accessibilityStatusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        accessibilityStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        accessibilityCard.addSubview(accessibilityStatusLabel)

        NSLayoutConstraint.activate([
            accessibilityTitleLabel.topAnchor.constraint(equalTo: accessibilityCard.topAnchor, constant: 16),
            accessibilityTitleLabel.leadingAnchor.constraint(equalTo: accessibilityCard.leadingAnchor, constant: 16),

            accessibilityGrantButton.centerYAnchor.constraint(equalTo: accessibilityTitleLabel.centerYAnchor),
            accessibilityGrantButton.trailingAnchor.constraint(equalTo: accessibilityCard.trailingAnchor, constant: -16),
            accessibilityGrantButton.widthAnchor.constraint(equalToConstant: 80),

            accessibilityDescLabel.topAnchor.constraint(equalTo: accessibilityTitleLabel.bottomAnchor, constant: 12),
            accessibilityDescLabel.leadingAnchor.constraint(equalTo: accessibilityCard.leadingAnchor, constant: 16),
            accessibilityDescLabel.trailingAnchor.constraint(equalTo: accessibilityCard.trailingAnchor, constant: -16),

            accessibilityStatusLabel.topAnchor.constraint(equalTo: accessibilityDescLabel.bottomAnchor, constant: 12),
            accessibilityStatusLabel.leadingAnchor.constraint(equalTo: accessibilityCard.leadingAnchor, constant: 16),
            accessibilityStatusLabel.bottomAnchor.constraint(lessThanOrEqualTo: accessibilityCard.bottomAnchor, constant: -16),
        ])
    }

    private func setupMicrophoneCard() {
        microphoneCard.wantsLayer = true
        microphoneCard.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        microphoneCard.layer?.cornerRadius = 8
        microphoneCard.layer?.borderWidth = 1
        microphoneCard.layer?.borderColor = NSColor.separatorColor.cgColor
        microphoneCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(microphoneCard)

        // Title
        microphoneTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        microphoneTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        microphoneCard.addSubview(microphoneTitleLabel)

        // Skip button
        microphoneSkipButton.bezelStyle = .rounded
        microphoneSkipButton.translatesAutoresizingMaskIntoConstraints = false
        microphoneCard.addSubview(microphoneSkipButton)

        // Grant button (hidden initially)
        microphoneGrantButton.bezelStyle = .rounded
        microphoneGrantButton.isHidden = true
        microphoneGrantButton.translatesAutoresizingMaskIntoConstraints = false
        microphoneCard.addSubview(microphoneGrantButton)

        // Description
        microphoneDescLabel.font = NSFont.systemFont(ofSize: 12)
        microphoneDescLabel.textColor = NSColor.secondaryLabelColor
        microphoneDescLabel.maximumNumberOfLines = 3
        microphoneDescLabel.translatesAutoresizingMaskIntoConstraints = false
        microphoneCard.addSubview(microphoneDescLabel)

        // Status
        microphoneStatusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        microphoneStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        microphoneCard.addSubview(microphoneStatusLabel)

        NSLayoutConstraint.activate([
            microphoneTitleLabel.topAnchor.constraint(equalTo: microphoneCard.topAnchor, constant: 16),
            microphoneTitleLabel.leadingAnchor.constraint(equalTo: microphoneCard.leadingAnchor, constant: 16),

            microphoneSkipButton.centerYAnchor.constraint(equalTo: microphoneTitleLabel.centerYAnchor),
            microphoneSkipButton.trailingAnchor.constraint(equalTo: microphoneCard.trailingAnchor, constant: -16),
            microphoneSkipButton.widthAnchor.constraint(equalToConstant: 80),

            microphoneGrantButton.centerYAnchor.constraint(equalTo: microphoneTitleLabel.centerYAnchor),
            microphoneGrantButton.trailingAnchor.constraint(equalTo: microphoneCard.trailingAnchor, constant: -16),
            microphoneGrantButton.widthAnchor.constraint(equalToConstant: 80),

            microphoneDescLabel.topAnchor.constraint(equalTo: microphoneTitleLabel.bottomAnchor, constant: 12),
            microphoneDescLabel.leadingAnchor.constraint(equalTo: microphoneCard.leadingAnchor, constant: 16),
            microphoneDescLabel.trailingAnchor.constraint(equalTo: microphoneCard.trailingAnchor, constant: -16),

            microphoneStatusLabel.topAnchor.constraint(equalTo: microphoneDescLabel.bottomAnchor, constant: 12),
            microphoneStatusLabel.leadingAnchor.constraint(equalTo: microphoneCard.leadingAnchor, constant: 16),
            microphoneStatusLabel.bottomAnchor.constraint(lessThanOrEqualTo: microphoneCard.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Permission Checking

    private func checkPermissionStatuses() {
        checkAccessibilityStatus()
        checkMicrophoneStatus()
    }

    private func checkAccessibilityStatus() {
        let hasAccess = AXIsProcessTrusted()

        if hasAccess {
            accessibilityStatusLabel.stringValue = "Status: ✅ Granted"
            accessibilityStatusLabel.textColor = NSColor.systemGreen
            accessibilityGrantButton.isEnabled = false
            accessibilityGrantButton.title = "✓ GRANTED"
            continueButton.isEnabled = true
        } else {
            accessibilityStatusLabel.stringValue = "Status: ⚠️  Not Granted"
            accessibilityStatusLabel.textColor = NSColor.systemOrange
            accessibilityGrantButton.isEnabled = true
            continueButton.isEnabled = false
        }
    }

    private func checkMicrophoneStatus() {
        let hasAccess = VoiceInputManager.checkMicrophonePermission()

        if hasAccess {
            microphoneStatusLabel.stringValue = "Status: ✅ Granted"
            microphoneStatusLabel.textColor = NSColor.systemGreen
            microphoneSkipButton.isHidden = true
            microphoneGrantButton.isHidden = true
        } else {
            microphoneStatusLabel.stringValue = "Status: ⏸️  Not Requested"
            microphoneStatusLabel.textColor = NSColor.secondaryLabelColor
        }
    }

    // MARK: - Actions

    @objc private func grantAccessibilityClicked() {
        // Open System Settings to Accessibility pane
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        // Poll for permission changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.checkAccessibilityStatus()
            if AXIsProcessTrusted() {
                timer.invalidate()
            }
        }
    }

    @objc private func grantMicrophoneClicked() {
        VoiceInputManager.requestMicrophonePermission { [weak self] granted in
            self?.checkMicrophoneStatus()
        }
    }

    @objc private func skipMicrophoneClicked() {
        // User doesn't want microphone access - that's fine
        microphoneStatusLabel.stringValue = "Status: ⏭️  Skipped"
        microphoneStatusLabel.textColor = NSColor.tertiaryLabelColor
        microphoneSkipButton.isHidden = true
        microphoneGrantButton.isHidden = false
        microphoneGrantButton.title = "Enable Later"
    }

    @objc private func continueClicked() {
        // Accessibility is granted, proceed to main app
        onPermissionsGranted?()
    }
}
