import Cocoa
import JoyConSwift

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!
    var joyConManager: JoyConManager!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup application
        NSApp.setActivationPolicy(.regular)

        // Create menu bar
        setupMenuBar()

        // Create view controller FIRST
        viewController = ViewController()

        // Create window
        let contentRect = NSRect(x: 100, y: 100, width: 700, height: 500)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "berrry-joyful"
        window.contentViewController = viewController
        window.minSize = NSSize(width: 500, height: 350)
        window.backgroundColor = NSColor(white: 0.1, alpha: 1.0)

        // Show window and activate app
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Setup controller monitoring
        setupControllerMonitoring()
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
        helpMenuItem.submenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "berrry-joyful"
        alert.informativeText = """
        Joy-Con Controller for Mac
        Version 1.0

        Control your Mac with Nintendo Joy-Con controllers.
        Optimized for Claude Code and terminal workflows.

        © 2025 Berrry Computer
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showHelp() {
        // This will be handled by the view controller
        viewController.log("📖 Press Options (-) on Joy-Con to show controls help")
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
        VoiceInputManager.shared.stopListening()
    }
}
