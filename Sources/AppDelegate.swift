import Cocoa
import ApplicationServices
import IOKit.hid

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
        window.title = "Berrry Joyful"
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
        appMenu.addItem(NSMenuItem(title: "About Berrry Joyful",
                                   action: #selector(showAbout),
                                   keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Berrry Joyful",
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

        #if DEBUG
        // Debug menu
        let debugMenuItem = NSMenuItem()
        mainMenu.addItem(debugMenuItem)
        let debugMenu = NSMenu(title: "Debug")
        debugMenu.addItem(NSMenuItem(title: "Start Drift Logging",
                                     action: #selector(startDriftLogging),
                                     keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Stop Drift Logging",
                                     action: #selector(stopDriftLogging),
                                     keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(NSMenuItem(title: "Show Drift Statistics",
                                     action: #selector(showDriftStatistics),
                                     keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Open Logs Folder",
                                     action: #selector(openLogsFolder),
                                     keyEquivalent: ""))
        debugMenuItem.submenu = debugMenu
        #endif

        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(NSMenuItem(title: "Berrry Joyful Help",
                                    action: #selector(showHelp),
                                    keyEquivalent: "?"))
        helpMenu.addItem(NSMenuItem(title: "Controller Setup Guide",
                                    action: #selector(showControllerSetup),
                                    keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(NSMenuItem(title: "Report Issue...",
                                    action: #selector(reportIssue),
                                    keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "Berrry Joyful on GitHub",
                                    action: #selector(openGitHub),
                                    keyEquivalent: ""))
        helpMenuItem.submenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "🎮 Berrry Joyful"

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

        // Use an invisible accessory view to force the alert to be 30% wider
        let spacer = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 1))
        alert.accessoryView = spacer

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

    // MARK: - Drift Logging Actions

    #if DEBUG
    @objc private func startDriftLogging() {
        DriftLogger.shared.startLogging()
        viewController?.log("📊 Drift logging started")

        let alert = NSAlert()
        alert.messageText = "Drift Logging Started"
        alert.informativeText = "Stick input data is now being logged to CSV files. Use your Joy-Con normally, and let it sit idle periodically to capture drift patterns.\n\nLogs are saved to: ~/Documents/DriftLogs/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func stopDriftLogging() {
        DriftLogger.shared.stopLogging()
        viewController?.log("📊 Drift logging stopped")

        let alert = NSAlert()
        alert.messageText = "Drift Logging Stopped"
        alert.informativeText = "Drift logging has been stopped. Log files are saved in:\n~/Documents/DriftLogs/\n\nYou can analyze these files using the included Python script or any CSV analysis tool."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Logs Folder")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openLogsFolder()
        }
    }

    @objc private func showDriftStatistics() {
        DriftLogger.shared.printStatistics()

        if let stats = DriftLogger.shared.getIdleStatistics() {
            let alert = NSAlert()
            alert.messageText = "Drift Statistics"
            alert.informativeText = String(format: """
                Based on idle stick samples:

                Mean Position:
                  X: %.6f
                  Y: %.6f

                Standard Deviation:
                  X: %.6f
                  Y: %.6f

                Current Neutral Calibration:
                  X: %.6f
                  Y: %.6f

                Interpretation:
                • High std deviation (>0.01) suggests drift or noise
                • Mean far from 0.0 suggests constant offset drift
                • Check console log for detailed statistics
                """,
                stats.mean.x, stats.mean.y,
                stats.stdDev.x, stats.stdDev.y,
                DriftLogger.shared.getCurrentNeutral().x,
                DriftLogger.shared.getCurrentNeutral().y
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.messageText = "No Drift Data"
            alert.informativeText = "Not enough idle samples collected yet. Start drift logging and let your controller sit idle for a few seconds."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func openLogsFolder() {
        let logsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriftLogs")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        NSWorkspace.shared.open(logsDir)
    }
    #endif

    func setupControllerMonitoring() {
        // Initialize JoyConSwift manager
        joyConManager = JoyConManager()

        viewController.log("🔍 Starting Joy-Con monitoring with JoyConSwift...")

        // Log Bluetooth paired controllers
        logBluetoothJoyConStatus()

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

            // Schedule reconnection attempt after a short delay
            // This helps detect when Joy-Cons wake from sleep
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.attemptReconnection()
            }
        }

        // Start async monitoring
        joyConManager.runAsync()
        viewController.log("🎮 JoyConSwift monitoring started")
        viewController.log("💡 Make sure Joy-Cons are paired via System Settings → Bluetooth")

        // Check for Joy-Cons after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkJoyConStatus()
        }
    }

    private func logBluetoothJoyConStatus() {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType", "-detailLevel", "basic"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                var foundJoyCon = false
                for line in lines {
                    if line.contains("Joy-Con") {
                        foundJoyCon = true
                        viewController.log("🔵 Bluetooth: \(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
                if !foundJoyCon {
                    viewController.log("⚠️ No Joy-Cons found in Bluetooth devices")
                }
            }
        } catch {
            viewController.log("⚠️ Could not check Bluetooth status: \(error.localizedDescription)")
        }
    }

    private func checkJoyConStatus() {
        let controllers = viewController.controllers
        viewController.log("📊 Status Check: \(controllers.count) controller(s) connected")

        for controller in controllers {
            let type = controller.type == .JoyConL ? "Joy-Con (L)" :
                      controller.type == .JoyConR ? "Joy-Con (R)" : "Other"
            viewController.log("   - \(type)")
        }

        if controllers.count == 1 {
            viewController.log("⚠️ Only 1 Joy-Con detected. If both are paired via Bluetooth:")
            viewController.log("   1. Try pressing buttons on the missing Joy-Con")
            viewController.log("   2. Restart the app (Cmd+Q then relaunch)")
            viewController.log("   3. Disconnect/reconnect the missing Joy-Con in Bluetooth settings")
        }
    }

    private func attemptReconnection() {
        viewController.log("🔄 Attempting to detect reconnected controllers...")

        // Don't restart the manager - JoyConSwift should automatically detect reconnections
        // Restarting creates multiple concurrent run loops which causes IOHIDManager crashes

        // Just log the status check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkJoyConStatus()
        }
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
