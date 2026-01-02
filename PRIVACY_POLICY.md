# Privacy Policy for berrry-joyful

**Effective Date**: January 1, 2025
**Last Updated**: December 29, 2024

**By Berrry Computer**

---

## Overview

berrry-joyful ("the App") is a macOS application that enables you to control your Mac using Nintendo Joy-Con controllers. This Privacy Policy explains what information the App collects, how it is used, and your rights regarding your data.

## TL;DR (Summary)

**berrry-joyful collects NO personal data. All data stays on your Mac. No analytics, no tracking, no internet connection.**

---

## Information Collection and Use

### Data We Do NOT Collect

berrry-joyful does NOT collect, store, transmit, or share any of the following:

- Personal information (name, email, phone number, etc.)
- Usage analytics or telemetry
- Crash reports
- Device identifiers
- Location data
- Voice recordings or speech data
- Controller input history
- Keyboard or mouse activity logs
- Any data that leaves your Mac

### Data Stored Locally on Your Mac

The App stores the following preferences locally using macOS UserDefaults:

- **Mouse sensitivity settings** (numeric value)
- **Scroll sensitivity settings** (numeric value)
- **Stick deadzone settings** (numeric value)
- **Voice input language preference** (language code)
- **Button mapping profiles** (JSON-encoded configuration)
- **Debug mode preference** (boolean)

This data:
- Remains exclusively on your Mac
- Is never transmitted over the network
- Is not accessible to Berrry Computer or any third party
- Can be deleted by removing the App

---

## Permissions Required

The App requests the following macOS permissions:

### 1. Accessibility Permission (REQUIRED)

**Purpose**: To simulate mouse movements, clicks, and keyboard input based on Joy-Con controller commands.

**What this means**: The App needs Accessibility access to control your mouse cursor and type on your behalf. This is the core functionality of the App.

**Privacy note**: The App only generates input events when you use your Joy-Con controller. It does not monitor, record, or log any activity on your Mac.

**How to revoke**: System Settings → Privacy & Security → Accessibility → Remove berrry-joyful

### 2. Microphone Permission (OPTIONAL)

**Purpose**: To enable voice-to-text input when you hold ZL+ZR buttons on your Joy-Con.

**What this means**: The App uses macOS Speech Recognition (on-device) to convert your speech into text. Voice input is entirely optional.

**Privacy note**:
- Voice recognition is performed on-device by macOS (not sent to servers)
- The App does not record, store, or transmit any audio
- Audio is processed in real-time and immediately discarded
- If you never use voice input, the microphone permission is never triggered

**How to revoke**: System Settings → Privacy & Security → Microphone → Remove berrry-joyful

### 3. Speech Recognition (OPTIONAL)

**Purpose**: To convert voice to text when using the voice input feature.

**Privacy note**: Uses macOS's built-in on-device speech recognition. No data is sent to external servers.

**How to revoke**: System Settings → Privacy & Security → Speech Recognition → Remove berrry-joyful

---

## Third-Party Services

### No Analytics or Tracking

berrry-joyful does NOT use:
- Google Analytics or similar services
- Crash reporting tools (Crashlytics, Sentry, etc.)
- Advertising networks
- Social media tracking pixels
- Any third-party data collection services

### Third-Party Code

The App uses **JoyConSwift** (v0.2.1), an open-source library (MIT License) for communicating with Nintendo Joy-Con controllers.

- JoyConSwift operates entirely on-device
- It does not collect or transmit any data
- Source code: https://github.com/magicien/JoyConSwift

---

## Network Activity

**berrry-joyful does NOT connect to the internet.**

The App:
- Does not make HTTP/HTTPS requests
- Does not communicate with remote servers
- Does not send or receive data over the network
- Does not require internet access to function

All functionality is completely offline.

---

## Data Sharing and Disclosure

**We do not share any data because we do not collect any data.**

berrry-joyful never shares, sells, or discloses information to:
- Advertisers
- Analytics companies
- Data brokers
- Government agencies (unless legally required and technically possible)
- Any other third parties

---

## Data Security

Since no data is collected or transmitted:
- There is no risk of data breaches involving your personal information
- Your activity with the App is completely private
- All settings are stored securely using macOS's standard UserDefaults mechanism

---

## Children's Privacy

berrry-joyful does not collect any information from anyone, including children under 13. The App is suitable for all ages (rated 4+).

---

## Your Rights

### Data Access
All data stored by the App is accessible to you at:
`~/Library/Preferences/app.berrry.joyful.plist`

You can view this file using:
```bash
defaults read app.berrry.joyful
```

### Data Deletion
To delete all App data:
1. Quit berrry-joyful
2. Run: `defaults delete app.berrry.joyful`
3. Or simply uninstall the App

### Revoking Permissions
You can revoke Accessibility, Microphone, and Speech Recognition permissions at any time via System Settings → Privacy & Security.

---

## macOS Sandbox

When distributed via the Mac App Store, berrry-joyful operates within Apple's App Sandbox. This provides additional security by:
- Restricting file system access
- Preventing unauthorized network connections
- Isolating the App from other applications
- Enforcing security policies at the operating system level

---

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Changes will be posted with a new "Last Updated" date at the top of this document.

Material changes will be communicated via:
- App Store release notes
- GitHub repository updates
- In-app notifications (if applicable)

Your continued use of the App after changes constitutes acceptance of the updated policy.

---

## Contact Us

If you have questions about this Privacy Policy or berrry-joyful's privacy practices:

- **GitHub Issues**: https://github.com/vgrichina/berrry-joyful/issues
- **Email**: [Your support email - to be added]
- **Developer**: Berrry Computer

---

## Legal Basis for Processing (GDPR)

For users in the European Economic Area (EEA):

Since berrry-joyful does not collect or process personal data, GDPR data processing obligations do not apply. The App operates entirely on your local device without any data transfer.

---

## California Privacy Rights (CCPA)

For California residents:

Under the California Consumer Privacy Act (CCPA), you have rights regarding personal information. However, since berrry-joyful does not collect, sell, or share personal information, these rights are not applicable to the App's operation.

---

## Open Source Transparency

berrry-joyful is open source. You can inspect the source code to verify these privacy claims:

**Repository**: https://github.com/vgrichina/berrry-joyful

We encourage technical users to review the code and confirm:
- No network requests are made
- No analytics or tracking code is present
- Only local settings are stored
- Voice data is not recorded or transmitted

---

## Summary of Key Points

| Question | Answer |
|----------|--------|
| Does the App collect personal data? | **NO** |
| Does the App use analytics? | **NO** |
| Does the App connect to the internet? | **NO** |
| Is voice data recorded or transmitted? | **NO** |
| Where is my data stored? | **Only on your Mac** |
| Can I delete my data? | **YES - uninstall the App** |
| Is my data shared with third parties? | **NO - no data to share** |
| Is the App open source? | **YES** |

---

**© 2025 Berrry Computer**

This Privacy Policy is effective as of January 1, 2025.
