import Cocoa
import GameController

class ViewController: NSViewController {
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var controllers: [GCController] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create scroll view
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        // Create text view
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
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        scrollView.documentView = textView

        view.addSubview(scrollView)

        log("🫐 berrry-joyful - Joy-Con Tester")
        log("Waiting for controller connections...")
        log("")
    }

    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textView = self.textView else { return }

            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)\n"

            textView.textStorage?.append(NSAttributedString(string: logMessage))
            textView.scrollToEndOfDocument(nil)
        }
    }

    func controllerConnected(_ controller: GCController) {
        controllers.append(controller)

        log("✅ Controller Connected:")
        log("   Name: \(controller.vendorName ?? "Unknown")")
        log("   Product: \(controller.productCategory)")

        // Setup input handlers
        if let gamepad = controller.extendedGamepad {
            log("   Type: Extended Gamepad")
            setupExtendedGamepadHandlers(gamepad)
        } else if let micro = controller.microGamepad {
            log("   Type: Micro Gamepad")
            setupMicroGamepadHandlers(micro)
        } else {
            log("   Type: Unknown")
        }

        log("")
    }

    func controllerDisconnected(_ controller: GCController) {
        controllers.removeAll { $0 == controller }
        log("❌ Controller Disconnected: \(controller.vendorName ?? "Unknown")")
        log("")
    }

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🅰️  Button A: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🅱️  Button B: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("❎ Button X: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🔶 Button Y: \(pressed ? "PRESSED" : "released")")
        }

        // D-pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            if xValue != 0 || yValue != 0 {
                self?.log(String(format: "⬆️  D-Pad: x=%.2f, y=%.2f", xValue, yValue))
            }
        }

        // Left stick
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            if abs(xValue) > 0.1 || abs(yValue) > 0.1 {
                self?.log(String(format: "🕹️  Left Stick: x=%.2f, y=%.2f", xValue, yValue))
            }
        }

        // Right stick
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            if abs(xValue) > 0.1 || abs(yValue) > 0.1 {
                self?.log(String(format: "🎯 Right Stick: x=%.2f, y=%.2f", xValue, yValue))
            }
        }

        // Shoulder buttons
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🔼 L Button: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🔼 R Button: \(pressed ? "PRESSED" : "released")")
        }

        // Triggers
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            if value > 0.1 {
                self?.log(String(format: "⬇️  ZL Trigger: %.2f", value))
            }
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            if value > 0.1 {
                self?.log(String(format: "⬇️  ZR Trigger: %.2f", value))
            }
        }

        // Menu/Options buttons
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("⚙️  Menu Button: \(pressed ? "PRESSED" : "released")")
        }

        if let buttonOptions = gamepad.buttonOptions {
            buttonOptions.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.log("⚙️  Options Button: \(pressed ? "PRESSED" : "released")")
            }
        }
    }

    private func setupMicroGamepadHandlers(_ gamepad: GCMicroGamepad) {
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("🅰️  Button A: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log("❎ Button X: \(pressed ? "PRESSED" : "released")")
        }

        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            if xValue != 0 || yValue != 0 {
                self?.log(String(format: "⬆️  D-Pad: x=%.2f, y=%.2f", xValue, yValue))
            }
        }
    }
}
