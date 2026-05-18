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

require brew
require lipo
require install_name_tool

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

fetch_bottles() {
  tag="$1"
  brew fetch --force --bottle-tag="$tag" mozjpeg gifsicle jpegoptim optipng libpng jpeg-turbo
}

extract_bottles() {
  tag="$1"
  dest="$2"
  mkdir -p "$dest"

  for formula in mozjpeg gifsicle jpegoptim optipng libpng jpeg-turbo; do
    bottle="$(brew --cache --bottle-tag="$tag" "$formula")"
    tar -xzf "$bottle" -C "$dest"
  done
}

copy_arch_tools() {
  src="$1"
  dest="$2"

  cp "$(find "$src/mozjpeg" -path "*/bin/cjpeg" -type f | head -n 1)" "$dest/cjpeg"
  cp "$(find "$src/mozjpeg" -path "*/bin/jpegtran" -type f | head -n 1)" "$dest/jpegtran"
  cp "$(find "$src/jpegoptim" -path "*/bin/jpegoptim" -type f | head -n 1)" "$dest/jpegoptim"
  cp "$(find "$src/gifsicle" -path "*/bin/gifsicle" -type f | head -n 1)" "$dest/gifsicle"
  cp "$(find "$src/optipng" -path "*/bin/optipng" -type f | head -n 1)" "$dest/optipng"
  cp "$(find "$src/mozjpeg" -path "*/lib/libjpeg.62.dylib" -type f | head -n 1)" "$dest/libjpeg.62.dylib"
  cp "$(find "$src/jpeg-turbo" -path "*/lib/libjpeg.8.dylib" -type f | head -n 1)" "$dest/libjpeg.8.dylib"
  cp "$(find "$src/libpng" -path "*/lib/libpng16.16.dylib" -type f | head -n 1)" "$dest/libpng16.16.dylib"
  chmod 755 "$dest"/*
}

make_universal() {
  name="$1"
  lipo -create \
    "$TOOLS_DIR/macos-arm64/$name" \
    "$TOOLS_DIR/macos-x86_64/$name" \
    -output "$TOOLS_DIR/macos-universal/$name"
  chmod 755 "$TOOLS_DIR/macos-universal/$name"
}

fetch_bottles arm64_sequoia
fetch_bottles sonoma

extract_bottles arm64_sequoia "$TMP_DIR/arm64"
extract_bottles sonoma "$TMP_DIR/x86_64"

copy_arch_tools "$TMP_DIR/arm64" "$TOOLS_DIR/macos-arm64"
copy_arch_tools "$TMP_DIR/x86_64" "$TOOLS_DIR/macos-x86_64"

for name in cjpeg jpegtran jpegoptim gifsicle optipng libjpeg.62.dylib libjpeg.8.dylib libpng16.16.dylib; do
  make_universal "$name"
done

install_name_tool -id @loader_path/libjpeg.62.dylib "$TOOLS_DIR/macos-universal/libjpeg.62.dylib"
install_name_tool -id @loader_path/libjpeg.8.dylib "$TOOLS_DIR/macos-universal/libjpeg.8.dylib"
install_name_tool -id @loader_path/libpng16.16.dylib "$TOOLS_DIR/macos-universal/libpng16.16.dylib"

install_name_tool -change @rpath/libjpeg.62.dylib @loader_path/libjpeg.62.dylib "$TOOLS_DIR/macos-universal/cjpeg"
install_name_tool -change "@@HOMEBREW_PREFIX@@/opt/libpng/lib/libpng16.16.dylib" @loader_path/libpng16.16.dylib "$TOOLS_DIR/macos-universal/cjpeg"
install_name_tool -change @rpath/libjpeg.62.dylib @loader_path/libjpeg.62.dylib "$TOOLS_DIR/macos-universal/jpegtran"
install_name_tool -change "@@HOMEBREW_PREFIX@@/opt/jpeg-turbo/lib/libjpeg.8.dylib" @loader_path/libjpeg.8.dylib "$TOOLS_DIR/macos-universal/jpegoptim"
install_name_tool -change "@@HOMEBREW_PREFIX@@/opt/libpng/lib/libpng16.16.dylib" @loader_path/libpng16.16.dylib "$TOOLS_DIR/macos-universal/optipng"

echo "Fetched optimizer helpers into $TOOLS_DIR"
