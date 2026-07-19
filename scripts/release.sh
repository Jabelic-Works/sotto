#!/usr/bin/env bash
set -euo pipefail

# Cuts a Sotto release and publishes it for Sparkle in-app updates.
#
#   scripts/release.sh 0.2.0
#
# It bumps the version, builds the release .app, packages the distributable
# archives, regenerates the EdDSA-signed appcast.xml, then commits, tags,
# pushes, and creates the GitHub release with the assets.
#
# Requirements: run on a clean `main`, `gh` authenticated, and the Sparkle
# signing key in the login Keychain (created once via Sparkle's generate_keys).
# The first run prompts for Keychain access to the signing key — choose
# "Always Allow".

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
ARCH="$(uname -m)"
ZIP_PATH="$DIST_DIR/Sotto-$VERSION-$ARCH.zip"
DMG_PATH="$DIST_DIR/Sotto-$VERSION-$ARCH.dmg"

# --- Preconditions -----------------------------------------------------------
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Must be on main." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is dirty. Commit or stash first." >&2; exit 1; }
command -v gh >/dev/null || { echo "gh CLI is required." >&2; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "Tag $TAG already exists." >&2; exit 1; }
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || { echo "Sparkle tools missing. Run 'swift package resolve'." >&2; exit 1; }

# Roll back the version bump if we fail before committing; give recovery steps
# if we fail after the tag/push are already published.
COMMITTED=0
STAGE=""
on_error() {
  [[ -n "$STAGE" ]] && rm -rf "$STAGE"
  if [[ "$COMMITTED" == 0 ]]; then
    git checkout -- "$INFO_PLIST" 2>/dev/null || true
    echo "Release aborted before committing; reverted the version bump." >&2
  else
    echo "" >&2
    echo "Release partially completed: the commit and tag $TAG are pushed but the" >&2
    echo "GitHub release may be missing. Finish it manually with:" >&2
    echo "  gh release create $TAG '$ZIP_PATH' '$DMG_PATH' --title 'Sotto $VERSION'" >&2
  fi
}
trap on_error ERR

echo "==> Releasing $TAG"

# --- 1. Bump version (build number = monotonically increasing) ---------------
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
NEXT_BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$INFO_PLIST"
echo "==> Version $VERSION (build $NEXT_BUILD)"

# --- 2. Build the release .app and package the archives ----------------------
CONFIGURATION=release "$REPO_ROOT/scripts/build-app.sh" >/dev/null
"$REPO_ROOT/scripts/package-app.sh" >/dev/null   # dist/Sotto-<ver>-<arch>.{zip,dmg}

# --- 3. Regenerate the signed appcast (single latest entry) ------------------
# generate_appcast lists every archive in the folder, so stage only this one.
STAGE="$(mktemp -d)"
cp "$ZIP_PATH" "$STAGE/"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$REPO_SLUG/releases/download/$TAG/" \
  "$STAGE"
cp "$STAGE/appcast.xml" "$APPCAST"
rm -rf "$STAGE"; STAGE=""

# --- 4. Commit, tag, push -----------------------------------------------------
git add "$INFO_PLIST" "$APPCAST"
git commit -q -m "Release $TAG"
git tag "$TAG"
COMMITTED=1
git push origin main
git push origin "$TAG"

# --- 5. GitHub release with the update zip + dmg -----------------------------
gh release create "$TAG" \
  "$ZIP_PATH" \
  "$DMG_PATH" \
  --title "Sotto $VERSION" \
  --notes "See README for install and update instructions. In-app: Check for Updates… in the menu bar."

trap - ERR
echo "==> Done: https://github.com/$REPO_SLUG/releases/tag/$TAG"
