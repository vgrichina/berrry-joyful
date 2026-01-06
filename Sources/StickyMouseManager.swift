import Cocoa
import CoreGraphics

/// Manages magnetic cursor behavior - slows down cursor near interactive UI elements
class StickyMouseManager {
    static let shared = StickyMouseManager()

    // MARK: - Settings

    enum MagneticStrength {
        case weak
        case medium
        case strong

        var multiplier: CGFloat {
            switch self {
            case .weak: return 0.7    // 70% of default distances
            case .medium: return 1.0  // 100% default
            case .strong: return 1.5  // 150% larger zones
            }
        }

        var description: String {
            switch self {
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }

    var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                scanner.invalidateCache()  // Fresh start when enabling
            }
            saveToUserDefaults()
        }
    }

    var magneticStrength: MagneticStrength = .medium {
        didSet {
            saveToUserDefaults()
        }
    }

    var showVisualOverlay: Bool = false {
        didSet {
            if !showVisualOverlay {
                hideAllOverlays()
            }
            saveToUserDefaults()
        }
    }

    // Element type filters (all enabled by default)
    var enabledElementTypes: Set<AccessibilityScanner.ElementType> = [
        .button, .textField, .textArea, .searchField, .secureTextField,
        .link, .checkbox, .radioButton, .popupButton, .slider
    ]

    // MARK: - Private Properties

    private let scanner = AccessibilityScanner()
    private var overlayWindow: NSWindow?
    private var overlayView: MultiOverlayView?
    private var lastCursorPosition: CGPoint?
    private var lastCursorTime: Date?
    private var velocity: CGVector = .zero
    private var timeSinceLastScan: TimeInterval = 0
    private var lastScanTime: Date?

    private init() {
        loadFromUserDefaults()
    }

    // MARK: - Public API

    /// Calculate speed multiplier for mouse movement based on nearby elements
    /// Returns a value between 0.0 (stopped) and 1.0 (full speed)
    func calculateSpeedMultiplier(at cursorPosition: CGPoint) -> CGFloat {
        guard isEnabled else { return 1.0 }

        // Calculate velocity
        let now = Date()
        if let lastPos = lastCursorPosition, let lastTime = lastCursorTime {
            let dt = now.timeIntervalSince(lastTime)
            if dt > 0 && dt < 0.1 {  // Only update if reasonable time delta
                let dx = cursorPosition.x - lastPos.x
                let dy = cursorPosition.y - lastPos.y
                // Smooth velocity with exponential moving average
                velocity = CGVector(
                    dx: velocity.dx * 0.7 + (dx / dt) * 0.3,
                    dy: velocity.dy * 0.7 + (dy / dt) * 0.3
                )
            }
        }
        lastCursorPosition = cursorPosition
        lastCursorTime = now

        // Scan for nearby elements with directional prediction
        let elements = scanner.getElementsNear(cursorPosition, radius: 120, velocity: velocity)

        // Filter by enabled types
        let filteredElements = elements.filter { enabledElementTypes.contains($0.type) }

        guard !filteredElements.isEmpty else { return 1.0 }

        // Calculate the slowest multiplier from all nearby elements
        var slowestMultiplier: CGFloat = 1.0

        for element in filteredElements {
            let distance = cursorPosition.distance(to: element.center)
            let distances = element.type.magneticDistances

            // Apply strength multiplier
            let outer = distances.outer * magneticStrength.multiplier
            let middle = distances.middle * magneticStrength.multiplier
            let inner = distances.inner * magneticStrength.multiplier

            // Calculate speed multiplier based on distance
            let multiplier: CGFloat
            if distance < inner {
                multiplier = 0.25  // Very slow
            } else if distance < middle {
                multiplier = 0.50  // Half speed
            } else if distance < outer {
                multiplier = 0.75  // Slightly slow
            } else {
                multiplier = 1.0   // Full speed
            }

            // Track the slowest (minimum) multiplier
            slowestMultiplier = min(slowestMultiplier, multiplier)
        }

        // Update visual overlay if enabled
        if showVisualOverlay {
            updateOverlays(for: filteredElements, cursorPosition: cursorPosition)
        }

        return slowestMultiplier
    }

    /// Cycle to next magnetic strength
    func cycleStrength() {
        switch magneticStrength {
        case .weak:
            magneticStrength = .medium
        case .medium:
            magneticStrength = .strong
        case .strong:
            magneticStrength = .weak
        }
    }

    /// Invalidate element cache (call when window focus changes)
    func invalidateCache() {
        scanner.invalidateCache()
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard

        // Load without triggering didSet/save by reading first, then batch-setting
        let savedEnabled = defaults.object(forKey: "stickyMouseEnabled") != nil ? defaults.bool(forKey: "stickyMouseEnabled") : false
        let savedStrength: MagneticStrength
        if let strengthRaw = defaults.string(forKey: "stickyMouseStrength") {
            switch strengthRaw {
            case "weak":
                savedStrength = .weak
            case "medium":
                savedStrength = .medium
            case "strong":
                savedStrength = .strong
            default:
                savedStrength = .medium
            }
        } else {
            savedStrength = .medium
        }
        let savedOverlay = defaults.object(forKey: "stickyMouseShowOverlay") != nil ? defaults.bool(forKey: "stickyMouseShowOverlay") : false

        // Apply values (will trigger saves, but that's okay - ensures consistency)
        isEnabled = savedEnabled
        magneticStrength = savedStrength
        showVisualOverlay = savedOverlay
    }

    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "stickyMouseEnabled")
        let strengthString: String
        switch magneticStrength {
        case .weak:
            strengthString = "weak"
        case .medium:
            strengthString = "medium"
        case .strong:
            strengthString = "strong"
        }
        defaults.set(strengthString, forKey: "stickyMouseStrength")
        defaults.set(showVisualOverlay, forKey: "stickyMouseShowOverlay")
    }

    // MARK: - Visual Overlay

    private func updateOverlays(for elements: [AccessibilityScanner.InteractiveElement], cursorPosition: CGPoint) {
        // Ensure overlay window exists
        if overlayWindow == nil {
            createOverlayWindow()
            NSLog("🧲 Created overlay window")
        }

        // Filter elements that are in range
        let visibleElements = elements.filter { element in
            let distance = cursorPosition.distance(to: element.center)
            let outer = element.type.magneticDistances.outer * magneticStrength.multiplier
            return distance < outer
        }

        NSLog("🧲 Elements found: \(elements.count), visible: \(visibleElements.count)")

        // Update the overlay view with new elements
        overlayView?.updateElements(visibleElements)

        // Make sure window is visible
        if let window = overlayWindow, !visibleElements.isEmpty {
            if !window.isVisible {
                window.orderFront(nil)
                NSLog("🧲 Ordered overlay window front")
            }
        }
    }

    private func createOverlayWindow() {
        // Calculate frame covering all screens
        var totalFrame = NSRect.zero
        for screen in NSScreen.screens {
            totalFrame = totalFrame.union(screen.frame)
        }

        // Create single transparent window covering all screens
        let window = NSWindow(
            contentRect: totalFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Create custom view to draw all overlays
        let view = MultiOverlayView(frame: totalFrame)
        window.contentView = view
        window.orderFront(nil)

        overlayWindow = window
        overlayView = view
    }

    private func hideAllOverlays() {
        overlayView?.updateElements([])
        overlayWindow?.orderOut(nil)
    }
}

