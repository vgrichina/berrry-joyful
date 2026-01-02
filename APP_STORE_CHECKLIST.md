# App Store Submission Checklist

This checklist covers everything needed to submit berrry-joyful to the Mac App Store.

## Current Status: NOT READY FOR SUBMISSION

**Last Updated**: 2025-12-29

---

## Phase 1: Apple Developer Account Setup

### Account & Certificates
- [ ] **Enroll in Apple Developer Program** ($99/year)
  - Visit: https://developer.apple.com/programs/
  - Required for Mac App Store distribution
  - Processing time: ~24-48 hours after payment

- [ ] **Generate Mac App Distribution Certificate**
  - Xcode → Settings → Accounts → Manage Certificates
  - Click "+" → Mac App Distribution
  - Or use Apple Developer portal

- [ ] **Create App Store Provisioning Profile**
  - Visit: https://developer.apple.com/account/resources/profiles/
  - Type: Mac App Store
  - Bundle ID: app.berrry.joyful
  - Include Distribution certificate

- [ ] **Configure Team ID in project**
  - Update `project.yml` with your Team ID
  - Set `DEVELOPMENT_TEAM` setting
  - Run `xcodegen` to regenerate project

---

## Phase 2: App Preparation

### Code & Build Configuration

- [ ] **Enable App Sandbox**
  - Add to `Sources/berrry-joyful.entitlements`:
    ```xml
    <key>com.apple.security.app-sandbox</key>
    <true/>
    ```
  - Test all functionality with sandbox enabled
  - Verify Joy-Con connectivity still works (USB/Bluetooth entitlements)

- [ ] **Test with Hardened Runtime**
  - Already enabled in project
  - Verify no crashes or permission issues

- [ ] **Update Build Settings**
  - Set CODE_SIGN_STYLE to "Manual"
  - Set CODE_SIGN_IDENTITY to "3rd Party Mac Developer Application"
  - Set PROVISIONING_PROFILE to your profile UUID
  - Set DEVELOPMENT_TEAM to your Team ID

- [ ] **Verify Entitlements**
  - ✓ `com.apple.security.device.usb` (for Joy-Con HID)
  - ✓ `com.apple.security.device.bluetooth` (for Joy-Con pairing)
  - ✓ `com.apple.security.device.audio-input` (for microphone)
  - [ ] `com.apple.security.app-sandbox` (REQUIRED for App Store)

- [ ] **Test Build with Release Configuration**
  ```bash
  xcodebuild -workspace berrry-joyful.xcworkspace \
    -scheme berrry-joyful \
    -configuration Release \
    clean archive \
    -archivePath ~/Desktop/berrry-joyful.xcarchive
  ```

- [ ] **Verify App Functionality with Sandbox**
  - Controller detection works
  - Mouse/keyboard control works
  - Voice input works
  - Settings persist
  - No crashes or errors

### App Assets

- [ ] **Create App Icon** (CRITICAL - REQUIRED)
  - Sizes needed for macOS:
    - 16x16 @1x and @2x
    - 32x32 @1x and @2x
    - 128x128 @1x and @2x
    - 256x256 @1x and @2x
    - 512x512 @1x and @2x
  - Format: PNG, no transparency
  - Tool: Use Xcode Asset Catalog or Icon Composer
  - Add to project via XcodeGen `project.yml`
  - Design notes: Joy-Con inspired, professional, recognizable at small sizes

- [ ] **Update Info.plist with Icon**
  - Add `CFBundleIconFile` key
  - Or use Asset Catalog `AppIcon` set

### Version & Metadata

- [ ] **Set Marketing Version**
  - Currently: 1.0
  - Decide on version number (recommend: 1.0.0)
  - Update in `project.yml` → `CFBundleShortVersionString`

- [ ] **Set Build Number**
  - Currently: 1
  - Each submission needs unique build number
  - Auto-increment for each upload
  - Update in `project.yml` → `CFBundleVersion`

