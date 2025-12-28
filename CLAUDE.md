# berrry-joyful - Joy-Con Mac Control App

## Project Overview

berrry-joyful is a macOS application that enables Mac control using Nintendo Joy-Con controllers. The app provides multiple control modes including mouse control, keyboard input, and voice commands, all accessible through Joy-Con button combinations.

## Tech Stack

- **Language**: Swift 5.9
- **Platform**: macOS 14.0+
- **Frameworks**:
  - Cocoa (AppKit)
  - GameController
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
│   └── berrry-joyful.entitlements # Security entitlements
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

## Build Instructions

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)

### Building

1. **Regenerate Xcode project** (required after adding/removing files):
   ```bash
   xcodegen
   ```

2. **Build from command line**:
   ```bash
   xcodebuild -project berrry-joyful.xcodeproj -scheme berrry-joyful -configuration Release build
   ```

3. **Run the app**:
   ```bash
   open /Users/$USER/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app
   ```

### Development Workflow

1. Make code changes in `Sources/` directory
2. If adding new `.swift` files, run `xcodegen` to update the Xcode project
3. Build and test using Xcode or `xcodebuild`

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

- Nintendo Joy-Con (L/R)
- Other GameController-compatible controllers
- Automatic controller detection and connection

## Important Notes

### XcodeGen Usage
- This project uses **XcodeGen** to generate the Xcode project file
- The `project.yml` file is the source of truth for project configuration
- **Never manually edit** `berrry-joyful.xcodeproj/project.pbxproj`
- Always run `xcodegen` after:
  - Adding or removing source files
  - Changing build settings in `project.yml`
  - Updating dependencies or entitlements

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
