import Cocoa
import GameController

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 Application launching...")

        // Setup application
        NSApp.setActivationPolicy(.regular)
        print("✅ Set activation policy")

        // Create menu bar
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu

        let appMenu = NSMenu()
        let quitMenuItem = NSMenuItem(title: "Quit JoyConTester",
                                      action: #selector(NSApplication.terminate(_:)),
                                      keyEquivalent: "q")
        appMenu.addItem(quitMenuItem)
        appMenuItem.submenu = appMenu
        print("✅ Created menu")

        // Create view controller FIRST
        viewController = ViewController()
        viewController.loadView() // Explicitly load the view
        print("✅ Created view controller, view: \(viewController.view)")

        // Create window
        let contentRect = NSRect(x: 100, y: 100, width: 600, height: 400)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "🎮 Joy-Con Tester"
        window.contentViewController = viewController
        print("✅ Created window: \(window)")

        // Show window and activate app
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ Window should be visible now")

        // Setup controller monitoring
        setupControllerMonitoring()
        print("✅ Controller monitoring setup")
    }

    func setupControllerMonitoring() {
        // Listen for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.viewController.controllerConnected(controller)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.viewController.controllerDisconnected(controller)
        }

        // Start discovery
        GCController.startWirelessControllerDiscovery()

        // Check for already connected controllers
        for controller in GCController.controllers() {
            viewController.controllerConnected(controller)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
