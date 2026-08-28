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
require jq
require lipo
require install_name_tool
require shasum

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

fetch_bottles() {
  tag="$1"
  dest="$TMP_DIR/bottles/$tag"
  mkdir -p "$dest"

  for formula in mozjpeg gifsicle jpegoptim optipng libpng jpeg-turbo; do
    metadata="$(curl --fail --silent --show-error --location "https://formulae.brew.sh/api/formula/$formula.json")"
    url="$(printf '%s' "$metadata" | jq -er --arg tag "$tag" '.bottle.stable.files[$tag].url')"
    sha256="$(printf '%s' "$metadata" | jq -er --arg tag "$tag" '.bottle.stable.files[$tag].sha256')"
    token="$(curl --fail --silent --show-error --location \
      "https://ghcr.io/token?scope=repository:homebrew/core/$formula:pull&service=ghcr.io" | jq -er '.token')"
    bottle="$dest/$formula.tar.gz"

    curl --fail --silent --show-error --location \
      --header "Authorization: Bearer $token" \
      "$url" \
      --output "$bottle"
    printf '%s  %s\n' "$sha256" "$bottle" | shasum -a 256 -c -
  done
}

extract_bottles() {
  tag="$1"
  dest="$2"
  mkdir -p "$dest"

  for formula in mozjpeg gifsicle jpegoptim optipng libpng jpeg-turbo; do
    bottle="$TMP_DIR/bottles/$tag/$formula.tar.gz"
    tar -xzf "$bottle" -C "$dest"
  done
}

copy_arch_tools() {
  src="$1"
  dest="$2"

  copy_first "$src/mozjpeg" "*/bin/cjpeg" "$dest/cjpeg"
  copy_first "$src/mozjpeg" "*/bin/jpegtran" "$dest/jpegtran"
  copy_first "$src/jpegoptim" "*/bin/jpegoptim" "$dest/jpegoptim"
  copy_first "$src/gifsicle" "*/bin/gifsicle" "$dest/gifsicle"
  copy_first "$src/optipng" "*/bin/optipng" "$dest/optipng"
  copy_first "$src/mozjpeg" "*/lib/libjpeg.62.dylib" "$dest/libjpeg.62.dylib"
  copy_first "$src/jpeg-turbo" "*/lib/libjpeg.8.dylib" "$dest/libjpeg.8.dylib"
  copy_first "$src/libpng" "*/lib/libpng16.16.dylib" "$dest/libpng16.16.dylib"
  chmod 755 "$dest"/*
}

copy_first() {
  search_root="$1"
  pattern="$2"
  output="$3"
  found="$(find "$search_root" -path "$pattern" | head -n 1)"

  if [ -z "$found" ]; then
    echo "Missing expected bottle file matching $pattern in $search_root" >&2
    exit 1
  fi

  rm -rf "$output"
  cp "$found" "$output"
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
