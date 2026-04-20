#!/bin/zsh

# package-release.sh — Build, sign, and package Moku for distribution
#
# Environment variables:
#   VERSION            — App version (e.g. 1.2.0).  default: 1.0.0
#   BUILD_NUMBER       — Build number.               default: 1
#   SIGNING_IDENTITY   — Developer ID certificate.   default: ad-hoc sign (-)
#   APP_NAME           — Application name.            default: Moku
#   BUNDLE_IDENTIFIER  — Bundle ID.                   default: com.mukhtharcm.moku

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="${APP_NAME:-Moku}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.mukhtharcm.moku}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

BUILD_DIR="$PROJECT_DIR/.build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_DIR="$PROJECT_DIR/dist/$VERSION"

echo "╔══════════════════════════════════════════════╗"
echo "║  Moku macOS — Release Build                  ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  App:       $APP_NAME"
echo "║  Version:   $VERSION ($BUILD_NUMBER)"
echo "║  Bundle ID: $BUNDLE_IDENTIFIER"
echo "║  Signing:   $SIGNING_IDENTITY"
echo "╚══════════════════════════════════════════════╝"
echo

# ── Step 1: Generate Xcode project ────────────────────────────────────
echo "→ Generating Xcode project with XcodeGen…"
cd "$PROJECT_DIR"

if ! command -v xcodegen &>/dev/null; then
    echo "ERROR: xcodegen not found. Install with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate --spec project.yml
echo "  ✓ Xcode project generated"

# ── Step 2: Build for release (unsigned) ──────────────────────────────
echo "→ Building $APP_NAME (Release, unsigned)…"

xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -destination "generic/platform=macOS" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -40

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: Built app not found at $APP_PATH" >&2
    echo "  Looking for .app in build products…" >&2
    find "$DERIVED_DATA/Build/Products" -name "*.app" -maxdepth 3 2>/dev/null || true
    exit 1
fi

echo "  ✓ Build succeeded: $APP_PATH"

# ── Step 3: Code sign the app bundle ─────────────────────────────────
ENTITLEMENTS_PATH="$PROJECT_DIR/Moku/App/Moku.entitlements"

if [[ "$SIGNING_IDENTITY" != "-" && -n "$SIGNING_IDENTITY" ]]; then
    echo "→ Signing app with: $SIGNING_IDENTITY"

    # Sign frameworks and libraries first (deep sign)
    find "$APP_PATH/Contents/Frameworks" -type f -perm +111 -o -name "*.dylib" 2>/dev/null | while read -r lib; do
        codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$lib" 2>/dev/null || true
    done

    find "$APP_PATH/Contents/Frameworks" -name "*.framework" 2>/dev/null | while read -r fw; do
        codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$fw" 2>/dev/null || true
    done

    # Sign the main app bundle with entitlements
    codesign --force --sign "$SIGNING_IDENTITY" \
        --timestamp \
        --options runtime \
        --entitlements "$ENTITLEMENTS_PATH" \
        "$APP_PATH"

    echo "  ✓ App signed"

    # Verify
    codesign --verify --deep --strict "$APP_PATH" 2>&1
    codesign -dvvv "$APP_PATH" 2>&1 | grep -E "^(Authority|Identifier|TeamIdentifier)" || true
    echo "  ✓ Signature verified"
else
    echo "→ Skipping code signing (no identity provided)"
    # Ad-hoc sign so the app can at least run
    codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_PATH" 2>/dev/null || true
fi

# ── Step 4: Create distribution directory ─────────────────────────────
echo "→ Preparing distribution artifacts…"
mkdir -p "$DIST_DIR"

# ── Step 5: Create ZIP archive ────────────────────────────────────────
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
echo "→ Creating ZIP: $ZIP_NAME"

cd "$(dirname "$APP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$DIST_DIR/$ZIP_NAME"
echo "  ✓ ZIP created: $DIST_DIR/$ZIP_NAME"

# ── Step 6: Create DMG ───────────────────────────────────────────────
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
echo "→ Creating DMG: $DMG_NAME"

VENV_DIR="$BUILD_DIR/dmgbuild-venv"
if [[ ! -f "$VENV_DIR/bin/dmgbuild" ]]; then
    echo "  Installing dmgbuild…"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet dmgbuild==1.6.7
fi

DMGBUILD="$VENV_DIR/bin/dmgbuild"

# Generate DMG background
DMG_BG_PATH="$BUILD_DIR/dmg-background.png"
if [[ -f "$PROJECT_DIR/Tools/generate-dmg-background.swift" ]]; then
    echo "  Generating DMG background…"
    swift "$PROJECT_DIR/Tools/generate-dmg-background.swift" "$DMG_BG_PATH"
else
    DMG_BG_PATH=""
fi

# Build DMG
export DMG_APP_PATH="$APP_PATH"
export DMG_BACKGROUND_PATH="$DMG_BG_PATH"

"$DMGBUILD" \
    -s "$PROJECT_DIR/Packaging/dmgbuild-settings.py" \
    "$APP_NAME" \
    "$DIST_DIR/$DMG_NAME"

echo "  ✓ DMG created: $DIST_DIR/$DMG_NAME"

# ── Step 7: Sign DMG ─────────────────────────────────────────────────
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    echo "→ Signing DMG…"
    codesign --sign "$SIGNING_IDENTITY" --timestamp "$DIST_DIR/$DMG_NAME"
    echo "  ✓ DMG signed"
fi

# ── Done ──────────────────────────────────────────────────────────────
echo
echo "╔══════════════════════════════════════════════╗"
echo "║  Release artifacts ready                      ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  $DIST_DIR/$ZIP_NAME"
echo "║  $DIST_DIR/$DMG_NAME"
echo "╚══════════════════════════════════════════════╝"
