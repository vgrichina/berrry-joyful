# Berrry Joyful

Control your Mac with Nintendo Joy-Con controllers. Optimized for Claude Code and terminal workflows.

**By Berrry Computer**

## Download & Installation

**For End Users**: Download the latest release from [Releases](https://github.com/berrry-computer/berrry-joyful/releases)

1. Download `Berrry-Joyful-v1.0.dmg`
2. Open the DMG and drag the app to Applications
3. Right-click the app and select "Open" (first time only)
4. Grant Accessibility permission when prompted
5. Pair your Joy-Con via Bluetooth and start controlling your Mac!

## Features

- **Unified Control Mode** - Mouse, keyboard, and scroll all active simultaneously
- **Full Mouse Control** - Move cursor with left stick, scroll with right stick
- **Keyboard Input** - Face buttons and D-pad for common keys and navigation
- **Voice Input** - Hold ZL+ZR to dictate text (text-only mode)
- **Modern Tabbed UI** - Configure mouse sensitivity, keyboard layouts, and voice settings
- **Collapsible Debug Log** - Monitor controller events and system messages
- **Permissions-First UX** - Friendly onboarding with clear permission explanations

## Control Scheme

### Unified Control Mode

All controls are active simultaneously when a Joy-Con is connected:

#### Face Buttons
| Button | Action |
|--------|--------|
| **A** | Enter / Confirm |
| **B** | Escape (with Cmd: Ctrl+C interrupt) |
| **X** | Tab (with Cmd: New Tab) |
| **Y** | Space |

#### Triggers & Shoulders
| Input | Action |
|-------|--------|
| **ZL + ZR** | Voice input (hold to speak, release to type) |
| **L** | Option (⌥) modifier |
| **R** | Shift (⇧) modifier |
| **L + R** | Precision mode (slower mouse) |

#### Analog Sticks
| Input | Function |
|-------|----------|
| **Left Stick** | Move mouse cursor |
| **Right Stick** | Scroll (vertical & horizontal) |

#### D-Pad
| Input | Action |
|-------|--------|
| **↑↓←→** | Arrow keys |
| **+ Modifiers** | Works with L/R for modified arrow keys |

#### Menu Buttons
| Button | Action |
|--------|--------|
| **Minus (-)** | Toggle debug log visibility |
| **Plus (+)** | (Currently unassigned) |

## Voice Input

**Hold ZL + ZR** to activate voice input. Speak naturally, then **release both buttons** to type what you said.

Voice input is **text-only** - it types whatever you speak. There are no voice commands.

Example:
1. Hold ZL + ZR
2. Say: "git commit dash m quote added new feature quote"
3. Release buttons
4. Text appears: "git commit -m added new feature"

## User Interface

The app features a modern tabbed interface:

### Connection Header
Shows controller status, battery level (when available), and LED indicators.

### Configuration Tabs

**🖱️ Mouse Tab**
- Sensitivity slider (0.5x - 3.0x)
- Deadzone control (0% - 30%)
- Invert Y-Axis option
- Mouse acceleration toggle

**⌨️ Keyboard Tab**
- Layout presets (Gaming, Text Editing, Media Controls, Custom)
- Button mapping reference
- Current configuration display

**🎤 Voice Tab**
- Live status indicator
- Activation method selection
- Speech recognition settings

### Collapsible Debug Log
Click "▼ Debug Log" to expand/collapse the event log panel at the bottom.

## Requirements

- macOS 14.0+ (Sonoma)
- Nintendo Joy-Con controllers (L, R, or both)
- Accessibility permission (required for mouse/keyboard control)
- Speech Recognition permission (optional, for voice input only)

## Permissions

The app shows a permissions screen on first launch:

### Required: Accessibility
Needed to control mouse and keyboard. Click **GRANT** to open System Settings, enable berrry-joyful in Accessibility, then click Continue.

### Optional: Speech Recognition
Needed for voice input (ZL+ZR). You can skip this and enable it later if desired.

## Building from Source

**For Developers**:

```bash
# Install dependencies
brew install xcodegen
sudo gem install cocoapods

# Install CocoaPods dependencies (includes JoyConSwift)
pod install

# Build using workspace (not .xcodeproj!)
xcodebuild -workspace berrry-joyful.xcworkspace -scheme berrry-joyful -configuration Debug build

# Or open in Xcode
open berrry-joyful.xcworkspace
```

**Important**:
- Always use `berrry-joyful.xcworkspace`, not `.xcodeproj`
- `pod install` automatically patches JoyConSwift pointer alignment bug
- Run `xcodegen` only when adding/removing source files

### Building for Distribution

See [DISTRIBUTION.md](DISTRIBUTION.md) for complete release build instructions including code signing, notarization, and DMG creation.

## Project Structure

```
Sources/
├── main.swift                      # App entry point
├── AppDelegate.swift               # Application lifecycle & controller monitoring
├── PermissionsViewController.swift # First-launch permissions UI
├── ViewController.swift            # Main tabbed UI & Joy-Con input handling
├── InputController.swift           # Mouse/keyboard simulation via CGEvent
├── VoiceInputManager.swift         # Speech recognition (text-only)
├── ControlMode.swift               # Unified control mode & settings
├── Info.plist                      # App configuration
└── berrry-joyful.entitlements      # Security entitlements
```

## Configuration

All settings are accessible via the tabbed UI and persist automatically:

- **Mouse Sensitivity**: Adjust cursor speed (default: 15.0)
- **Deadzone**: Ignore small stick movements (default: 15%)
- **Invert Y**: Flip vertical axis
- **Acceleration**: Enable mouse acceleration curve
- **Keyboard Presets**: Choose layout optimized for different tasks

## Technical Notes

- Pure Swift 5.9 with AppKit (no storyboards, all programmatic UI)
- JoyConSwift library for direct Joy-Con HID communication (via CocoaPods)
- CGEvent API for mouse/keyboard simulation
- Speech framework for voice recognition (on-device, macOS 13+)
- Auto-patches JoyConSwift pointer alignment bug during `pod install`
- Unified control mode: all input methods active simultaneously

## Tips for Claude Code

1. **Navigate quickly** - Left stick for cursor, right stick for scrolling
2. **Voice for long prompts** - Hold ZL+ZR to dictate complex commands
3. **Arrow keys** - Use D-pad for terminal history and cursor movement
4. **Interrupt processes** - Cmd+B (B button with Cmd modifier)
5. **Precision control** - Hold L+R for slow, accurate mouse movement
6. **Debug visibility** - Toggle log with Minus (-) button when troubleshooting

## Troubleshooting

**Controller not detected?**
- Pair Joy-Con via Bluetooth in System Settings
- Check app logs (toggle debug panel with Minus button)

**Mouse/keyboard not working?**
- Grant Accessibility permission in System Settings
- Restart the app after granting permission

**Voice input not working?**
- Grant Speech Recognition permission
- Check microphone privacy settings
- Verify ZL+ZR button combination

**Build errors?**
- Use `.xcworkspace` not `.xcodeproj`
- Run `pod install` to get dependencies
- Clean build folder if issues persist

---

**© 2025 Berrry Computer**
