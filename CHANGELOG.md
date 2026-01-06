# Changelog

All notable changes to Berrry Joyful will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - TBD

### Added
- App icon with proper macOS transparency and corner radius specifications

### Added
- Initial release of Berrry Joyful
- Full Joy-Con controller support (L, R, Pro Controller)
- Mouse control with analog stick
- Keyboard input simulation
- Voice-to-text dictation (hold ZL+ZR to speak)
- On-screen status overlay with help display
- Multiple control modes:
  - Mouse mode with configurable sensitivity
  - Keyboard mode with customizable button mappings
  - Voice input mode with real-time transcription
- Accessibility permission handling
- Microphone permission handling
- Automatic controller detection and connection
- Modern tabbed UI for configuration
- Debug log for troubleshooting
- Privacy-first design (no data collection, fully offline)
- Hardened runtime security
- Support for macOS 14.0+

### Technical
- Built with Swift 5.9
- Uses JoyConSwift framework (via CocoaPods)
- XcodeGen-based project configuration
- Automated release build script
- Developer ID code signing support
- Notarization support for distribution

[Unreleased]: https://github.com/vgrichina/berrry-joyful/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/vgrichina/berrry-joyful/releases/tag/v1.0.0
