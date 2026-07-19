#!/usr/bin/env bash
set -euo pipefail

# Cuts a Sotto release and publishes it for Sparkle in-app updates.
#
#   scripts/release.sh 0.2.0
#
# It bumps the version, builds the release .app, packages a Sparkle update zip
# (+ a .dmg for manual install), regenerates the EdDSA-signed appcast.xml, then
# commits, tags, pushes, and creates the GitHub release with the assets.
#
# Requirements: run on a clean `main`, `gh` authenticated, and the Sparkle
# signing key in the login Keychain (from scripts/build-metallib is unrelated;
# the key comes from Sparkle's generate_keys, run once). The first run prompts
# for Keychain access to the signing key — choose "Always Allow".

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: scripts/release.sh <version>   e.g. scripts/release.sh 0.2.0" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

INFO_PLIST="$REPO_ROOT/packaging/macos/Info.plist"
APPCAST="$REPO_ROOT/appcast.xml"
DIST_DIR="$REPO_ROOT/dist"
SPARKLE_BIN="$REPO_ROOT/.build/artifacts/sparkle/Sparkle/bin"
REPO_SLUG="Jabelic-Works/sotto"
TAG="v$VERSION"

# --- Preconditions -----------------------------------------------------------
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Must be on main." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is dirty. Commit or stash first." >&2; exit 1; }
command -v gh >/dev/null || { echo "gh CLI is required." >&2; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "Tag $TAG already exists." >&2; exit 1; }
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || { echo "Sparkle tools missing. Run 'swift package resolve'." >&2; exit 1; }

echo "==> Releasing $TAG"

# --- 1. Bump version (build number = monotonically increasing) ---------------
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
NEXT_BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$INFO_PLIST"
echo "==> Version $VERSION (build $NEXT_BUILD)"

# --- 2. Build the release .app ------------------------------------------------
CONFIGURATION=release "$REPO_ROOT/scripts/build-app.sh" >/dev/null
APP_DIR="$REPO_ROOT/.build/Sotto.app"

# --- 3. Package the update zip (Sparkle) and a dmg (manual install) ----------
mkdir -p "$DIST_DIR"
ARCH="$(uname -m)"
ZIP_NAME="Sotto-$VERSION.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto -c -k --keepParent "$APP_DIR" "$STAGE/$ZIP_NAME"
cp "$STAGE/$ZIP_NAME" "$DIST_DIR/$ZIP_NAME"
"$REPO_ROOT/scripts/package-app.sh" >/dev/null   # produces dist/Sotto-<ver>-<arch>.dmg
DMG_PATH="$DIST_DIR/Sotto-$VERSION-$ARCH.dmg"

# --- 4. Regenerate the signed appcast (single latest entry) ------------------
# Only the new zip is in $STAGE, so the appcast holds just this version, with
# the enclosure URL pointing at this release's GitHub asset.
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$REPO_SLUG/releases/download/$TAG/" \
  "$STAGE"
cp "$STAGE/appcast.xml" "$APPCAST"

# --- 5. Commit, tag, push -----------------------------------------------------
git add "$INFO_PLIST" "$APPCAST"
git commit -q -m "Release $TAG"
git tag "$TAG"
git push origin main
git push origin "$TAG"

# --- 6. GitHub release with the update zip + dmg -----------------------------
gh release create "$TAG" \
  "$DIST_DIR/$ZIP_NAME" \
  "$DMG_PATH" \
  --title "Sotto $VERSION" \
  --notes "See README for install and update instructions. In-app: Check for Updates… in the menu bar."

echo "==> Done: https://github.com/$REPO_SLUG/releases/tag/$TAG"
