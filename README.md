# berrry-joyful

Control your Mac with Nintendo Joy-Con controllers. Optimized for Claude Code and terminal workflows.

**By Berrry Computer**

## Features

- **Full Mouse Control** - Move cursor with analog sticks, click with triggers
- **Keyboard Shortcuts** - Enter, Escape, Tab, arrow keys, and modifiers
- **Voice Input** - Hold Menu (+) to dictate text or speak commands
- **Three Control Modes** - Mouse, Scroll, and Text modes for different tasks
- **Status Overlay** - Floating display shows current mode and modifiers
- **Claude Code Optimized** - Quick access to common terminal operations

## Control Scheme

### Face Buttons
| Button | Action |
|--------|--------|
| **A** | Enter / Confirm |
| **B** | Escape / Cancel (with ZL: Ctrl+C interrupt) |
| **X** | Tab / Autocomplete (with ZL: New Tab) |
| **Y** | Cycle through control modes |

### Triggers & Shoulders
| Input | Action |
|-------|--------|
| **ZR** | Left click (hold for drag) |
| **ZL** | Right click / Command (⌘) modifier |
| **L** | Option (⌥) modifier |
| **R** | Shift (⇧) modifier |
| **L + R** | Control (⌃) modifier |

### Analog Sticks
| Input | Mouse Mode | Scroll Mode | Text Mode |
|-------|------------|-------------|-----------|
| **Left Stick** | Move cursor | Scroll vertically | Scroll |
| **Right Stick** | Fine movement | Scroll horizontally | Fine scroll |
| **L3 (click)** | Middle click | - | - |
| **R3 (click)** | Precision mode | - | - |

### D-Pad
| Input | Mouse/Text Mode | Scroll Mode |
|-------|-----------------|-------------|
| **D-Pad** | Arrow keys | Page Up/Down |
| **+ L** | Word navigation (⌥+Arrow) | - |
| **+ ZL** | Line start/end (⌘+Arrow) | - |

### Menu Buttons
| Button | Action |
|--------|--------|
| **Menu (+)** | Hold for voice input |
| **Options (-)** | Show/hide help overlay |

## Voice Input

Hold **Menu (+)** to speak. Release to type the transcribed text.

### Voice Commands
Say these commands to perform actions instead of typing:
- "enter" / "submit" / "confirm" - Press Enter
- "escape" / "cancel" / "back" - Press Escape
- "tab" / "autocomplete" - Press Tab
- "click" / "select" - Left click
- "right click" - Right click
- "scroll up" / "scroll down" - Page navigation
- "delete" / "backspace" - Delete character
- "stop" / "interrupt" - Send Ctrl+C

## Requirements

- macOS 14.0+ (Sonoma)
- Nintendo Joy-Con controllers (paired via Bluetooth)
- Accessibility permission (for mouse/keyboard control)
- Microphone permission (for voice input)

## Permissions

The app will prompt for these permissions on first launch:

1. **Accessibility** - Required for mouse movement and keyboard input
   - Go to: System Settings → Privacy & Security → Accessibility
   - Enable berrry-joyful

2. **Microphone** - Required for voice input
   - Go to: System Settings → Privacy & Security → Microphone
   - Enable berrry-joyful

3. **Bluetooth** - Automatically requested for Joy-Con connection

## Building

```bash
# Install dependencies
brew install xcodegen
sudo gem install cocoapods

# Install CocoaPods dependencies (includes JoyConSwift)
pod install

# Generate Xcode project
xcodegen generate

# Build using workspace (not .xcodeproj!)
xcodebuild -workspace berrry-joyful.xcworkspace -scheme berrry-joyful -configuration Debug build

# Or open in Xcode
open berrry-joyful.xcworkspace
```

**Note**: Always use `berrry-joyful.xcworkspace`, not the `.xcodeproj` file, since we use CocoaPods dependencies.

## Project Structure

```
Sources/
├── main.swift              # App entry point
├── AppDelegate.swift       # Application lifecycle & menus
├── ViewController.swift    # Main UI and Joy-Con input handling
├── InputController.swift   # Mouse/keyboard simulation via CGEvent
├── VoiceInputManager.swift # Speech recognition via Speech framework
├── ControlMode.swift       # Control modes and settings
├── StatusOverlay.swift     # Floating status window and help
├── Info.plist              # App configuration
└── berrry-joyful.entitlements
```

## Technical Notes

- Pure Swift 5.9 with AppKit (no storyboards)
- JoyConSwift library for direct Joy-Con HID communication (via CocoaPods)
- CGEvent API for mouse/keyboard simulation
- Speech framework for voice recognition
- Supports on-device speech recognition (macOS 13+)
- Auto-patches JoyConSwift pointer alignment bug during `pod install`

## Tips for Claude Code

1. **Mouse Mode** - Navigate the UI, click buttons, scroll output
2. **Text Mode** - Use D-pad for cursor movement in text fields
3. **Voice Input** - Quickly dictate prompts or commands
4. **ZL + B** - Interrupt long-running processes (Ctrl+C)
5. **Precision Mode (R3)** - Fine cursor control for small targets

---

**© 2025 Berrry Computer**
