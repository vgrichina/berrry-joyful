import Cocoa
import JoyConSwift
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!
    var permissionsViewController: PermissionsViewController?
    var joyConManager: JoyConManager!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup application
        NSApp.setActivationPolicy(.regular)

        // Create menu bar
        setupMenuBar()

        // Check if we need to show permissions screen
        let hasAccessibility = AXIsProcessTrusted()

        // Create window
        let contentRect = NSRect(x: 100, y: 100, width: 800, height: 700)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "berrry-joyful"
        window.backgroundColor = NSColor.windowBackgroundColor

        // Skip permissions screen in debug mode
        #if DEBUG
        let skipPermissions = InputController.shared.debugMode
        #else
        let skipPermissions = false
        #endif

        if !hasAccessibility && !skipPermissions {
            // Show permissions screen first
            showPermissionsScreen()
        } else {
            // Go directly to main app
            showMainApp()
        }

        // Show window and activate app
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPermissionsScreen() {
        permissionsViewController = PermissionsViewController()
        permissionsViewController?.onPermissionsGranted = { [weak self] in
            self?.showMainApp()
        }
        window.contentViewController = permissionsViewController
        window.minSize = NSSize(width: 700, height: 600)
    }

    private func showMainApp() {
        // Create view controller
        viewController = ViewController()
        window.contentViewController = viewController
        window.minSize = NSSize(width: 700, height: 600)

        // Setup controller monitoring
        setupControllerMonitoring()

        // Clear permissions VC
        permissionsViewController = nil
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About berrry-joyful",
                                   action: #selector(showAbout),
                                   keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit berrry-joyful",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Show Help",
                                    action: #selector(showHelp),
                                    keyEquivalent: "/"))
        viewMenuItem.submenu = viewMenu

        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(NSMenuItem(title: "berrry-joyful Help",
                                    action: #selector(showHelp),
                                    keyEquivalent: "?"))
        helpMenu.addItem(NSMenuItem(title: "Controller Setup Guide",
                                    action: #selector(showControllerSetup),
                                    keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(NSMenuItem(title: "Report Issue...",
                                    action: #selector(reportIssue),
                                    keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "berrry-joyful on GitHub",
                                    action: #selector(openGitHub),
                                    keyEquivalent: ""))
        helpMenuItem.submenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "🎮 berrry-joyful"

        // Get version from bundle
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        alert.informativeText = """
        Version \(version) (Build \(build))

        Control your Mac with Nintendo Joy-Con controllers.
        Perfect for Claude Code, terminal workflows, and accessibility.

        © 2025 Berrry Computer

        This app uses JoyConSwift by magicien (MIT License)

        GitHub: github.com/vgrichina/berrry-joyful
        Privacy: No data collection, fully offline
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View on GitHub")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Open GitHub repo
            if let url = URL(string: "https://github.com/vgrichina/berrry-joyful") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func showHelp() {
        // This will be handled by the view controller
        viewController.log("📖 Press Options (-) on Joy-Con to show controls help")
    }

    @objc private func showControllerSetup() {
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

    @objc private func reportIssue() {
        if let url = URL(string: "https://github.com/vgrichina/berrry-joyful/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/vgrichina/berrry-joyful") {
            NSWorkspace.shared.open(url)
        }
    }

    func setupControllerMonitoring() {
        // Initialize JoyConSwift manager
        joyConManager = JoyConManager()

        viewController.log("🔍 Starting Joy-Con monitoring with JoyConSwift...")

        // Set up connection handler
        joyConManager.connectHandler = { [weak self] controller in
            guard let self = self else { return }

            let controllerType = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
            self.viewController.log("✅ Joy-Con Connected: \(controllerType)")
            self.viewController.log("   Type: \(controller.type)")

            // Store controller and configure handlers
            self.viewController.joyConConnected(controller)
        }

        // Set up disconnection handler
        joyConManager.disconnectHandler = { [weak self] controller in
            guard let self = self else { return }

            let controllerType = controller.type == .JoyConL ? "Joy-Con (L)" : "Joy-Con (R)"
            self.viewController.log("❌ Joy-Con Disconnected: \(controllerType)")

            self.viewController.joyConDisconnected(controller)
        }

        // Start async monitoring
        joyConManager.runAsync()
        viewController.log("🎮 JoyConSwift monitoring started")
        viewController.log("💡 Make sure Joy-Cons are paired via System Settings → Bluetooth")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        InputController.shared.stopMouseUpdates()

        // Only clean up voice manager if it was actually used
        // Accessing it unnecessarily can trigger microphone permission prompts
        let voiceManager = VoiceInputManager.shared
        if voiceManager.wasUsed {
            voiceManager.stopListening()
        }
    }
}
