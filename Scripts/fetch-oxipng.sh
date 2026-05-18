#!/bin/sh
set -eu

VERSION="10.1.1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/Vendor/Tools"

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

fetch_arch() {
  arch="$1"
  asset_arch="$2"
  url="https://github.com/oxipng/oxipng/releases/download/v$VERSION/oxipng-$VERSION-$asset_arch-apple-darwin.tar.gz"
  tmp_dir="$(mktemp -d)"
  out_dir="$TOOLS_DIR/macos-$arch"

  mkdir -p "$out_dir"
  curl -fsSL "$url" | tar -xz -C "$tmp_dir"
  found="$(find "$tmp_dir" -type f -name oxipng -perm -111 | head -n 1)"

  if [ -z "$found" ]; then
    echo "Could not find oxipng in downloaded archive for $arch" >&2
    exit 1
  fi

  cp "$found" "$out_dir/oxipng"
  chmod 755 "$out_dir/oxipng"
  rm -rf "$tmp_dir"
}

fetch_arch "arm64" "aarch64"
fetch_arch "x86_64" "x86_64"

lipo -create \
  "$TOOLS_DIR/macos-arm64/oxipng" \
  "$TOOLS_DIR/macos-x86_64/oxipng" \
  -output "$TOOLS_DIR/macos-universal/oxipng"
chmod 755 "$TOOLS_DIR/macos-universal/oxipng"

echo "Fetched oxipng $VERSION into $TOOLS_DIR"
echo "Run Scripts/fetch-optimizer-tools.sh to refresh JPEG/GIF/OptiPNG helpers."
