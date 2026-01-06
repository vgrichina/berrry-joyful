# Distribution Guide - Berrry Joyful

Complete guide for building, signing, notarizing, and distributing **Berrry Joyful** outside the Mac App Store.

---

## Prerequisites

### Apple Developer Account
- Active Apple Developer Program membership ($99/year)
- Developer ID Application certificate (not App Store certificate)
- App-specific password for notarization

### Tools Required
```bash
# Ensure Xcode Command Line Tools are installed
xcode-select --install

# Verify tools are available
which xcodebuild  # Should output path
which codesign    # Should output path
which xcrun       # Should output path
```

---

## Step 1: Get Developer ID Certificate

1. **Log in to Apple Developer Portal**
   - Go to: https://developer.apple.com/account/resources/certificates/list

2. **Create Developer ID Application Certificate**
   - Click the "+" button
   - Select **"Developer ID Application"** (NOT "Mac App Distribution")
   - Follow the certificate assistant steps
   - Download and install the certificate (double-click to add to Keychain)

3. **Verify Certificate Installation**
   ```bash
   security find-identity -v -p codesigning
   ```
   You should see something like:
   ```
   1) XXXX... "Developer ID Application: Your Name (TEAM_ID)"
   ```

---

## Step 2: Configure App-Specific Password

Required for notarization (Apple no longer accepts regular passwords).

1. **Generate App-Specific Password**
   - Go to: https://appleid.apple.com/account/manage
   - Sign in with your Apple ID
   - Security → App-Specific Passwords → Generate
   - Label it "notarytool" and save the generated password

2. **Store Credentials in Keychain**
   ```bash
   xcrun notarytool store-credentials "notarytool" \
     --apple-id "your-apple-id@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

   Find your Team ID at: https://developer.apple.com/account

---

## Step 3: Build Release Version

```bash
# Clean previous builds
xcodebuild clean -workspace berrry-joyful.xcworkspace -scheme berrry-joyful

# Build Release configuration
xcodebuild -workspace berrry-joyful.xcworkspace \
  -scheme berrry-joyful \
  -configuration Release \
  build

# Built app will be at:
# ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app
```

---

## Step 4: Code Sign the App

```bash
# Find your Developer ID certificate name
CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')

echo "Using certificate: $CERT_NAME"

# Sign the app with hardened runtime and entitlements
codesign --force --deep --sign "$CERT_NAME" \
  --options runtime \
  --entitlements Sources/berrry-joyful.entitlements \
  --timestamp \
  ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app

# Verify signature
codesign --verify --verbose=4 \
  ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app

# Check that it's properly signed (not ad-hoc)
codesign -dv --verbose=4 \
  ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app 2>&1 | grep "Authority"
```

You should see your Developer ID certificate in the Authority chain.

---

## Step 5: Create DMG Package

```bash
# Create a staging directory
mkdir -p dist/dmg-staging
cp -R ~/Library/Developer/Xcode/DerivedData/berrry-joyful-*/Build/Products/Release/berrry-joyful.app \
  dist/dmg-staging/

# Optional: Add README, LICENSE to DMG
cp DISTRIBUTION_README.md dist/dmg-staging/README.txt
cp LICENSE dist/dmg-staging/ 2>/dev/null || echo "No LICENSE file found"

# Create DMG
hdiutil create -volname "Berrry Joyful" \
  -srcfolder dist/dmg-staging \
  -ov -format UDZO \
  dist/Berrry-Joyful-v1.0.dmg

echo "✓ DMG created at: dist/Berrry-Joyful-v1.0.dmg"
```

---

## Step 6: Notarize the DMG

```bash
# Submit DMG for notarization
xcrun notarytool submit dist/Berrry-Joyful-v1.0.dmg \
  --keychain-profile "notarytool" \
  --wait

# This will:
# - Upload the DMG to Apple
# - Wait for Apple's automated security scan (usually 1-5 minutes)
# - Display the results
```

**If notarization succeeds**, you'll see:
```
status: Accepted
```

**If it fails**, check the log:
```bash
# Get the submission ID from the error message, then:
xcrun notarytool log <submission-id> --keychain-profile "notarytool"
```

Common failures:
- App not signed with Developer ID (check Step 4)
- Missing hardened runtime flag
- Invalid entitlements

---

## Step 7: Staple the Notarization Ticket

After successful notarization, attach the ticket to the DMG:

```bash
xcrun stapler staple dist/Berrry-Joyful-v1.0.dmg

