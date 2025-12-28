import Foundation

/// Control modes for Joy-Con input handling
enum ControlMode: String, CaseIterable {
    case mouse = "Mouse"
    case scroll = "Scroll"
    case text = "Text"

    var description: String {
        switch self {
        case .mouse:
            return "Mouse Control - Move cursor with sticks, click with triggers"
        case .scroll:
            return "Scroll Mode - Navigate documents and terminal output"
        case .text:
            return "Text Mode - D-pad for arrow keys, optimized for text editing"
        }
    }

    var icon: String {
        switch self {
        case .mouse: return "🖱️"
        case .scroll: return "📜"
        case .text: return "⌨️"
        }
    }

    func next() -> ControlMode {
        let allCases = ControlMode.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .mouse }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

/// Modifier keys state tracking
struct ModifierState {
    var command: Bool = false    // ZL held
    var option: Bool = false     // L held
    var shift: Bool = false      // R held
    var control: Bool = false    // L + R held

    var isEmpty: Bool {
        return !command && !option && !shift && !control
    }

    var description: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        return parts.isEmpty ? "" : parts.joined()
    }
}

/// Settings for input sensitivity and behavior
class InputSettings: ObservableObject {
    static let shared = InputSettings()

    // Mouse sensitivity (1.0 = default, higher = faster)
    var mouseSensitivity: CGFloat = 15.0

    // Precision mode sensitivity multiplier (when R3 pressed)
    var precisionMultiplier: CGFloat = 0.3

    // Scroll sensitivity
    var scrollSensitivity: CGFloat = 3.0

    // Dead zone for analog sticks (0.0-1.0)
    var stickDeadzone: Float = 0.15

    // Acceleration curve exponent (1.0 = linear, 2.0 = quadratic)
    var accelerationCurve: CGFloat = 1.5

    // Mouse update rate in Hz
    var mouseUpdateRate: TimeInterval = 1.0 / 120.0  // 120 Hz

    // Whether voice input is enabled
    var voiceInputEnabled: Bool = true

    private init() {
        loadFromUserDefaults()
    }

    func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "mouseSensitivity") != nil {
            mouseSensitivity = CGFloat(defaults.float(forKey: "mouseSensitivity"))
        }
        if defaults.object(forKey: "scrollSensitivity") != nil {
            scrollSensitivity = CGFloat(defaults.float(forKey: "scrollSensitivity"))
        }
        if defaults.object(forKey: "stickDeadzone") != nil {
            stickDeadzone = defaults.float(forKey: "stickDeadzone")
        }
        if defaults.object(forKey: "voiceInputEnabled") != nil {
            voiceInputEnabled = defaults.bool(forKey: "voiceInputEnabled")
        }
    }

    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(Float(mouseSensitivity), forKey: "mouseSensitivity")
        defaults.set(Float(scrollSensitivity), forKey: "scrollSensitivity")
        defaults.set(stickDeadzone, forKey: "stickDeadzone")
        defaults.set(voiceInputEnabled, forKey: "voiceInputEnabled")
    }
}
