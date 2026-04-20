#!/bin/zsh

# notarize-release.sh — Submit release artifacts to Apple's notary service
#
# Environment variables (required):
#   VERSION              — The version to notarize (finds DMG in dist/<version>/)
#   APPLE_ID             — Apple ID for notarization
#   APP_SPECIFIC_PASSWORD — App-specific password
#   TEAM_ID              — Apple Developer Team ID
#
# Optional:
#   APP_NAME             — Application name (default: Moku)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="${APP_NAME:-Moku}"
VERSION="${VERSION:?VERSION is required}"
APPLE_ID="${APPLE_ID:?APPLE_ID is required}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required}"
TEAM_ID="${TEAM_ID:?TEAM_ID is required}"

DIST_DIR="$PROJECT_DIR/dist/$VERSION"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
NOTARY_LOG="$DIST_DIR/notary-log.json"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "ERROR: DMG not found: $DMG_PATH" >&2
    exit 1
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  Apple Notarization                           ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  DMG:     $DMG_PATH"
echo "║  Team ID: $TEAM_ID"
echo "╚══════════════════════════════════════════════╝"
echo

# ── Step 1: Submit to notary service ──────────────────────────────────
echo "→ Submitting DMG to Apple's notary service…"

xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --output-format json \
    --wait \
    2>&1 | tee "$NOTARY_LOG"

status=$(python3 -c "import json,sys; d=json.load(open('$NOTARY_LOG')); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")

if [[ "$status" != "Accepted" ]]; then
    echo "ERROR: Notarization failed with status: $status" >&2

    submission_id=$(python3 -c "import json; d=json.load(open('$NOTARY_LOG')); print(d.get('id',''))" 2>/dev/null || echo "")
    if [[ -n "$submission_id" ]]; then
        echo "→ Fetching notarization log…"
        xcrun notarytool log "$submission_id" \
            --apple-id "$APPLE_ID" \
            --password "$APP_SPECIFIC_PASSWORD" \
            --team-id "$TEAM_ID" \
            2>&1 || true
    fi

    exit 1
fi

echo "  ✓ Notarization accepted"

# ── Step 2: Staple notarization ticket ────────────────────────────────
echo "→ Stapling notarization ticket to DMG…"
xcrun stapler staple "$DMG_PATH"
echo "  ✓ Ticket stapled to DMG"

# ── Step 3: Re-create ZIP from the stapled DMG's app ─────────────────
# The ZIP contains the .app — we need to also notarize and staple it
echo "→ Submitting ZIP to Apple's notary service…"

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait \
    2>&1 || true

echo "  ✓ ZIP notarization submitted"

# ── Done ──────────────────────────────────────────────────────────────
echo
echo "╔══════════════════════════════════════════════╗"
echo "║  Notarization complete                        ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  DMG: stapled ✓                               ║"
echo "║  ZIP: submitted ✓                              ║"
echo "╚══════════════════════════════════════════════╝"
