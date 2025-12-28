import Cocoa
import GameController

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!

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
        // Listen for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.viewController.log("🔌 GCControllerDidConnect notification received")
            self?.viewController.controllerConnected(controller)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.viewController.log("🔌 GCControllerDidDisconnect notification received")
            self?.viewController.controllerDisconnected(controller)
        }

        // Start discovery
        viewController.log("🔍 Starting wireless controller discovery...")
        GCController.startWirelessControllerDiscovery()

        // Check for already connected controllers
        let controllers = GCController.controllers()
        viewController.log("🎮 Found \(controllers.count) controllers already connected")
        for controller in controllers {
            viewController.controllerConnected(controller)
        }

        // Poll for controllers every 2 seconds in case they connect late
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let currentControllers = GCController.controllers()
            let connectedCount = self?.viewController.controllers.count ?? 0

            if currentControllers.count > connectedCount {
                self?.viewController.log("🎮 New controller detected! Total: \(currentControllers.count)")
                for controller in currentControllers {
                    // Check if not already in our list
                    if !(self?.viewController.controllers.contains(controller) ?? false) {
                        self?.viewController.controllerConnected(controller)
                    }
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        GCController.stopWirelessControllerDiscovery()
        InputController.shared.stopMouseUpdates()
        VoiceInputManager.shared.stopListening()
    }
}