# Verify stapling worked
xcrun stapler validate dist/Berrry-Joyful-v1.0.dmg
```

You should see:
```
The validate action worked!
```

---

## Step 8: Test the Distribution

1. **Move the DMG to a different Mac** (or test location)
2. **Open the DMG**
3. **Drag the app to Applications**
4. **Double-click to launch** (should open without warnings)

If Gatekeeper blocks it:
- Right-click → Open (first time only)
- If that doesn't work, check notarization logs

---

## Step 9: Distribute

Your signed and notarized DMG is ready for distribution!

Upload to:
- GitHub Releases
- Your website
- Direct download links
- Email/messaging

Users can download and run immediately without security warnings (on macOS 10.15+).

---

## Automation Script

Create `scripts/release.sh` for automated builds:

```bash
#!/bin/bash
set -e

VERSION="1.0"
APP_NAME="berrry-joyful"
DMG_NAME="Berrry-Joyful-v${VERSION}.dmg"

echo "Building Berrry Joyful v${VERSION}..."

# Find certificate
CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
echo "Using certificate: $CERT_NAME"

# Clean and build
xcodebuild clean -workspace ${APP_NAME}.xcworkspace -scheme ${APP_NAME}
xcodebuild -workspace ${APP_NAME}.xcworkspace \
  -scheme ${APP_NAME} \
  -configuration Release \
  build

# Find built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*/Build/Products/Release -name "${APP_NAME}.app" | head -1)
echo "Built app at: $APP_PATH"

# Sign
echo "Signing..."
codesign --force --deep --sign "$CERT_NAME" \
  --options runtime \
  --entitlements Sources/${APP_NAME}.entitlements \
  --timestamp \
  "$APP_PATH"

# Verify
codesign --verify --verbose=4 "$APP_PATH"

# Create DMG
echo "Creating DMG..."
mkdir -p dist/dmg-staging
cp -R "$APP_PATH" dist/dmg-staging/
hdiutil create -volname "Berrry Joyful" \
  -srcfolder dist/dmg-staging \
  -ov -format UDZO \
  dist/${DMG_NAME}

# Clean staging
rm -rf dist/dmg-staging

# Notarize
echo "Notarizing (this may take a few minutes)..."
xcrun notarytool submit dist/${DMG_NAME} \
  --keychain-profile "notarytool" \
  --wait

# Staple
echo "Stapling notarization ticket..."
xcrun stapler staple dist/${DMG_NAME}
xcrun stapler validate dist/${DMG_NAME}

echo "✓ Release complete: dist/${DMG_NAME}"
echo ""
echo "Next steps:"
echo "1. Test the DMG on a clean Mac"
echo "2. Upload to GitHub Releases"
echo "3. Update download links"
```

Make it executable:
```bash
chmod +x scripts/release.sh
```

---

## Troubleshooting

### "No Developer ID certificate found"
- Ensure you created a **Developer ID Application** certificate (not Mac App Distribution)
- Check it's installed in Keychain Access
- Run: `security find-identity -v -p codesigning`

### "App is damaged and can't be opened"
- App wasn't signed properly
- Re-sign following Step 4 exactly
- Make sure to use `--options runtime` and `--timestamp`

### Notarization fails with "Invalid signature"
- App must be signed with Developer ID (not ad-hoc, not development)
- Check signature: `codesign -dv app.app` should show Developer ID

### "This app needs to be updated"
- Deployment target might be too old
- Ensure `MACOSX_DEPLOYMENT_TARGET` is set correctly (14.0 in project.yml)

### Notarization takes forever
- Usually 1-5 minutes, but can take up to 30 minutes
- Use `--wait` flag to get immediate feedback
- Check status: `xcrun notarytool history --keychain-profile "notarytool"`

---

## Important Notes

### Why Can't This Be in the Mac App Store?

The app requires:
- **Disabled App Sandbox** (`<key>com.apple.security.app-sandbox</key><false/>`)
- **System-wide Accessibility API** access
- **Cross-app input simulation**

These capabilities are **prohibited** in the Mac App Store for security reasons. The app **must** be distributed outside the App Store using Developer ID.

### Security Implications

Users will need to:
1. Right-click → Open the app (first launch only)
2. Grant Accessibility permission
3. Trust the Developer ID signature

This is normal for non-App Store Mac apps with system-level permissions.

---

## Release Checklist

- [ ] Updated version number in `project.yml` (CFBundleShortVersionString)
- [ ] Updated CHANGELOG.md with release notes
- [ ] Developer ID Application certificate installed
- [ ] notarytool credentials stored
- [ ] Clean build succeeds
- [ ] App signed with Developer ID (not ad-hoc)
- [ ] DMG created
- [ ] DMG notarized successfully
- [ ] Notarization ticket stapled
- [ ] Tested on clean Mac (different machine if possible)
- [ ] No Gatekeeper warnings when opening
- [ ] Accessibility permission grants correctly
- [ ] Joy-Con connects and controls work
- [ ] README and documentation updated
- [ ] Git tag created (v1.0)
- [ ] GitHub release published
- [ ] Download links updated

---

**Ready to release!** 🎉

