# JoyConSwift - Vendored Library

## Overview

This is a vendored copy of [JoyConSwift](https://github.com/magicien/JoyConSwift) by magicien, an IOKit wrapper for Nintendo Joy-Con and Pro Controller on macOS.

**License**: MIT (see LICENSE file)

## Why Vendored?

JoyConSwift is vendored directly into this project instead of using CocoaPods because:

1. **Pointer alignment fix** - The original library has a bug in `Utils.swift` that causes crashes with `Fatal error: self must be a properly aligned pointer`. Our vendored version uses safe byte-by-byte reading instead of `withMemoryRebound`.

2. **Direct source editing** - Allows modifying the library source directly for debugging or customization without managing patches.

3. **Simplified build** - No need for CocoaPods, workspace files, or `pod install`. Just `xcodegen && xcodebuild`.

## Files

```
JoyConSwift/
├── Controller.swift       # Base controller class
├── JoyCon.swift           # Enums (Button, ControllerType, etc.)
├── JoyConManager.swift    # IOHIDManager wrapper, controller detection
├── HomeLEDPattern.swift   # Home button LED pattern struct
├── Rumble.swift           # Rumble frequency enums
├── Subcommand.swift       # Bluetooth HID subcommand types
├── Utils.swift            # Safe byte reading utilities (PATCHED)
├── LICENSE                # MIT license
├── CLAUDE.md              # This file
└── controllers/
    ├── ProController.swift
    ├── JoyConL.swift
    ├── JoyConR.swift
    ├── FamicomController1.swift
    ├── FamicomController2.swift
    └── SNESController.swift
```

## Key Classes

### JoyConManager
The main entry point. Creates an IOHIDManager to detect controller connections.

```swift
let manager = JoyConManager()
manager.connectHandler = { controller in
    print("Connected: \(controller.type)")
}
manager.runAsync()  // Start monitoring in background thread
```

### Controller
Base class for all controllers. Provides:
- Button press/release handlers
- Stick position handlers
- Battery status
- Rumble support
- SPI flash reading (calibration data, colors)

### JoyCon (enum)
Contains nested enums for:
- `ControllerType` - JoyConL, JoyConR, ProController, etc.
- `Button` - A, B, X, Y, ZL, ZR, etc.
- `StickDirection` - Up, Down, Left, Right, Neutral, etc.
- `BatteryStatus` - full, medium, low, critical, empty

## Important: Utils.swift Patch

The `Utils.swift` file contains patched versions of the byte reading functions. The original code used:
```swift
// UNSAFE - can crash on unaligned pointers
ptr.withMemoryRebound(to: Int16.self, capacity: 1) { $0.pointee }
```

Our patched version uses safe byte-by-byte reading:
```swift
// SAFE - works on any pointer alignment
let byte0 = Int16(ptr[0])
let byte1 = Int16(ptr[1])
return byte0 | (byte1 << 8)
```

**Do not revert this change** - it will cause crashes when reading controller data.

## Usage in berrry-joyful

Since JoyConSwift is now part of the same module, there's no need for `import JoyConSwift`. Just use the classes directly:

```swift
// In AppDelegate.swift or ViewController.swift
var joyConManager: JoyConManager!
// No import needed - it's the same module
```

## Upstream

Original repository: https://github.com/magicien/JoyConSwift
Version vendored: 0.2.1 (with pointer alignment fix)
