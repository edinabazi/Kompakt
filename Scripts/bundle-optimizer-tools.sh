#!/bin/sh
set -eu

TOOLS_SRC="${PROJECT_DIR}/Vendor/Tools/macos-universal"
HELPERS_DIR="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Helpers"

required_tools="
oxipng
optipng
jpegtran
jpegoptim
cjpeg
cwebp
gifsicle
ffmpeg
libjpeg.62.dylib
libjpeg.8.dylib
libpng16.16.dylib
"

if [ ! -d "$TOOLS_SRC" ]; then
  echo "error: Missing bundled optimizer directory: $TOOLS_SRC" >&2
  exit 1
fi

for tool in $required_tools; do
  if [ ! -f "$TOOLS_SRC/$tool" ]; then
    echo "error: Missing bundled optimizer tool: Vendor/Tools/macos-universal/$tool" >&2
    exit 1
  fi
done

for file in "$TOOLS_SRC"/*; do
  [ -f "$file" ] || continue

  found=0
  filename="$(basename "$file")"
  for tool in $required_tools; do
    if [ "$filename" = "$tool" ]; then
      found=1
      break
    fi
  done

  if [ "$found" -ne 1 ]; then
    echo "error: Unexpected bundled optimizer file: Vendor/Tools/macos-universal/$filename" >&2
    exit 1
  fi
done

rm -rf "$HELPERS_DIR"
mkdir -p "$HELPERS_DIR"

echo "Bundling optimizer tools from $TOOLS_SRC"

for tool in $required_tools; do
  dest="$HELPERS_DIR/$tool"
  cp "$TOOLS_SRC/$tool" "$dest"
  chmod 755 "$dest"

  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    timestamp_args="--timestamp=none"
    if [ "${CONFIGURATION:-}" = "Release" ]; then
      timestamp_args="--timestamp"
    fi

    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --options runtime $timestamp_args "$dest"
  fi

  echo "Bundled $tool into $dest"
done
