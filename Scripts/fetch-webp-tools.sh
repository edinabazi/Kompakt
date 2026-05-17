#!/bin/sh
set -eu

VERSION="1.6.0"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/Vendor/Tools"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fetch_arch() {
  arch="$1"
  asset_arch="$2"
  url="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$VERSION-mac-$asset_arch.tar.gz"
  out_dir="$TOOLS_DIR/macos-$arch"

  mkdir -p "$out_dir"
  curl -fsSL "$url" | tar -xz -C "$TMP_DIR"
  cp "$TMP_DIR/libwebp-$VERSION-mac-$asset_arch/bin/cwebp" "$out_dir/cwebp"
  chmod 755 "$out_dir/cwebp"
}

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

fetch_arch "arm64" "arm64"
fetch_arch "x86_64" "x86-64"

lipo -create \
  "$TOOLS_DIR/macos-arm64/cwebp" \
  "$TOOLS_DIR/macos-x86_64/cwebp" \
  -output "$TOOLS_DIR/macos-universal/cwebp"
chmod 755 "$TOOLS_DIR/macos-universal/cwebp"

echo "Fetched libwebp $VERSION cwebp into $TOOLS_DIR"