---

## Phase 3: Legal & Privacy Documents

### Required Documents

- [ ] **Privacy Policy** (REQUIRED)
  - Document what data is collected (none in your case)
  - Explain permission usage (Accessibility, Microphone)
  - Provide user rights information
  - Host online with accessible URL
  - See: `PRIVACY_POLICY.md` (created)

- [ ] **License File** (Recommended)
  - Choose license for your code (MIT, Apache, GPL, Proprietary)
  - Add LICENSE file to repository
  - Mention in README
  - See: `LICENSE` (created)

- [ ] **Export Compliance**
  - Determine if app uses encryption
  - berrry-joyful: NO encryption → select "No" in App Store Connect
  - Bluetooth/USB communication is not "encryption"

### Third-Party Acknowledgments

- [ ] **JoyConSwift License Attribution**
  - Already have: `Pods/Target Support Files/.../acknowledgements.markdown`
  - Consider adding "Acknowledgments" in app menu or About dialog
  - MIT License allows commercial use

---

## Phase 4: App Store Connect Setup

### Create App Record

- [ ] **Log into App Store Connect**
  - Visit: https://appstoreconnect.apple.com
  - Use Apple Developer account

- [ ] **Create New App**
  - Click "+" → New App
  - Platform: macOS
  - Name: berrry-joyful
  - Primary Language: English (U.S.)
  - Bundle ID: app.berrry.joyful
  - SKU: Choose unique identifier (e.g., BERRRY-JOYFUL-001)
  - User Access: Full Access

### App Information

- [ ] **Category**
  - Primary: Utilities
  - Secondary: Productivity (optional)

- [ ] **App Subtitle** (max 30 characters)
  - Example: "Joy-Con Mac Controller"

- [ ] **Keywords** (max 100 characters, comma-separated)
  - Example: "joycon,nintendo,controller,gamepad,accessibility,input,mouse,keyboard,voice"

- [ ] **Support URL** (REQUIRED)
  - Options:
    - GitHub issues: https://github.com/vgrichina/berrry-joyful/issues
    - Website: Create simple support page
    - Email: support@berrry.app (set up email)

- [ ] **Marketing URL** (Optional)
  - GitHub repo: https://github.com/vgrichina/berrry-joyful
  - Or create dedicated website

- [ ] **Privacy Policy URL** (REQUIRED)
  - Host privacy policy online
  - Options: GitHub Pages, website, gist
  - Example: https://vgrichina.github.io/berrry-joyful/privacy

### App Description

- [ ] **App Description** (max 4000 characters)
  ```
  Transform your Mac workflow with Nintendo Joy-Con controllers.

  berrry-joyful brings intuitive controller input to macOS, perfect for
  terminal workflows, coding with Claude Code, and hands-free computing.

  FEATURES:
  • Full mouse control with analog stick precision
  • Keyboard shortcuts via face buttons and D-pad
  • Voice-to-text dictation (hold ZL+ZR to speak)
  • Real-time configuration with modern tabbed UI
  • Debug log for troubleshooting
  • Privacy-first design with no data collection

  UNIFIED CONTROL MODE:
  All controls work simultaneously - move cursor, scroll, press keys,
  and dictate text without switching modes.

  PERFECT FOR:
  • Claude Code and terminal work
  • Accessibility needs
  • Hands-free computing
  • Ergonomic input alternatives
  • Couch computing

  REQUIREMENTS:
  • macOS 14.0 or later
  • Nintendo Joy-Con controllers (L, R, or both)
  • Accessibility permission for input control
  • Microphone permission for voice input (optional)

  PRIVACY:
  • No internet connection
  • No analytics or tracking
  • All data stays on your Mac
  • Settings saved locally

  By Berrry Computer
  ```

- [ ] **What's New** (for version updates)
  - For v1.0: "Initial release"
  - For future updates: Describe new features/fixes

