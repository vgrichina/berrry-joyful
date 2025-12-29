import Foundation
import Carbon.HIToolbox

/// Defines what action a button should perform
enum ButtonAction: Codable, Equatable {
    case mouseClick
    case rightClick
    case pressKey(keyCode: Int, requiresShift: Bool = false)
    case pressEnter
    case pressEscape
    case pressTab
    case pressSpace
    case pressBackspace
    case customKey(keyCode: Int, description: String)
    case voiceInput
    case none

    var description: String {
        switch self {
        case .mouseClick: return "Click"
        case .rightClick: return "Right Click"
        case .pressKey(let code, let shift):
            return shift ? "Shift+Key(\(code))" : "Key(\(code))"
        case .pressEnter: return "Enter"
        case .pressEscape: return "Escape"
        case .pressTab: return "Tab"
        case .pressSpace: return "Space"
        case .pressBackspace: return "Backspace"
        case .customKey(_, let desc): return desc
        case .voiceInput: return "Voice Input"
        case .none: return "None"
        }
    }
}

/// Defines what modifier a shoulder button provides
enum ModifierAction: Codable, Equatable {
    case command
    case option
    case shift
    case control
    case none

    var description: String {
        switch self {
        case .command: return "Cmd"
        case .option: return "Option"
        case .shift: return "Shift"
        case .control: return "Control"
        case .none: return "None"
        }
    }
}

/// Complete button mapping profile
struct ButtonProfile: Codable, Equatable {
    var name: String
    var description: String

    // Face buttons
    var buttonA: ButtonAction
    var buttonB: ButtonAction
    var buttonX: ButtonAction
    var buttonY: ButtonAction

    // D-Pad
    var dpadUp: ButtonAction
    var dpadDown: ButtonAction
    var dpadLeft: ButtonAction
    var dpadRight: ButtonAction

    // Shoulder buttons (modifiers)
    var bumperL: ModifierAction
    var bumperR: ModifierAction

    // Triggers
    var triggerZL: ButtonAction
    var triggerZR: ButtonAction
    var triggerZLZR: ButtonAction  // Both triggers held

    // System buttons
    var buttonMinus: ButtonAction
    var buttonPlus: ButtonAction

    // Combo actions (when modifiers are held)
    var enableSmartTabbing: Bool  // X button smart tab combinations
    var enableCmdClick: Bool       // L+A for Cmd+Click

    // Stick controls
    var leftStickFunction: StickFunction
    var rightStickFunction: StickFunction

    enum StickFunction: String, Codable {
        case mouse = "Mouse"
        case scroll = "Scroll"
        case arrowKeys = "Arrow Keys"
        case wasd = "WASD"
        case disabled = "Disabled"
    }

    // MARK: - Default Profiles

    /// Desktop + Terminal profile optimized for Claude Code
    static var desktopTerminal: ButtonProfile {
        ButtonProfile(
            name: "Desktop + Terminal",
            description: "Optimized for Claude Code, terminal, and browser navigation",
            buttonA: .mouseClick,
            buttonB: .pressEscape,
            buttonX: .pressTab,
            buttonY: .pressEnter,
            dpadUp: .pressKey(keyCode: kVK_ANSI_1),
            dpadDown: .pressKey(keyCode: kVK_ANSI_2),
            dpadLeft: .pressKey(keyCode: kVK_ANSI_3),
            dpadRight: .pressKey(keyCode: kVK_ANSI_4),
            bumperL: .command,
            bumperR: .shift,
            triggerZL: .pressKey(keyCode: kVK_ANSI_LeftBracket, requiresShift: true),  // Cmd+Shift+[
            triggerZR: .pressKey(keyCode: kVK_ANSI_RightBracket, requiresShift: true), // Cmd+Shift+]
            triggerZLZR: .voiceInput,
            buttonMinus: .pressBackspace,
            buttonPlus: .none,
            enableSmartTabbing: true,
            enableCmdClick: true,
            leftStickFunction: .mouse,
            rightStickFunction: .scroll
        )
    }

