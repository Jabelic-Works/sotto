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

"$REPO_ROOT/scripts/patch-mlx-swift-lm.sh"
swift build --disable-sandbox -c "$CONFIGURATION"

# SwiftPM cannot compile Metal shaders, so build the MLX metallib separately.
CONFIGURATION="$CONFIGURATION" "$REPO_ROOT/scripts/build-metallib.sh"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"
# MLX loads `mlx.metallib` colocated with the executable (Contents/MacOS).
cp "$(dirname "$EXECUTABLE_PATH")/mlx.metallib" "$MACOS_DIR/mlx.metallib"
cp "$REPO_ROOT/packaging/macos/Info.plist" "$CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