- [ ] **Promotional Text** (max 170 characters, updatable anytime)
  - Example: "Control your Mac with Joy-Con controllers. Perfect for Claude Code workflows. Privacy-first, no data collection."

### Screenshots (REQUIRED - minimum 3)

- [ ] **Create Screenshots**
  - Size: 1280x800 or 2560x1600 (16:10 ratio)
  - Minimum: 3 screenshots
  - Maximum: 10 screenshots
  - Show:
    1. Main UI with controller connected
    2. Mouse control in action
    3. Voice input demonstration
    4. Keyboard tab configuration
    5. Debug log view (optional)
  - Add captions explaining each feature
  - Use high-quality, clear images

- [ ] **App Preview Video** (Optional but recommended)
  - Max length: 30 seconds
  - Show app in action with Joy-Con
  - Demonstrate key features
  - Format: .mov, .m4v, .mp4

### App Review Information

- [ ] **Contact Information**
  - First Name, Last Name
  - Phone Number
  - Email Address
  - All private, only for Apple reviewers

- [ ] **Demo Account** (if needed)
  - Not needed for berrry-joyful (no login required)

- [ ] **Notes for Reviewer**
  ```
  This app requires Nintendo Joy-Con controllers to test properly.

  TESTING INSTRUCTIONS:
  1. Pair Joy-Con via Bluetooth (System Settings → Bluetooth)
  2. Grant Accessibility permission when prompted
  3. App will detect controller automatically
  4. Move left stick to control mouse
  5. Press A, B, X, Y for keyboard input
  6. Hold ZL+ZR and speak to test voice input

  IMPORTANT:
  - Voice input requires microphone permission (optional)
  - Accessibility permission is required for mouse/keyboard control
  - No internet connection needed - fully offline app

  The app uses JoyConSwift (MIT License) for Joy-Con communication.
  ```

### Pricing & Availability

- [ ] **Price**
  - Free (recommended for v1.0)
  - Or set price tier

- [ ] **Availability**
  - All territories, or select specific countries
  - Launch date: Manual or automatic

### Age Rating

- [ ] **Complete Age Rating Questionnaire**
  - Violence: None
  - Sexual Content: None
  - Horror: None
  - Gambling: None
  - Drugs: None
  - Expected Rating: 4+ (Everyone)

---

## Phase 5: Build & Upload

### Archive & Export

- [ ] **Create Archive**
  ```bash
  xcodebuild -workspace berrry-joyful.xcworkspace \
    -scheme berrry-joyful \
    -configuration Release \
    clean archive \
    -archivePath ~/Desktop/berrry-joyful.xcarchive
  ```

- [ ] **Validate Archive**
  - Xcode → Organizer → Archives
  - Select archive → Validate App
  - Choose Mac App Store distribution
  - Fix any validation errors

- [ ] **Export for App Store**
  - Organizer → Distribute App
  - Choose: App Store Connect
  - Upload to App Store Connect
  - Or export .pkg and use Transporter app

- [ ] **Upload with Transporter** (alternative)
  - Export signed .pkg from Xcode
  - Open Transporter app
  - Drag .pkg to upload
  - Wait for processing (~5-30 minutes)

### TestFlight (Optional but Recommended)

- [ ] **Enable TestFlight Beta Testing**
  - App Store Connect → TestFlight tab
  - Add internal testers (up to 100)
  - Test app thoroughly before public release
  - Gather feedback from beta testers

- [ ] **Create External Test Group** (optional)
  - Requires App Review for public beta
  - Share TestFlight link publicly
  - Gather broader feedback

---

## Phase 6: App Review Submission

### Pre-Submission Checklist

- [ ] **All metadata complete**
  - App description written
  - Screenshots uploaded (minimum 3)
  - Keywords set
  - Support URL provided
  - Privacy policy URL provided

- [ ] **Build uploaded and processed**
  - Check App Store Connect for processing status
  - Select build for submission

