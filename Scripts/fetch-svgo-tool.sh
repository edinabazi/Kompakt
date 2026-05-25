#!/bin/sh
set -eu

VERSION="4.0.1"
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

require npm
require bun
require lipo

mkdir -p "$TOOLS_DIR/macos-arm64" "$TOOLS_DIR/macos-x86_64" "$TOOLS_DIR/macos-universal"

cd "$TMP_DIR"
npm init -y >/dev/null
npm install "svgo@$VERSION" >/dev/null

cat > kompakt-svgo.js <<'EOF'
import { readFileSync, writeFileSync } from 'node:fs';
import svgo from './node_modules/svgo/dist/svgo-node.cjs';

const { optimize } = svgo;
const args = process.argv.slice(2);
let multipass = false;
let input;
let output;

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];

  if (arg === '--multipass') {
    multipass = true;
  } else if (arg === '-i' || arg === '--input') {
    input = args[index + 1];
    index += 1;
  } else if (arg === '-o' || arg === '--output') {
    output = args[index + 1];
    index += 1;
  } else if (!input) {
    input = arg;
  }
}

if (!input || !output) {
  console.error('Usage: svgo [--multipass] -i input.svg -o output.svg');
  process.exit(2);
}

try {
  const result = optimize(readFileSync(input, 'utf8'), { path: input, multipass });
  writeFileSync(output, result.data);
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
EOF

bun build --compile --target=bun-darwin-arm64 kompakt-svgo.js --outfile "$TOOLS_DIR/macos-arm64/svgo"
bun build --compile --target=bun-darwin-x64 kompakt-svgo.js --outfile "$TOOLS_DIR/macos-x86_64/svgo"

lipo -create \
  "$TOOLS_DIR/macos-arm64/svgo" \
  "$TOOLS_DIR/macos-x86_64/svgo" \
  -output "$TOOLS_DIR/macos-universal/svgo"

chmod 755 "$TOOLS_DIR/macos-arm64/svgo" "$TOOLS_DIR/macos-x86_64/svgo" "$TOOLS_DIR/macos-universal/svgo"

echo "Fetched SVGO $VERSION into $TOOLS_DIR"
