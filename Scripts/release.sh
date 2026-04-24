#!/bin/bash
# Scripts/release.sh — Archive, notarize, staple, package DMG, and publish to GitHub.
#
# One-time credential setup (stores in your keychain, never needs repeating):
#   xcrun notarytool store-credentials "sfmaker-notary" \
#     --key ~/.private_keys/AuthKey_<KEY_ID>.p8 \
#     --key-id <KEY_ID> \
#     --issuer <ISSUER_ID>
#
# If you already have "eyeballs-notary" set up, you can reuse it by changing
# NOTARY_PROFILE below.
#
# Usage:
#   ./Scripts/release.sh
#
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
SCHEME="SFMaker"
PROJECT="SFMaker.xcodeproj"
EXPORT_OPTIONS="Scripts/ExportOptions.plist"
NOTARY_PROFILE="sfmaker-notary"   # keychain profile name from store-credentials
APP_NAME="SF Image Maker"

# ── Derived values ─────────────────────────────────────────────────────────────
ARCHIVE_PATH="build/${SCHEME}.xcarchive"
EXPORT_PATH="build/export"

mkdir -p build

# ── 1. Increment build number ──────────────────────────────────────────────────
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/MARKETING_VERSION/{print $3}')
xcrun agvtool next-version -all > /dev/null
BUILD=$(xcrun agvtool what-version -terse)
TAG="v${VERSION}.${BUILD}"
DMG_NAME="SFImageMaker-${VERSION}"
DMG_PATH="build/${DMG_NAME}.dmg"
echo "▶ ${APP_NAME} ${VERSION} (build ${BUILD}) → ${TAG}"

# ── 2. Archive ─────────────────────────────────────────────────────────────────
echo "▶ Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  | grep -E "^(error:|warning:|Build succeeded|Archive succeeded|/)" || true

# ── 3. Export (Developer ID signed) ───────────────────────────────────────────
echo "▶ Exporting..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

APP_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.app" | head -1)
if [ -z "$APP_PATH" ]; then
  echo "error: no .app found in ${EXPORT_PATH}" >&2
  exit 1
fi
echo "▶ Found app: ${APP_PATH}"

# ── 4. Create DMG with drag-to-Applications layout ────────────────────────────
echo "▶ Creating DMG..."

STAGING_DMG="build/staging.dmg"
APP_BUNDLE=$(basename "$APP_PATH")
MOUNT_DIR="/Volumes/SFMaker-staging"

[ -f "$STAGING_DMG" ] && rm -f "$STAGING_DMG"
if [ -d "$MOUNT_DIR" ]; then
  hdiutil detach "$MOUNT_DIR" -quiet -force 2>/dev/null || true
fi

APP_SIZE_MB=$(du -sm "$APP_PATH" | awk '{print $1}')
STAGING_SIZE=$((APP_SIZE_MB + 20))

hdiutil create \
  -megabytes "$STAGING_SIZE" \
  -volname "${APP_NAME} ${VERSION}" \
  -fs HFS+ \
  -ov \
  "$STAGING_DMG"

hdiutil attach "$STAGING_DMG" \
  -mountpoint "$MOUNT_DIR" \
  -noautoopen \
  -readwrite

cp -r "$APP_PATH" "$MOUNT_DIR/"

if [ -f "Assets/DMGBackground.png" ]; then
  mkdir -p "$MOUNT_DIR/.background"
  cp "Assets/DMGBackground.png" "$MOUNT_DIR/.background/DMGBackground.png"
  [ -f "Assets/DMGBackground@2x.png" ] && \
    cp "Assets/DMGBackground@2x.png" "$MOUNT_DIR/.background/DMGBackground@2x.png"
  BG_APPLESCRIPT='set background picture of viewOptions to file ".background:DMGBackground.png"'
else
  BG_APPLESCRIPT=""
fi

osascript <<APPLESCRIPT
tell application "Finder"
  set theDisk to disk "SFMaker-staging"
  make new alias file to folder "Applications" of startup disk at theDisk
  tell theDisk
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 540, 400}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    ${BG_APPLESCRIPT}
    set position of item "${APP_BUNDLE}" of container window to {130, 160}
    set position of item "Applications" of container window to {370, 160}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
sleep 1
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$STAGING_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -ov

rm -f "$STAGING_DMG"

# ── 5. Notarize DMG ────────────────────────────────────────────────────────────
echo "▶ Notarizing (this takes a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ── 6. Staple ─────────────────────────────────────────────────────────────────
echo "▶ Stapling..."
xcrun stapler staple "$DMG_PATH"

# ── 7. Verify ─────────────────────────────────────────────────────────────────
echo "▶ Verifying staple..."
xcrun stapler validate "$DMG_PATH"

# ── 8. Publish GitHub release ─────────────────────────────────────────────────
echo "▶ Publishing GitHub release ${TAG}..."
gh release create "$TAG" \
  "$DMG_PATH" \
  --title "${APP_NAME} ${TAG}" \
  --generate-notes

# ── 9. Commit and push incremented build number ───────────────────────────────
echo "▶ Committing build number ${BUILD}..."
git add "$PROJECT/project.pbxproj"
git commit -m "Release ${TAG} (build ${BUILD})"
git push

echo ""
echo "✅ Released: ${TAG}"
echo "   DMG: ${DMG_PATH}"