    /// Gaming profile with WASD and standard controls
    static var gaming: ButtonProfile {
        ButtonProfile(
            name: "Gaming",
            description: "WASD movement, Space to jump, standard gaming controls",
            buttonA: .pressSpace,  // Jump
            buttonB: .pressEscape,  // Menu/Back
            buttonX: .pressKey(keyCode: kVK_ANSI_E),  // Interact
            buttonY: .pressKey(keyCode: kVK_ANSI_R),  // Reload
            dpadUp: .pressKey(keyCode: kVK_ANSI_W),
            dpadDown: .pressKey(keyCode: kVK_ANSI_S),
            dpadLeft: .pressKey(keyCode: kVK_ANSI_A),
            dpadRight: .pressKey(keyCode: kVK_ANSI_D),
            bumperL: .shift,  // Sprint
            bumperR: .control,  // Crouch
            triggerZL: .mouseClick,  // Attack
            triggerZR: .rightClick,  // Aim
            triggerZLZR: .pressKey(keyCode: kVK_Tab),
            buttonMinus: .pressKey(keyCode: kVK_ANSI_M),  // Map
            buttonPlus: .pressEscape,  // Menu
            enableSmartTabbing: false,
            enableCmdClick: false,
            leftStickFunction: .wasd,
            rightStickFunction: .mouse
        )
    }

    /// Media control profile
    static var media: ButtonProfile {
        ButtonProfile(
            name: "Media Control",
            description: "Control music, videos, and presentations",
            buttonA: .pressKey(keyCode: kVK_Space),  // Play/Pause
            buttonB: .pressEscape,
            buttonX: .pressKey(keyCode: kVK_RightArrow),  // Next
            buttonY: .pressKey(keyCode: kVK_LeftArrow),   // Previous
            dpadUp: .pressKey(keyCode: kVK_VolumeUp),
            dpadDown: .pressKey(keyCode: kVK_VolumeDown),
            dpadLeft: .pressKey(keyCode: kVK_LeftArrow),  // Rewind
            dpadRight: .pressKey(keyCode: kVK_RightArrow), // Fast Forward
            bumperL: .command,
            bumperR: .shift,
            triggerZL: .pressKey(keyCode: kVK_LeftArrow),
            triggerZR: .pressKey(keyCode: kVK_RightArrow),
            triggerZLZR: .pressKey(keyCode: kVK_Space),
            buttonMinus: .pressKey(keyCode: kVK_Mute),
            buttonPlus: .pressKey(keyCode: kVK_F5),  // Presentation mode
            enableSmartTabbing: false,
            enableCmdClick: false,
            leftStickFunction: .mouse,
            rightStickFunction: .scroll
        )
    }

    /// Classic controller layout
    static var classic: ButtonProfile {
        ButtonProfile(
            name: "Classic",
            description: "Traditional controller mapping with arrow keys",
            buttonA: .pressEnter,
            buttonB: .pressEscape,
            buttonX: .pressTab,
            buttonY: .pressSpace,
            dpadUp: .pressKey(keyCode: kVK_UpArrow),
            dpadDown: .pressKey(keyCode: kVK_DownArrow),
            dpadLeft: .pressKey(keyCode: kVK_LeftArrow),
            dpadRight: .pressKey(keyCode: kVK_RightArrow),
            bumperL: .option,
            bumperR: .shift,
            triggerZL: .pressKey(keyCode: kVK_PageUp),
            triggerZR: .pressKey(keyCode: kVK_PageDown),
            triggerZLZR: .voiceInput,
            buttonMinus: .pressBackspace,
            buttonPlus: .pressEscape,
            enableSmartTabbing: false,
            enableCmdClick: false,
            leftStickFunction: .mouse,
            rightStickFunction: .scroll
        )
    }

    static var allDefaultProfiles: [ButtonProfile] {
        [desktopTerminal, gaming, media, classic]
    }
}
