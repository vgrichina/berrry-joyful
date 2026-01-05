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
                hideOverlays()
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
    private var overlayWindows: [NSWindow] = []
    private var lastCursorPosition: CGPoint?
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

        // Scan for nearby elements
        let elements = scanner.getElementsNear(cursorPosition, radius: 300)

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
        // Clear old overlays
        hideOverlays()

        // Create new overlays for each element
        for element in elements {
            let distance = cursorPosition.distance(to: element.center)
            let distances = element.type.magneticDistances

            // Only show overlay for elements in range
            let outer = distances.outer * magneticStrength.multiplier
            guard distance < outer else { continue }

            // Create overlay window
            let window = createOverlayWindow(for: element, distances: distances)
            overlayWindows.append(window)
        }
    }

    private func createOverlayWindow(
        for element: AccessibilityScanner.InteractiveElement,
        distances: (outer: CGFloat, middle: CGFloat, inner: CGFloat)
    ) -> NSWindow {
        // Apply strength multiplier
        let outer = distances.outer * magneticStrength.multiplier
        let middle = distances.middle * magneticStrength.multiplier
        let inner = distances.inner * magneticStrength.multiplier

        // Create window at element bounds
        let window = NSWindow(
            contentRect: element.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false

        // Create view to draw glow
        let view = OverlayView(
            frame: NSRect(origin: .zero, size: element.bounds.size),
            color: element.type.glowColor.withAlphaComponent(0.3)
        )

        window.contentView = view
        window.orderFront(nil)

        return window
    }

    private func hideOverlays() {
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
    }
}

// MARK: - Overlay View

private class OverlayView: NSView {
    let glowColor: NSColor

    init(frame: NSRect, color: NSColor) {
        self.glowColor = color
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw glowing border
        context.setStrokeColor(glowColor.cgColor)
        context.setLineWidth(3.0)

        let insetRect = bounds.insetBy(dx: 2, dy: 2)
        context.stroke(insetRect)

        // Draw subtle fill
        context.setFillColor(glowColor.withAlphaComponent(0.1).cgColor)
        context.fill(insetRect)
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
