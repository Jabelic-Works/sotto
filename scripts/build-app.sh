#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-debug}"
PRODUCT_NAME="Sotto"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "CONFIGURATION must be debug or release" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/.build/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$REPO_ROOT/.build/$CONFIGURATION/$PRODUCT_NAME"

# Terminate any running instance first. macOS `open` only reactivates an
# already-running app instead of launching the freshly built binary, so without
# this a rebuild appears to have no effect.
pkill -f "$APP_DIR/Contents/MacOS/$PRODUCT_NAME" 2>/dev/null || true

"$REPO_ROOT/scripts/patch-mlx-swift-lm.sh"
swift build --disable-sandbox -c "$CONFIGURATION"

# SwiftPM cannot compile Metal shaders, so build the MLX metallib separately.
CONFIGURATION="$CONFIGURATION" "$REPO_ROOT/scripts/build-metallib.sh"

FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
# Start from a clean bundle so stale binaries/metallibs never linger.
rm -rf "$MACOS_DIR" "$FRAMEWORKS_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"
# MLX also searches `<executable dir>/Resources/mlx.metallib`. Keeping the
# metallib out of Contents/MacOS leaves only the main executable there, which
# keeps code signing of the bundle valid (a second Mach-O beside the executable
# breaks the seal).
mkdir -p "$MACOS_DIR/Resources"
cp "$(dirname "$EXECUTABLE_PATH")/mlx.metallib" "$MACOS_DIR/Resources/mlx.metallib"
cp "$REPO_ROOT/packaging/macos/Info.plist" "$CONTENTS_DIR/Info.plist"

# Embed Sparkle.framework (for in-app updates) and let the executable find it.
SPARKLE_FRAMEWORK="$REPO_ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  rm -rf "$FRAMEWORKS_DIR/Sparkle.framework"
  cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
  if ! otool -l "$MACOS_DIR/$PRODUCT_NAME" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$PRODUCT_NAME"
  fi
fi

if command -v codesign >/dev/null 2>&1; then
  # Ad-hoc sign the whole bundle (incl. the embedded Sparkle framework) after the
  # rpath edit. --deep is acceptable here because there are no entitlements or
  # hardened runtime to apply; it just seals every nested item consistently.
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "$APP_DIR"
