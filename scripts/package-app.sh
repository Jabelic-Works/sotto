#!/usr/bin/env bash
set -euo pipefail

# Packages the built Sotto.app into distributable archives under dist/:
# a .zip (via ditto, preserving bundle metadata) and a drag-to-Applications .dmg.
#
# Build the app first, e.g.:
#   CONFIGURATION=release scripts/build-app.sh
#
# The app is ad-hoc signed only, so recipients must clear the Gatekeeper
# quarantine (right-click > Open, or `xattr -dr com.apple.quarantine Sotto.app`).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/.build/Sotto.app"
DIST_DIR="$REPO_ROOT/dist"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Sotto.app not found. Build it first: CONFIGURATION=release scripts/build-app.sh" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist")"
ARCH="$(uname -m)"
NAME="Sotto-$VERSION-$ARCH"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$NAME.zip" "$DIST_DIR/$NAME.dmg"

# Zip — ditto keeps the .app bundle intact (symlinks, permissions, xattrs).
ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/$NAME.zip"

# DMG — stage the app next to an /Applications symlink for drag-to-install.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_DIR" "$STAGING/Sotto.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Sotto" -srcfolder "$STAGING" -ov -format UDZO "$DIST_DIR/$NAME.dmg" >/dev/null

echo "$DIST_DIR/$NAME.zip"
echo "$DIST_DIR/$NAME.dmg"
