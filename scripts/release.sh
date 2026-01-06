#!/bin/bash
# Berrry Joyful Release Automation Script
# This script builds, signs, packages, and notarizes the app for distribution

set -e

# Configuration
XCODE_SCHEME="berrry-joyful"
APP_NAME="Berrry Joyful"
VERSION="1.0"
BUNDLE_ID="app.berrry.joyful"
DEVELOPER_ID="Developer ID Application: Vladimir Grichina (9532C74ZP2)"
NOTARY_PROFILE="notarytool"  # Set up with: xcrun notarytool store-credentials

# Paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${PROJECT_ROOT}/berrry-joyful.xcworkspace"
SCHEME="${XCODE_SCHEME}"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${PROJECT_ROOT}/dist"
DMG_STAGING="${DIST_DIR}/dmg-staging"
DMG_NAME="berrry-joyful-v${VERSION}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function check_requirements() {
    log_info "Checking requirements..."

    # Check for xcodebuild
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Install Xcode."
        exit 1
    fi

    # Check for Developer ID certificate
    if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        log_error "Developer ID Application certificate not found"
        log_error "Get one from: https://developer.apple.com/account/resources/certificates/list"
        exit 1
    fi

    log_info "All requirements met ✓"
}

function clean_build() {
    log_info "Cleaning previous builds..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${DIST_DIR}"

    xcodebuild clean -workspace "${WORKSPACE}" -scheme "${SCHEME}" -configuration Release > /dev/null 2>&1
    log_info "Clean complete ✓"
}

function build_app() {
    log_info "Building Release version..."

    xcodebuild -workspace "${WORKSPACE}" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}" \
        build

    APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

    if [ ! -d "${APP_PATH}" ]; then
        log_error "Build failed - app not found at ${APP_PATH}"
        exit 1
    fi

    log_info "Build complete ✓"
}

function sign_app() {
    log_info "Signing app with Developer ID..."

    # Sign frameworks first
    log_info "Signing embedded frameworks..."
    FRAMEWORKS_DIR="${APP_PATH}/Contents/Frameworks"
    if [ -d "${FRAMEWORKS_DIR}" ]; then
        for framework in "${FRAMEWORKS_DIR}"/*.framework; do
            if [ -e "${framework}" ]; then
                log_info "  - Signing $(basename "${framework}")"
                codesign --force --deep --sign "${DEVELOPER_ID}" --timestamp --options runtime "${framework}"
            fi
        done
    fi

    # Sign the main app
    log_info "Signing main app bundle..."
    codesign --force --deep --sign "${DEVELOPER_ID}" --timestamp --options runtime "${APP_PATH}"

    # Verify signature
    log_info "Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}" 2>&1 | grep -q "valid on disk" || {
        log_error "Code signing verification failed"
        exit 1
    }

    log_info "Signing complete ✓"
}

function create_dmg() {
    log_info "Creating DMG..."

    mkdir -p "${DMG_STAGING}"
    mkdir -p "${DIST_DIR}"

    # Copy app to staging
    cp -R "${APP_PATH}" "${DMG_STAGING}/"

    # Create symlink to Applications
    ln -s /Applications "${DMG_STAGING}/Applications"

    # Create DMG
    DMG_PATH="${DIST_DIR}/${DMG_NAME}"
    hdiutil create \
        -volname "${DISPLAY_NAME}" \
        -srcfolder "${DMG_STAGING}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}"

    # Clean up staging
    rm -rf "${DMG_STAGING}"

    if [ ! -f "${DMG_PATH}" ]; then
        log_error "DMG creation failed"
        exit 1
    fi

    log_info "DMG created: ${DMG_PATH} ✓"
}

function notarize_dmg() {
    log_info "Submitting DMG for notarization..."
    log_warn "This may take 1-5 minutes. Please wait..."

    DMG_PATH="${DIST_DIR}/${DMG_NAME}"

    # Check if notary profile exists
    if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" &> /dev/null; then
        log_warn "Notarization profile '${NOTARY_PROFILE}' not configured"
        log_warn "Run this to configure:"
        log_warn "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" \\"
        log_warn "    --apple-id \"your-email@example.com\" \\"
        log_warn "    --team-id \"9532C74ZP2\" \\"
        log_warn "    --password \"xxxx-xxxx-xxxx-xxxx\""
        log_warn "Get app-specific password from: https://appleid.apple.com/account/manage"
        log_warn ""
        log_warn "Skipping notarization for now. DMG will work but show Gatekeeper warning."
        return 0
    fi

    # Submit for notarization
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait

    # Staple the notarization ticket
    log_info "Stapling notarization ticket..."
    xcrun stapler staple "${DMG_PATH}"

    # Validate
    xcrun stapler validate "${DMG_PATH}"

    log_info "Notarization complete ✓"
}

function show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "${GREEN}Release build complete!${NC}"
    echo ""
    echo "  App:     ${APP_PATH}"
    echo "  DMG:     ${DIST_DIR}/${DMG_NAME}"
    echo "  Version: ${VERSION}"
    echo ""
    log_info "Next steps:"
    echo "  1. Test the DMG on a different Mac (or user account)"
    echo "  2. Create GitHub Release with tag v${VERSION}"
    echo "  3. Upload the DMG to GitHub Releases"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Main execution
function main() {
    cd "${PROJECT_ROOT}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ${DISPLAY_NAME} Release Builder"
    echo "  Version ${VERSION}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_requirements
    clean_build
    build_app
    sign_app
    create_dmg
    notarize_dmg
    show_summary
}

main "$@"
