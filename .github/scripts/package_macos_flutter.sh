#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="${APP_DIR:-$ROOT_DIR/app}"
APP_NAME="${APP_NAME:-Moku}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.moku.moku}"
VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-false}"
NOTARIZE_DMG="${NOTARIZE_DMG:-true}"
NOTARY_ATTEMPTS="${NOTARY_ATTEMPTS:-3}"
ASC_NOTARY_ATTEMPTS="${ASC_NOTARY_ATTEMPTS:-$NOTARY_ATTEMPTS}"
NOTARY_POLL_INTERVAL="${NOTARY_POLL_INTERVAL:-15s}"
NOTARY_TIMEOUT="${NOTARY_TIMEOUT:-30m}"
ASC_UPLOAD_TIMEOUT="${ASC_UPLOAD_TIMEOUT:-5m}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
NOTARYTOOL_KEY_PATH="${NOTARYTOOL_KEY_PATH:-}"
NOTARYTOOL_NO_S3_ACCELERATION="${NOTARYTOOL_NO_S3_ACCELERATION:-false}"
DIST_ROOT="${DIST_ROOT:-$ROOT_DIR/dist/macos}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-$APP_DIR/macos/Runner/Release.entitlements}"

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

derive_pubspec_version() {
  local version_line
  version_line="$(awk '/^version:/ {print $2; exit}' "$APP_DIR/pubspec.yaml")"
  [[ -n "$version_line" ]] || fail "Could not read version from $APP_DIR/pubspec.yaml"

  if [[ -z "$VERSION" ]]; then
    VERSION="${version_line%%+*}"
  fi

  if [[ -z "$BUILD_NUMBER" ]]; then
    if [[ "$version_line" == *"+"* ]]; then
      BUILD_NUMBER="${version_line#*+}"
    else
      BUILD_NUMBER="1"
    fi
  fi
}

create_zip() {
  local app_path="$1"
  local zip_path="$2"
  local app_parent
  local app_basename

  app_parent="$(dirname "$app_path")"
  app_basename="$(basename "$app_path")"
  rm -f "$zip_path"

  (
    cd "$app_parent"
    ditto -c -k --sequesterRsrc --keepParent "$app_basename" "$zip_path"
  )
}

create_dmg() {
  local app_path="$1"
  local dmg_path="$2"
  local dmg_root="$3"

  rm -rf "$dmg_root"
  mkdir -p "$dmg_root"
  ditto "$app_path" "$dmg_root/$APP_NAME.app"
  ln -s /Applications "$dmg_root/Applications"

  rm -f "$dmg_path"
  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$dmg_root" \
    -ov \
    -format UDZO \
    "$dmg_path"
}

notarize_file() {
  local file_path="$1"
  local log_prefix="$2"
  local attempt=1

  [[ -f "$file_path" ]] || fail "Notarization file not found: $file_path"

  while (( attempt <= ASC_NOTARY_ATTEMPTS )); do
    local attempt_log="${log_prefix}-attempt-${attempt}.log"
    log "Notarizing $(basename "$file_path") with asc (attempt $attempt/$ASC_NOTARY_ATTEMPTS)"

    if ASC_UPLOAD_TIMEOUT="$ASC_UPLOAD_TIMEOUT" asc notarization submit \
      --file "$file_path" \
      --wait \
      --poll-interval "$NOTARY_POLL_INTERVAL" \
      --timeout "$NOTARY_TIMEOUT" \
      --output json \
      --pretty 2>&1 | tee "$attempt_log"; then
      cp "$attempt_log" "${log_prefix}.log"
      return 0
    fi

    if (( attempt < ASC_NOTARY_ATTEMPTS )); then
      sleep 15
    fi

    attempt=$((attempt + 1))
  done

  if [[ -n "$NOTARYTOOL_KEY_PATH" && -n "$ASC_KEY_ID" && -n "$ASC_ISSUER_ID" ]]; then
    local notarytool_mode
    local -a notarytool_args

    for notarytool_mode in accelerated no-s3-acceleration; do
      if [[ "$NOTARYTOOL_NO_S3_ACCELERATION" == "true" && "$notarytool_mode" == "accelerated" ]]; then
        continue
      fi

      local fallback_log="${log_prefix}-notarytool-${notarytool_mode}.log"
      log "Falling back to notarytool for $(basename "$file_path") ($notarytool_mode)"

      notarytool_args=(
        xcrun notarytool submit "$file_path"
        --key "$NOTARYTOOL_KEY_PATH"
        --key-id "$ASC_KEY_ID"
        --issuer "$ASC_ISSUER_ID"
        --wait
        --timeout "$NOTARY_TIMEOUT"
        --output-format json
      )

      if [[ "$notarytool_mode" == "no-s3-acceleration" ]]; then
        notarytool_args+=(--no-s3-acceleration)
      fi

      if "${notarytool_args[@]}" 2>&1 | tee "$fallback_log"; then
        cp "$fallback_log" "${log_prefix}.log"
        return 0
      fi
    done
  fi

  return 1
}

