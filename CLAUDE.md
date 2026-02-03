# berrry-joyful - Joy-Con Mac Control App

## Project Overview

berrry-joyful is a macOS application that enables Mac control using Nintendo Joy-Con controllers. The app provides multiple control modes including mouse control, keyboard input, and voice commands, all accessible through Joy-Con button combinations.

## Tech Stack

- **Language**: Swift 5.9
- **Platform**: macOS 14.0+
- **Frameworks**:
  - Cocoa (AppKit)
  - JoyConSwift (vendored) - Joy-Con controller support
  - Speech (for voice input)
- **Build System**: XcodeGen + Xcode
- **Project Configuration**: `project.yml`

## Project Structure

```
berrry-joyful/
├── Sources/
│   ├── AppDelegate.swift          # Main application delegate
│   ├── ViewController.swift       # Main view controller
│   ├── InputController.swift      # Handles mouse/keyboard simulation
│   ├── VoiceInputManager.swift    # Voice recognition and commands
│   ├── ControlMode.swift          # Control mode enumerations
│   ├── StatusOverlay.swift        # On-screen status display
│   ├── main.swift                 # Entry point
│   ├── Info.plist                 # App metadata
│   ├── berrry-joyful.entitlements # Security entitlements
│   └── JoyConSwift/               # Vendored JoyConSwift library
│       ├── Controller.swift
│       ├── JoyCon.swift
│       ├── JoyConManager.swift
│       ├── Utils.swift            # Contains pointer alignment fix
│       ├── controllers/           # Controller subclasses
│       └── ...
├── project.yml                    # XcodeGen configuration
└── berrry-joyful.xcodeproj/       # Generated Xcode project
```

## Key Components

### AppDelegate.swift
- Manages application lifecycle
- Sets up menu bar
- Handles controller monitoring
- Creates and manages main window

### ViewController.swift
- Main UI management
- Controller input handling
- Mode switching logic
- Status overlay coordination

### InputController.swift
- Simulates mouse movements and clicks
- Simulates keyboard input
- Handles accessibility permissions
- Manages modifier keys (Cmd, Shift, etc.)

### VoiceInputManager.swift
- Speech recognition integration
- Voice command processing
- Microphone permission handling
- Real-time transcription

### ControlMode.swift
- Defines control modes (mouse, keyboard, voice)
- Modifier state management
- Input settings configuration

### StatusOverlay.swift
- On-screen overlay windows
- Help screen display
- Mode indicators

### JoyConSwift (Vendored)
- IOKit wrapper for Joy-Con and Pro Controller
- See `Sources/JoyConSwift/CLAUDE.md` for details
- Contains fix for pointer alignment crash

## Build Instructions

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)

### Initial Setup

1. **Generate Xcode project**:
   ```bash
   xcodegen
   ```

### Building

1. **Build from command line**:
   ```bash
   xcodebuild -project berrry-joyful.xcodeproj -scheme berrry-joyful -configuration Debug build
   ```

2. **Run the app**:
   ```bash
   open ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Debug/berrry-joyful.app
   ```

### Development Workflow

1. Make code changes in `Sources/` directory
2. If adding new `.swift` files, run `xcodegen` to update the Xcode project
3. Build using Xcode (open `berrry-joyful.xcodeproj`) or `xcodebuild`

## Permissions Required

The app requires the following macOS permissions:

1. **Accessibility Access**: Required for simulating mouse and keyboard input
   - System Settings → Privacy & Security → Accessibility → Enable for berrry-joyful

2. **Microphone Access**: Required for voice input features
   - System Settings → Privacy & Security → Microphone → Enable for berrry-joyful

The app will prompt for these permissions on first launch.

## Features

- **Mouse Control**: Use Joy-Con as a mouse with adjustable sensitivity
- **Keyboard Input**: Simulate keyboard presses and key combinations
- **Voice Commands**: Voice-activated commands and text input
- **Mode Switching**: Seamlessly switch between control modes
- **On-Screen Overlay**: Visual feedback for current mode and status
- **Help Screen**: Built-in help overlay with keyboard shortcuts

## Controller Support

- Nintendo Joy-Con (L/R) - via vendored JoyConSwift
- Nintendo Pro Controller - via vendored JoyConSwift
- Automatic controller detection via IOHIDManager
- Direct HID communication for full Joy-Con feature access

## Important Notes

### XcodeGen Usage
- This project uses **XcodeGen** to generate the Xcode project file
- The `project.yml` file is the source of truth for project configuration
- **Never manually edit** `berrry-joyful.xcodeproj/project.pbxproj`
- Always run `xcodegen` after:
  - Adding or removing source files
  - Changing build settings in `project.yml`
  - Updating entitlements

### Adding New Files
1. Add the `.swift` file to `Sources/` directory
2. Run `xcodegen` to regenerate the project
3. Build and run

### Entitlements
The app uses hardened runtime and requires specific entitlements for USB/HID access to communicate with Joy-Con controllers. These are configured in `Sources/berrry-joyful.entitlements`.

## Bundle Identifier

`app.berrry.joyful`

## Branding

This is a **Berrry Computer** branded application. The branding reflects the Berrry Computer aesthetic and design language.

## Development Tips

- Use XcodeGen for all project structure changes
- Test with actual Joy-Con controllers for best results
- Monitor Console.app for debugging accessibility and permission issues
- The app uses a programmatic UI (no storyboards)

## Troubleshooting

### Build Failures
1. Run `xcodegen` to regenerate project
2. Clean build folder: `xcodebuild clean`
3. Check that all Swift files in `Sources/` are valid

### Missing Files in Build
- Run `xcodegen` - it automatically picks up all files in `Sources/`

### Permissions Issues
- Grant Accessibility and Microphone permissions in System Settings
- Restart the app after granting permissions

### JoyConSwift Pointer Alignment

The vendored JoyConSwift in `Sources/JoyConSwift/` already includes the fix for the pointer alignment crash. The fix is in `Utils.swift` which uses safe byte-by-byte reading instead of `withMemoryRebound`.

If you ever need to update JoyConSwift from upstream, make sure to apply this fix to `Utils.swift`.
