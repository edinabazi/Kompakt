#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/Vendor/Tools/macos-universal"

required_tools="
oxipng
optipng
jpegtran
jpegoptim
cjpeg
cwebp
gifsicle
svgo
ffmpeg
libjpeg.62.dylib
libjpeg.8.dylib
libpng16.16.dylib
"

if [ ! -d "$TOOLS_DIR" ]; then
  echo "Missing tools directory: $TOOLS_DIR" >&2
  exit 1
fi

for tool in $required_tools; do
  path="$TOOLS_DIR/$tool"
  if [ ! -f "$path" ]; then
    echo "Missing required bundled tool: $tool" >&2
    exit 1
  fi

  if [ ! -x "$path" ]; then
    echo "Bundled tool is not executable: $tool" >&2
    exit 1
  fi

  if file "$path" | grep -q "Mach-O"; then
    if ! lipo -info "$path" | grep -q "x86_64" || ! lipo -info "$path" | grep -q "arm64"; then
      echo "Bundled tool is not universal arm64/x86_64: $tool" >&2
      lipo -info "$path" >&2
      exit 1
    fi

    if otool -L "$path" 2>/dev/null | grep -E "/opt/homebrew|/usr/local|@@HOMEBREW_PREFIX@@" >/dev/null; then
      echo "Bundled tool has non-relocated Homebrew library references: $tool" >&2
      otool -L "$path" >&2
      exit 1
    fi
  fi
done

echo "Bundled optimizer tools verified."
