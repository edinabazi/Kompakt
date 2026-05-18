#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/Kompakt.app /path/to/Kompakt.dmg" >&2
  exit 64
fi

APP_PATH="$1"
DMG_PATH="$2"
APP_NAME="$(basename "$APP_PATH" .app)"
VOLUME_NAME="$APP_NAME"
BUILD_DIR="$(cd "$(dirname "$DMG_PATH")" && pwd)"
DMG_PATH="$BUILD_DIR/$(basename "$DMG_PATH")"
STAGING_DIR="$BUILD_DIR/dmg-staging"
MOUNT_DIR="$BUILD_DIR/dmg-mount"
RW_DMG="$BUILD_DIR/$APP_NAME-rw.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found: $APP_PATH" >&2
  exit 66
fi

rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$RW_DMG" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$BUILD_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG"

mkdir -p "$MOUNT_DIR"
DEVICE="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" | awk '/Apple_HFS/ { print $1; exit }')"
if [[ -z "$DEVICE" ]]; then
  echo "error: failed to attach writable DMG" >&2
  exit 1
fi

cleanup() {
  hdiutil detach "$DEVICE" >/dev/null 2>&1 || true
  rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$RW_DMG"
}
trap cleanup EXIT

LAYOUT_LOG="$BUILD_DIR/dmg-layout.log"
osascript <<APPLESCRIPT >"$LAYOUT_LOG" 2>&1 &
set volumeFolder to POSIX file "$MOUNT_DIR" as alias

tell application "Finder"
  open volumeFolder
  delay 1
  set diskWindow to container window of volumeFolder
  set current view of diskWindow to icon view
  try
    set toolbar visible of diskWindow to false
  end try
  try
    set statusbar visible of diskWindow to false
  end try
  set the bounds of diskWindow to {100, 100, 640, 660}
  set viewOptions to the icon view options of diskWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set position of item "$APP_NAME.app" of volumeFolder to {140, 210}
  set position of item "Applications" of volumeFolder to {400, 210}
  update volumeFolder without registering applications
  delay 1
end tell
APPLESCRIPT
LAYOUT_PID="$!"

for _ in {1..30}; do
  if ! kill -0 "$LAYOUT_PID" >/dev/null 2>&1; then
    if ! wait "$LAYOUT_PID"; then
      cat "$LAYOUT_LOG" >&2
      echo "error: failed to set DMG Finder layout" >&2
      exit 1
    fi
    LAYOUT_PID=""
    break
  fi
  sleep 1
done

if [[ -n "${LAYOUT_PID:-}" ]]; then
  kill "$LAYOUT_PID" >/dev/null 2>&1 || true
  cat "$LAYOUT_LOG" >&2
  echo "error: timed out while setting DMG Finder layout" >&2
  exit 1
fi

rm -f "$LAYOUT_LOG"

sync
hdiutil detach "$DEVICE"
trap - EXIT

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$RW_DMG"
