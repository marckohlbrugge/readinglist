#!/usr/bin/env bash
set -euo pipefail

# Build, sign, notarize, and package Reading List for distribution.
#
# Required environment variables:
#   DEVELOPER_ID_APPLICATION  - signing identity, e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID                  - Apple ID email for notarization
#   APPLE_ID_PASSWORD         - app-specific password for notarization
#   TEAM_ID                   - Apple Developer Team ID
#
# Optional:
#   BUILD_ARCH                - "arm64", "x86_64", or "universal" (default: universal)
#   VERSION                   - version string to embed (default: extracted from git tag or "0.0.0")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Reading List"
BUILD_DIR="$PROJECT_DIR/.build"
STAGING_DIR="$BUILD_DIR/release-staging"
DMG_DIR="$BUILD_DIR/dmg-staging"
ENTITLEMENTS="$PROJECT_DIR/Entitlements.plist"

BUILD_ARCH="${BUILD_ARCH:-universal}"
VERSION="${VERSION:-}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { echo "==> $*"; }
error() { echo "ERROR: $*" >&2; exit 1; }

check_env() {
    local var="$1"
    if [[ -z "${!var:-}" ]]; then
        error "Required environment variable $var is not set."
    fi
}

resolve_version() {
    if [[ -n "$VERSION" ]]; then
        return
    fi

    # Try to extract from git tag (v1.2.3 -> 1.2.3)
    if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
        VERSION="$(git describe --tags --exact-match HEAD | sed 's/^v//')"
    else
        VERSION="0.0.0"
        info "WARNING: not on an exact git tag; version set to $VERSION"
    fi
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build_app() {
    info "Building $APP_NAME (arch: $BUILD_ARCH, version: $VERSION)..."

    local arch_flags=()
    case "$BUILD_ARCH" in
        universal)
            arch_flags=(--arch arm64 --arch x86_64)
            ;;
        arm64|x86_64)
            arch_flags=(--arch "$BUILD_ARCH")
            ;;
        *)
            error "Unknown BUILD_ARCH: $BUILD_ARCH (use arm64, x86_64, or universal)"
            ;;
    esac

    swift build -c release "${arch_flags[@]}"

    # SPM creates the .app bundle at .build/<APP_NAME>.app
    local app_bundle="$BUILD_DIR/$APP_NAME.app"
    if [[ ! -d "$app_bundle" ]]; then
        error "App bundle not found at $app_bundle after build."
    fi

    # Copy to staging
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"
    cp -R "$app_bundle" "$STAGING_DIR/"

    # Copy privacy manifest
    cp "$PROJECT_DIR/Resources/PrivacyInfo.xcprivacy" "$STAGING_DIR/$APP_NAME.app/Contents/Resources/PrivacyInfo.xcprivacy"

    # Update version in Info.plist
    local plist="$STAGING_DIR/$APP_NAME.app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"

    local build_number
    build_number="$(date +%Y%m%d%H%M%S)"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist"

    info "App bundle staged at $STAGING_DIR/$APP_NAME.app"
}

# ---------------------------------------------------------------------------
# Sign
# ---------------------------------------------------------------------------

sign_app() {
    check_env DEVELOPER_ID_APPLICATION

    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    info "Signing $APP_NAME..."

    codesign --force --sign "$DEVELOPER_ID_APPLICATION" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$app_bundle"

    info "Verifying signature..."
    codesign --verify --strict "$app_bundle"
    info "Signature OK."
}

# ---------------------------------------------------------------------------
# Notarize
# ---------------------------------------------------------------------------

notarize_app() {
    check_env APPLE_ID
    check_env APPLE_ID_PASSWORD
    check_env TEAM_ID

    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    local zip_path="$STAGING_DIR/$APP_NAME-notarize.zip"

    info "Creating ZIP for notarization..."
    ditto -c -k --keepParent "$app_bundle" "$zip_path"

    info "Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$zip_path" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    info "Stapling notarization ticket..."
    xcrun stapler staple "$app_bundle"

    rm -f "$zip_path"
    info "Notarization complete."
}

# ---------------------------------------------------------------------------
# Package DMG
# ---------------------------------------------------------------------------

create_dmg() {
    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    local dmg_path="$BUILD_DIR/Reading-List-${VERSION}.dmg"

    info "Creating DMG..."

    rm -rf "$DMG_DIR"
    mkdir -p "$DMG_DIR"
    cp -R "$app_bundle" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"

    rm -f "$dmg_path"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov \
        -format UDZO \
        "$dmg_path"

    rm -rf "$DMG_DIR"

    # Sign the DMG itself
    if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$dmg_path"
    fi

    info "DMG created: $dmg_path"
    echo "$dmg_path"
}

# ---------------------------------------------------------------------------
# Create ZIP (for GitHub Releases)
# ---------------------------------------------------------------------------

create_zip() {
    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    local zip_path="$BUILD_DIR/Reading-List-${VERSION}.zip"

    info "Creating ZIP..."
    rm -f "$zip_path"
    ditto -c -k --keepParent "$app_bundle" "$zip_path"

    info "ZIP created: $zip_path"
    echo "$zip_path"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cd "$PROJECT_DIR"
resolve_version

info "Starting release build for $APP_NAME v$VERSION"

build_app
sign_app
notarize_app
create_dmg
create_zip

info ""
info "Release artifacts:"
info "  DMG: $BUILD_DIR/Reading-List-${VERSION}.dmg"
info "  ZIP: $BUILD_DIR/Reading-List-${VERSION}.zip"
info ""
info "Done!"
