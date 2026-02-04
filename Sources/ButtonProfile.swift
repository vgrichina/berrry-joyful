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
    case keyCombo(keyCode: UInt16?, command: Bool, shift: Bool, option: Bool, control: Bool, description: String)  // Arbitrary key combo with modifiers
    case voiceInput
    case missionControl  // Launch Mission Control app directly
    case none

    var description: String {
        switch self {
        case .mouseClick: return "Click"
        case .rightClick: return "Right Click"
        case .pressKey(let code, let shift):
            let keyName = CapturedKey.keyCodeToString(UInt16(code))
            return shift ? "⌘⇧\(keyName)" : keyName
        case .pressEnter: return "Enter"
        case .pressEscape: return "Escape"
        case .pressTab: return "Tab"
        case .pressSpace: return "Space"
        case .pressBackspace: return "Backspace"
        case .customKey(_, let desc): return desc
        case .keyCombo(_, _, _, _, _, let desc): return desc
        case .voiceInput: return "Voice Input"
        case .missionControl: return "Mission Control"
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
    var buttonHome: ButtonAction
    var buttonCapture: ButtonAction

    // Side buttons (Joy-Con sideways mode)
    var buttonSL: ButtonAction
    var buttonSR: ButtonAction

    // Stick clicks
    var leftStickClick: ButtonAction
    var rightStickClick: ButtonAction

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

    /// Desktop profile - general productivity with arrow navigation
    static var desktopTerminal: ButtonProfile {
        ButtonProfile(
            name: "Desktop",
            description: "General productivity with arrow key navigation",
            buttonA: .mouseClick,
            buttonB: .pressEscape,
            buttonX: .pressTab,
            buttonY: .pressEnter,
            dpadUp: .pressKey(keyCode: kVK_UpArrow),
            dpadDown: .pressKey(keyCode: kVK_DownArrow),
            dpadLeft: .pressKey(keyCode: kVK_LeftArrow),
            dpadRight: .pressKey(keyCode: kVK_RightArrow),
            bumperL: .command,
            bumperR: .shift,
            triggerZL: .keyCombo(keyCode: UInt16(kVK_ANSI_LeftBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧[ (Prev Tab)"),
            triggerZR: .keyCombo(keyCode: UInt16(kVK_ANSI_RightBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧] (Next Tab)"),
            triggerZLZR: .voiceInput,
            buttonMinus: .pressBackspace,
            buttonPlus: .pressSpace,
            buttonHome: .missionControl,
            buttonCapture: .keyCombo(keyCode: UInt16(kVK_ANSI_4), command: true, shift: true, option: false, control: false, description: "⌘⇧4 (Screenshot)"),
            buttonSL: .none,
            buttonSR: .none,
            leftStickClick: .mouseClick,
            rightStickClick: .rightClick,
            enableSmartTabbing: true,
            enableCmdClick: true,
            leftStickFunction: .mouse,
            rightStickFunction: .scroll
        )
    }

    /// Media profile - volume and playback on D-Pad
    static var media: ButtonProfile {
        ButtonProfile(
            name: "Media",
            description: "Volume and playback controls on D-Pad",
            buttonA: .mouseClick,
            buttonB: .pressEscape,
            buttonX: .pressTab,
            buttonY: .pressEnter,
            dpadUp: .pressKey(keyCode: kVK_VolumeUp),
            dpadDown: .pressKey(keyCode: kVK_VolumeDown),
            dpadLeft: .pressKey(keyCode: kVK_Mute),
            dpadRight: .pressSpace,  // Play/Pause
            bumperL: .command,
            bumperR: .shift,
            triggerZL: .keyCombo(keyCode: UInt16(kVK_ANSI_LeftBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧[ (Prev Tab)"),
            triggerZR: .keyCombo(keyCode: UInt16(kVK_ANSI_RightBracket), command: true, shift: true, option: false, control: false, description: "⌘⇧] (Next Tab)"),
            triggerZLZR: .voiceInput,
            buttonMinus: .pressKey(keyCode: kVK_ANSI_J),  // Rewind 10s (YouTube)
            buttonPlus: .pressKey(keyCode: kVK_ANSI_L),   // Forward 10s (YouTube)
            buttonHome: .missionControl,
            buttonCapture: .keyCombo(keyCode: UInt16(kVK_ANSI_4), command: true, shift: true, option: false, control: false, description: "⌘⇧4 (Screenshot)"),
            buttonSL: .none,
            buttonSR: .none,
            leftStickClick: .mouseClick,
            rightStickClick: .rightClick,
            enableSmartTabbing: true,
            enableCmdClick: true,
            leftStickFunction: .mouse,
            rightStickFunction: .scroll
        )
    }

    /// Gaming profile - FPS-style with WASD movement
    static var gaming: ButtonProfile {
        ButtonProfile(
            name: "Gaming",
            description: "FPS-style: left stick WASD, right stick aim, triggers shoot",
            buttonA: .pressSpace,  // Jump
            buttonB: .pressEscape,  // Menu/Back
            buttonX: .pressKey(keyCode: kVK_ANSI_E),  // Interact
            buttonY: .pressKey(keyCode: kVK_ANSI_R),  // Reload
            dpadUp: .pressKey(keyCode: kVK_ANSI_1),    // Weapon 1
            dpadDown: .pressKey(keyCode: kVK_ANSI_2),  // Weapon 2
            dpadLeft: .pressKey(keyCode: kVK_ANSI_3),  // Weapon 3
            dpadRight: .pressKey(keyCode: kVK_ANSI_4), // Weapon 4
            bumperL: .shift,    // Sprint
            bumperR: .control,  // Crouch
            triggerZL: .rightClick,   // Aim
            triggerZR: .mouseClick,   // Shoot
            triggerZLZR: .pressKey(keyCode: kVK_ANSI_G),  // Grenade
            buttonMinus: .pressKey(keyCode: kVK_ANSI_M),  // Map
            buttonPlus: .pressKey(keyCode: kVK_Tab),      // Scoreboard
            buttonHome: .missionControl,
            buttonCapture: .keyCombo(keyCode: UInt16(kVK_ANSI_4), command: true, shift: true, option: false, control: false, description: "⌘⇧4 (Screenshot)"),
            buttonSL: .none,
            buttonSR: .none,
            leftStickClick: .pressKey(keyCode: kVK_ANSI_C),  // Crouch toggle
            rightStickClick: .pressKey(keyCode: kVK_ANSI_V), // Melee
            enableSmartTabbing: false,
            enableCmdClick: false,
            leftStickFunction: .wasd,
            rightStickFunction: .mouse
        )
    }

    static var allDefaultProfiles: [ButtonProfile] {
        [desktopTerminal, media, gaming]
    }
}
