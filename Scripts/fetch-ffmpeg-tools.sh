#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/Vendor/Tools"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require curl
require lipo
require unzip

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

fetch_arch() {
  arch="$1"
  url="$2"
  out_dir="$TOOLS_DIR/$arch"
  zip="$TMP_DIR/$arch.zip"
  extract_dir="$TMP_DIR/$arch"

  curl --retry 5 --retry-delay 2 -fL "$url" -o "$zip"
  mkdir -p "$extract_dir" "$out_dir"
  unzip -q "$zip" -d "$extract_dir"

  found="$(find "$extract_dir" -type f -name ffmpeg -perm -111 | head -n 1)"
  if [ -z "$found" ]; then
    echo "Could not find ffmpeg in $url" >&2
    exit 1
  fi

  cp "$found" "$out_dir/ffmpeg"
  chmod 755 "$out_dir/ffmpeg"
}

fetch_arch macos-arm64 https://www.osxexperts.net/ffmpeg81arm.zip
fetch_arch macos-x86_64 https://www.osxexperts.net/ffmpeg80intel.zip

lipo -create \
  "$TOOLS_DIR/macos-arm64/ffmpeg" \
  "$TOOLS_DIR/macos-x86_64/ffmpeg" \
  -output "$TOOLS_DIR/macos-universal/ffmpeg"
chmod 755 "$TOOLS_DIR/macos-universal/ffmpeg"

echo "Fetched ffmpeg into $TOOLS_DIR"
