# 🫐 berrry-joyful

A simple macOS app to test and map Nintendo Joy-Con controllers using the GameController framework.

**By Berrry Computer**

## Features

- Real-time display of Joy-Con button presses
- Support for all Joy-Con inputs:
  - Face buttons (A, B, X, Y)
  - D-pad
  - Left and right analog sticks
  - Shoulder buttons (L, R)
  - Triggers (ZL, ZR)
  - Menu/Options buttons

## Requirements

- macOS 14.0+
- Xcode
- XcodeGen (for project generation)

## Building

```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project berrry-joyful.xcodeproj -scheme berrry-joyful -configuration Debug build

# Or open in Xcode
open berrry-joyful.xcodeproj
```

## Usage

1. Run the app
2. Connect a Joy-Con controller via Bluetooth
3. Press buttons and move sticks to see inputs logged in the window

## Technical Notes

- Uses programmatic AppKit (no storyboards)
- Explicit `main.swift` for proper NSApplication setup
- GameController framework for controller input handling

---

**© 2025 Berrry Computer**
