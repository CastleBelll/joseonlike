#!/usr/bin/env bash
# Reproducible local/CI export for JOSEONLIKE.
#
# Usage: tools/ci/export.sh <android|ios|windows> [debug|release]
#
# Secrets are never read from export_presets.cfg (committed) — this script
# writes a gitignored export_credentials.cfg at the project root from
# environment variables, which Godot 4.3+ merges over export_presets.cfg
# at export time. See docs/CI.md for the full env var list per platform.
set -euo pipefail

PLATFORM="${1:-}"
BUILD_TYPE="${2:-release}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CREDENTIALS_FILE="$PROJECT_ROOT/export_credentials.cfg"
GODOT_BIN="${GODOT:-godot}"
GODOT_VERSION="4.7.stable"

usage() {
  echo "Usage: $0 <android|ios|windows> [debug|release]" >&2
  exit 1
}

fail() {
  echo "::error::$1" >&2
  exit 1
}

[ -n "$PLATFORM" ] || usage
case "$BUILD_TYPE" in
  debug|release) ;;
  *) usage ;;
esac

command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "Godot binary not found (looked for '$GODOT_BIN'). Set \$GODOT or install Godot $GODOT_VERSION."

# Preflight: export templates must be installed for the pinned Godot version.
TEMPLATE_DIRS=(
  "$HOME/.local/share/godot/export_templates/$GODOT_VERSION"
  "$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
  "${APPDATA:-}/Godot/export_templates/$GODOT_VERSION"
)
templates_found=false
for dir in "${TEMPLATE_DIRS[@]}"; do
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    templates_found=true
    break
  fi
done
"$templates_found" || fail "Export templates for Godot $GODOT_VERSION not found. Install them via the editor (Editor > Manage Export Templates) or download Godot_v${GODOT_VERSION}_export_templates.tpz and extract to one of: ${TEMPLATE_DIRS[*]}"

mkdir -p "$PROJECT_ROOT/build/$PLATFORM"

write_credentials() {
  echo "$1" > "$CREDENTIALS_FILE"
}

case "$PLATFORM" in
  android)
    PRESET="Android"
    OUT="$PROJECT_ROOT/build/android/joseonlike.apk"
    if [ "$BUILD_TYPE" = "release" ]; then
      : "${ANDROID_KEYSTORE_RELEASE_PATH:?ANDROID_KEYSTORE_RELEASE_PATH is required for a release Android export}"
      : "${ANDROID_KEYSTORE_RELEASE_USER:?ANDROID_KEYSTORE_RELEASE_USER is required for a release Android export}"
      : "${ANDROID_KEYSTORE_RELEASE_PASSWORD:?ANDROID_KEYSTORE_RELEASE_PASSWORD is required for a release Android export}"
      write_credentials "[preset.0.options]

keystore/release=\"${ANDROID_KEYSTORE_RELEASE_PATH}\"
keystore/release_user=\"${ANDROID_KEYSTORE_RELEASE_USER}\"
keystore/release_password=\"${ANDROID_KEYSTORE_RELEASE_PASSWORD}\"
keystore/debug=\"${ANDROID_KEYSTORE_DEBUG_PATH:-}\"
keystore/debug_user=\"${ANDROID_KEYSTORE_DEBUG_USER:-}\"
keystore/debug_password=\"${ANDROID_KEYSTORE_DEBUG_PASSWORD:-}\"
"
    fi
    ;;
  ios)
    PRESET="iOS"
    OUT="$PROJECT_ROOT/build/ios/joseonlike.ipa"
    if [ "$BUILD_TYPE" = "release" ]; then
      : "${IOS_TEAM_ID:?IOS_TEAM_ID is required for a release iOS export}"
      : "${IOS_CODE_SIGN_IDENTITY_RELEASE:?IOS_CODE_SIGN_IDENTITY_RELEASE is required for a release iOS export}"
      : "${IOS_PROVISIONING_PROFILE_UUID_RELEASE:?IOS_PROVISIONING_PROFILE_UUID_RELEASE is required for a release iOS export}"
      write_credentials "[preset.1.options]

application/app_store_team_id=\"${IOS_TEAM_ID}\"
application/code_sign_identity_release=\"${IOS_CODE_SIGN_IDENTITY_RELEASE}\"
application/provisioning_profile_uuid_release=\"${IOS_PROVISIONING_PROFILE_UUID_RELEASE}\"
application/provisioning_profile_uuid_debug=\"${IOS_PROVISIONING_PROFILE_UUID_DEBUG:-}\"
"
    fi
    ;;
  windows)
    PRESET="Windows Desktop"
    OUT="$PROJECT_ROOT/build/windows/joseonlike.exe"
    if [ "$BUILD_TYPE" = "release" ] && [ -n "${WINDOWS_CODESIGN_IDENTITY:-}" ]; then
      : "${WINDOWS_CODESIGN_PASSWORD:?WINDOWS_CODESIGN_PASSWORD is required when WINDOWS_CODESIGN_IDENTITY is set}"
      write_credentials "[preset.2.options]

codesign/identity=\"${WINDOWS_CODESIGN_IDENTITY}\"
codesign/password=\"${WINDOWS_CODESIGN_PASSWORD}\"
"
    fi
    ;;
  *)
    usage
    ;;
esac

EXPORT_FLAG="--export-release"
[ "$BUILD_TYPE" = "debug" ] && EXPORT_FLAG="--export-debug"

echo "Exporting $PRESET ($BUILD_TYPE) -> $OUT"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$EXPORT_FLAG" "$PRESET" "$OUT"

rm -f "$CREDENTIALS_FILE"
echo "Done: $OUT"