// MARK: - Multi-Overlay View

private class MultiOverlayView: NSView {
    private var elements: [AccessibilityScanner.InteractiveElement] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // NSView uses bottom-left origin by default (not flipped)
    override var isFlipped: Bool {
        return false
    }

    func updateElements(_ newElements: [AccessibilityScanner.InteractiveElement]) {
        elements = newElements
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Get window frame to convert from screen coordinates to view coordinates
        guard let windowFrame = window?.frame else { return }

        // Draw each element's overlay
        for element in elements {
            let glowColor = element.type.glowColor.withAlphaComponent(0.3)

            // Convert element bounds from screen coordinates to view coordinates
            // The Accessibility API returns screen coordinates with Y=0 at top
            // But NSView uses Y=0 at bottom, so we need to flip Y
            var viewRect = element.bounds
            viewRect.origin.x -= windowFrame.origin.x
            // Flip Y coordinate: convert from top-origin to bottom-origin
            viewRect.origin.y = windowFrame.size.height - (element.bounds.origin.y - windowFrame.origin.y) - element.bounds.size.height

            // Draw glowing border
            context.setStrokeColor(glowColor.cgColor)
            context.setLineWidth(3.0)

            let insetRect = viewRect.insetBy(dx: 2, dy: 2)
            context.stroke(insetRect)

            // Draw subtle fill
            context.setFillColor(glowColor.withAlphaComponent(0.1).cgColor)
            context.fill(insetRect)
        }
    }
}

// MARK: - Helper Extensions

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}
