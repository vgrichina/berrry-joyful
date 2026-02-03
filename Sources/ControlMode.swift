import Foundation

/// Control modes for Joy-Con input handling
/// Simplified to unified default mode with hold-to-activate special modes
enum ControlMode: String {
    case unified = "Unified"

    var description: String {
        return "Unified Control - Mouse, scroll, and keys all accessible"
    }

    var icon: String {
        return ""
    }
}

/// Special input modes activated by holding button combinations
enum SpecialInputMode {
    case voice           // ZL + ZR held
    case precision       // L + R held (future: autocomplete/snippets)
    case none

    var icon: String {
        switch self {
        case .voice: return "Voice"
        case .precision: return "Precision"
        case .none: return ""
        }
    }

    var description: String {
        switch self {
        case .voice: return "Voice Input - Speak to type or command"
        case .precision: return "Precision Mode - Slow mouse, arrow keys"
        case .none: return ""
        }
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
    var leftStickDeadzone: Float = 0.15
    var rightStickDeadzone: Float = 0.15

    // Legacy property for backward compatibility
    var stickDeadzone: Float {
        get { leftStickDeadzone }
        set {
            leftStickDeadzone = newValue
            rightStickDeadzone = newValue
        }
    }

    // Acceleration curve exponent (1.0 = linear, 2.0 = quadratic)
    var accelerationCurve: CGFloat = 1.5

    // Mouse update rate in Hz
    var mouseUpdateRate: TimeInterval = 1.0 / 120.0  // 120 Hz

    // Mouse settings
    var invertY: Bool = false
    var mouseAcceleration: Bool = false

    // Voice settings
    var voiceLanguage: String = "en-US"  // Default to US English

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

        // Load per-stick deadzones with backward compatibility
        if defaults.object(forKey: "leftStickDeadzone") != nil {
            leftStickDeadzone = defaults.float(forKey: "leftStickDeadzone")
        } else if defaults.object(forKey: "stickDeadzone") != nil {
            // Migrate old single deadzone to both sticks
            leftStickDeadzone = defaults.float(forKey: "stickDeadzone")
        }

        if defaults.object(forKey: "rightStickDeadzone") != nil {
            rightStickDeadzone = defaults.float(forKey: "rightStickDeadzone")
        } else if defaults.object(forKey: "stickDeadzone") != nil {
            // Migrate old single deadzone to both sticks
            rightStickDeadzone = defaults.float(forKey: "stickDeadzone")
        }

        if defaults.object(forKey: "invertY") != nil {
            invertY = defaults.bool(forKey: "invertY")
        }
        if defaults.object(forKey: "mouseAcceleration") != nil {
            mouseAcceleration = defaults.bool(forKey: "mouseAcceleration")
        }
        if let savedLanguage = defaults.string(forKey: "voiceLanguage") {
            voiceLanguage = savedLanguage
        }
    }

    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(Float(mouseSensitivity), forKey: "mouseSensitivity")
        defaults.set(Float(scrollSensitivity), forKey: "scrollSensitivity")
        defaults.set(leftStickDeadzone, forKey: "leftStickDeadzone")
        defaults.set(rightStickDeadzone, forKey: "rightStickDeadzone")
        // Keep legacy key for backward compatibility
        defaults.set(leftStickDeadzone, forKey: "stickDeadzone")
        defaults.set(invertY, forKey: "invertY")
        defaults.set(mouseAcceleration, forKey: "mouseAcceleration")
        defaults.set(voiceLanguage, forKey: "voiceLanguage")
    }
}