sign_app() {
  local app_path="$1"

  [[ -n "$SIGNING_IDENTITY" ]] || fail "SIGNING_IDENTITY is required for signed macOS release artifacts"
  [[ -f "$ENTITLEMENTS_PATH" ]] || fail "Entitlements file not found: $ENTITLEMENTS_PATH"

  log "Signing embedded frameworks"
  if [[ -d "$app_path/Contents/Frameworks" ]]; then
    while IFS= read -r framework_path; do
      codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$framework_path"
    done < <(find "$app_path/Contents/Frameworks" -type d -name "*.framework" -prune | sort)

    while IFS= read -r dylib_path; do
      codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$dylib_path"
    done < <(find "$app_path/Contents/Frameworks" -type f -name "*.dylib" | sort)
  fi

  log "Signing $APP_NAME.app"
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$SIGNING_IDENTITY" \
    "$app_path"
}

verify_signed_app() {
  local app_path="$1"
  local dist_dir="$2"

  log "Verifying code signature"
  codesign --verify --deep --strict --verbose=4 "$app_path"
  codesign -dvvv "$app_path" > "$dist_dir/signature.txt" 2>&1
  codesign --display --entitlements :- "$app_path" > "$dist_dir/entitlements.xml" 2>/dev/null

  if grep -q "com.apple.security.get-task-allow" "$dist_dir/entitlements.xml"; then
    fail "Shipping signature contains com.apple.security.get-task-allow"
  fi

  grep -E "^(Authority|Timestamp|TeamIdentifier|Runtime Version)" "$dist_dir/signature.txt" || true
}

derive_pubspec_version

DIST_DIR="$DIST_ROOT/$VERSION"
WORK_DIR="$DIST_DIR/work"
STAGED_APP="$WORK_DIR/$APP_NAME.app"
FINAL_ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"
FINAL_DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"
NOTARY_ZIP="$DIST_DIR/$APP_NAME-$VERSION-notary.zip"
DMG_ROOT="$WORK_DIR/dmg-root"

log "Release metadata"
printf 'App: %s\n' "$APP_NAME"
printf 'Version: %s (%s)\n' "$VERSION" "$BUILD_NUMBER"
printf 'Bundle ID: %s\n' "$BUNDLE_IDENTIFIER"
printf 'Notarize: %s\n' "$NOTARIZE"

log "Building Flutter macOS release"
(
  cd "$APP_DIR"
  flutter pub get
  flutter build macos \
    --release \
    --build-name="$VERSION" \
    --build-number="$BUILD_NUMBER"
)

BUILT_APP="$(find "$APP_DIR/build/macos/Build/Products/Release" -maxdepth 1 -type d -name "*.app" -print -quit)"
[[ -n "$BUILT_APP" && -d "$BUILT_APP" ]] || fail "No built .app found in $APP_DIR/build/macos/Build/Products/Release"

rm -rf "$DIST_DIR"
mkdir -p "$WORK_DIR"
ditto "$BUILT_APP" "$STAGED_APP"

ACTUAL_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$STAGED_APP/Contents/Info.plist")"
if [[ "$ACTUAL_BUNDLE_ID" != "$BUNDLE_IDENTIFIER" ]]; then
  fail "Built bundle id is $ACTUAL_BUNDLE_ID, expected $BUNDLE_IDENTIFIER"
fi

sign_app "$STAGED_APP"
verify_signed_app "$STAGED_APP" "$DIST_DIR"

if [[ "$NOTARIZE" == "true" ]]; then
  log "Creating notarization ZIP"
  create_zip "$STAGED_APP" "$NOTARY_ZIP"
  notarize_file "$NOTARY_ZIP" "$DIST_DIR/notary-app"

  log "Stapling app notarization ticket"
  xcrun stapler staple "$STAGED_APP"
  xcrun stapler validate "$STAGED_APP"
fi

log "Creating final ZIP"
create_zip "$STAGED_APP" "$FINAL_ZIP"

log "Creating final DMG"
create_dmg "$STAGED_APP" "$FINAL_DMG" "$DMG_ROOT"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$FINAL_DMG"

if [[ "$NOTARIZE" == "true" && "$NOTARIZE_DMG" == "true" ]]; then
  notarize_file "$FINAL_DMG" "$DIST_DIR/notary-dmg"

  log "Stapling DMG notarization ticket"
  xcrun stapler staple "$FINAL_DMG"
  xcrun stapler validate "$FINAL_DMG"
fi

log "Verifying packaged artifacts"
hdiutil verify "$FINAL_DMG"
ls -lh "$FINAL_ZIP" "$FINAL_DMG"

log "macOS release artifacts ready"
printf '%s\n' "$FINAL_ZIP"
printf '%s\n' "$FINAL_DMG"
