# Changelog

All notable changes to Berrry Joyful will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-02-04

### Added
- Initial public release of Berrry Joyful
- Full Joy-Con controller support (L, R, Pro Controller)
- Mouse control with analog stick (left stick moves cursor, right stick scrolls)
- Keyboard input simulation via face buttons and D-pad
- Voice-to-text dictation (hold ZL+ZR to speak)
- Profile system with three built-in profiles:
  - Desktop: Arrow key navigation, tab switching, general productivity
  - Media: Volume/playback controls on D-pad
  - Gaming: FPS-style WASD movement and mouse aim
- Custom profile creation and editing
- Menu bar app with quick profile switching
- App runs in background when window is closed
- Modern toolbar UI with segmented control
- Permissions screen on first launch
- App icon with proper macOS transparency and corner radius
- Privacy-first design (no data collection, fully offline)
- Hardened runtime security
- Support for macOS 14.0+

### Technical
- Built with Swift 5.9 and AppKit (programmatic UI, no storyboards)
- Vendored JoyConSwift library for direct HID communication
- XcodeGen-based project configuration
- CGEvent API for mouse/keyboard simulation
- Speech framework for on-device voice recognition
- Developer ID code signing support
- Notarization support for distribution

[Unreleased]: https://github.com/berrry-computer/berrry-joyful/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/berrry-computer/berrry-joyful/releases/tag/v0.5.0
