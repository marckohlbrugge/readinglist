#!/usr/bin/env bash
set -euo pipefail

# Build, sign, and package Reading List for Mac App Store submission.
#
# Required environment variables:
#   APPLE_ID          - Apple ID email for altool
#   APPLE_ID_PASSWORD - app-specific password for altool
#
# Optional:
#   BUILD_ARCH        - "arm64", "x86_64", or "universal" (default: universal)
#   VERSION           - version string to embed (default: extracted from git tag or "0.0.0")
#   UPLOAD            - set to "1" to upload to App Store Connect after building

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Reading List"
BUILD_DIR="$PROJECT_DIR/.build"
STAGING_DIR="$BUILD_DIR/mas-staging"
ENTITLEMENTS="$PROJECT_DIR/Entitlements-MAS.plist"
PROVISIONING_PROFILE="$PROJECT_DIR/ReadingList_MAS.provisionprofile"

BUILD_ARCH="${BUILD_ARCH:-universal}"
VERSION="${VERSION:-}"
UPLOAD="${UPLOAD:-0}"

TEAM_ID="Y9VMFY8SNZ"
SIGN_APP="Apple Distribution: Killbridge Ventures Pte. Ltd. ($TEAM_ID)"
SIGN_PKG="3rd Party Mac Developer Installer: Killbridge Ventures Pte. Ltd. ($TEAM_ID)"

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
    info "Building $APP_NAME for Mac App Store (arch: $BUILD_ARCH, version: $VERSION)..."

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

    local bin_path
    bin_path="$(swift build -c release --show-bin-path)"
    local executable="$bin_path/$APP_NAME"

    if [[ ! -f "$executable" ]]; then
        error "Executable not found at $executable after build."
    fi

    # Assemble .app bundle
    rm -rf "$STAGING_DIR"
    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    mkdir -p "$app_bundle/Contents/MacOS"
    mkdir -p "$app_bundle/Contents/Resources"

    cp "$executable" "$app_bundle/Contents/MacOS/$APP_NAME"
    cp "$PROJECT_DIR/Info.plist" "$app_bundle/Contents/Info.plist"
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$app_bundle/Contents/Resources/AppIcon.icns"
    cp "$PROJECT_DIR/Resources/Assets.car" "$app_bundle/Contents/Resources/Assets.car"
    cp "$PROJECT_DIR/Resources/PrivacyInfo.xcprivacy" "$app_bundle/Contents/Resources/PrivacyInfo.xcprivacy"

    # Embed provisioning profile
    cp "$PROVISIONING_PROFILE" "$app_bundle/Contents/embedded.provisionprofile"

    # Strip extended attributes (quarantine flags cause App Store rejection)
    xattr -rc "$app_bundle"

    # Update version in Info.plist
    local plist="$app_bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"

    local build_number
    build_number="$(date +%Y%m%d%H%M%S)"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist"

    info "App bundle assembled at $app_bundle"
}

# ---------------------------------------------------------------------------
# Sign
# ---------------------------------------------------------------------------

sign_app() {
    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    info "Signing $APP_NAME with Apple Distribution certificate..."

    codesign --force \
        --sign "$SIGN_APP" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$app_bundle"

    info "Verifying signature..."
    codesign --verify --strict "$app_bundle"
    info "Signature OK."
}

# ---------------------------------------------------------------------------
# Package
# ---------------------------------------------------------------------------

create_pkg() {
    local app_bundle="$STAGING_DIR/$APP_NAME.app"
    local pkg_path="$BUILD_DIR/Reading-List-${VERSION}-MAS.pkg"

    info "Creating installer package..."

    productbuild \
        --component "$app_bundle" /Applications \
        --sign "$SIGN_PKG" \
        --timestamp \
        "$pkg_path"

    info "Package created: $pkg_path"
}

# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------

upload_pkg() {
    check_env APPLE_ID
    check_env APPLE_ID_PASSWORD

    local pkg_path="$BUILD_DIR/Reading-List-${VERSION}-MAS.pkg"
    info "Uploading to App Store Connect..."

    xcrun altool --upload-app \
        --type macos \
        --file "$pkg_path" \
        --apiKey "${API_KEY:-}" \
        --apiIssuer "${API_ISSUER:-}" \
        2>/dev/null \
    || xcrun altool --upload-app \
        --type macos \
        --file "$pkg_path" \
        --username "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID"

    info "Upload complete."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cd "$PROJECT_DIR"
resolve_version

info "Starting Mac App Store build for $APP_NAME v$VERSION"

build_app
sign_app
create_pkg

if [[ "$UPLOAD" == "1" ]]; then
    upload_pkg
fi

info ""
info "Mac App Store artifacts:"
info "  PKG: $BUILD_DIR/Reading-List-${VERSION}-MAS.pkg"
info ""
if [[ "$UPLOAD" != "1" ]]; then
    info "To upload, run: UPLOAD=1 $0"
    info "  or: xcrun altool --upload-app --type macos --file '$BUILD_DIR/Reading-List-${VERSION}-MAS.pkg' -u \$APPLE_ID -p \$APPLE_ID_PASSWORD --asc-provider $TEAM_ID"
fi
info ""
info "Done!"