- [ ] **Age rating complete**

- [ ] **Pricing set**

- [ ] **Review information provided**
  - Contact details
  - Testing notes

- [ ] **Export compliance answered**

### Submit for Review

- [ ] **Click "Submit for Review"**
  - Review all information one final time
  - Confirm submission

- [ ] **Monitor Review Status**
  - Waiting for Review: ~1-3 days
  - In Review: ~24-48 hours
  - Resolution: Approved or Rejected

### If Rejected

- [ ] **Read rejection reason carefully**
- [ ] **Fix issues cited by reviewer**
- [ ] **Respond in Resolution Center** (if clarification needed)
- [ ] **Upload new build** (if code changes required)
- [ ] **Resubmit for review**

### If Approved

- [ ] **App goes live automatically** (or on scheduled date)
- [ ] **Download from Mac App Store to verify**
- [ ] **Update README with App Store link**
- [ ] **Announce release** (social media, blog, etc.)

---

## Phase 7: Post-Launch

### Marketing & Distribution

- [ ] **Add App Store Badge to README**
  ```markdown
  [![Download on the Mac App Store](badge.svg)](https://apps.apple.com/app/idXXXXXXXX)
  ```

- [ ] **Update Repository**
  - Add App Store link
  - Update installation instructions
  - Mention App Store as preferred distribution method

- [ ] **Create Landing Page** (optional)
  - GitHub Pages
  - Dedicated website
  - Feature highlights, screenshots, download link

### Monitoring & Updates

- [ ] **Monitor App Analytics**
  - App Store Connect → Analytics
  - Track downloads, crashes, user engagement

- [ ] **Respond to Reviews**
  - App Store Connect → Ratings and Reviews
  - Reply to user feedback professionally

- [ ] **Plan Updates**
  - Bug fixes
  - New features
  - macOS version updates
  - Increment build/version numbers for each update

- [ ] **Create Update Workflow**
  - Fix issues → Test → Update version → Archive → Upload → Submit

---

## Quick Reference: Files to Create/Update

### New Files to Create
- [x] `APP_STORE_CHECKLIST.md` (this file)
- [ ] `APP_STORE_ASSETS.md` (asset creation guide)
- [x] `PRIVACY_POLICY.md` (privacy documentation)
- [x] `LICENSE` (code license)
- [ ] App icon files (AppIcon.appiconset/)
- [ ] Screenshots (for App Store Connect)

### Files to Update
- [ ] `project.yml` (Team ID, code signing)
- [ ] `Sources/berrry-joyful.entitlements` (add sandbox)
- [ ] `README.md` (add App Store link when live)
- [ ] `CLAUDE.md` (add App Store build instructions)

### Files to Host Online
- [ ] Privacy Policy (GitHub Pages or website)
- [ ] Support page (or use GitHub Issues)

---

## Estimated Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Developer Account Setup | 2-3 days | Includes approval wait |
| App Preparation | 1-2 days | Icon design, sandbox testing |
| Documentation | 4-6 hours | Privacy policy, legal docs |
| App Store Connect Setup | 2-3 hours | Metadata, screenshots |
| Build & Upload | 1-2 hours | Archive, validate, upload |
| App Review | 2-7 days | Apple's review process |
| **Total** | **5-14 days** | Excluding design iterations |

---

## Critical Blockers (Must Do First)

1. **App Icon** - Cannot submit without icon
2. **Apple Developer Account** - Cannot upload without membership
3. **Privacy Policy URL** - Required field in App Store Connect
4. **Screenshots** - Minimum 3 required
5. **App Sandbox** - Must enable and test for App Store approval

---

## Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [macOS App Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Sandboxing Your Mac App](https://developer.apple.com/documentation/security/app_sandbox)

---

**Next Steps**: Start with Phase 1 (Developer Account) and Phase 2 (App Icon). These are prerequisites for everything else.
