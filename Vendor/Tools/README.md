# Bundled Optimizer Tools

Kompakt never asks end users to install command-line dependencies.

Release builds generate signed/notarization-safe optimizer executables and required dylibs here:

```text
Vendor/Tools/macos-universal/
Vendor/Tools/macos-arm64/
Vendor/Tools/macos-x86_64/
```

During the Xcode build, files from `macos-universal` are copied and signed into:

```text
Kompakt.app/Contents/Helpers/
```

The architecture-specific folders are generated as source slices for rebuilding universal helpers. The app only looks in `Contents/Helpers`; it does not fall back to Homebrew, MacPorts, or system paths.

Bundled helper names:

- `oxipng`
- `optipng`
- `jpegtran`
- `jpegoptim`
- `cjpeg`
- `cwebp`
- `gifsicle`
- `svgo`
- `ffmpeg`
- `libjpeg.62.dylib`
- `libjpeg.8.dylib`
- `libpng16.16.dylib`

`fetch-oxipng.sh` refreshes the Rust-distributed `oxipng` release. `fetch-webp-tools.sh` refreshes Google's statically linked `cwebp` release from the official WebP archives. `fetch-svgo-tool.sh` builds a standalone `svgo` helper from the pinned npm package. `fetch-ffmpeg-tools.sh` refreshes the static macOS `ffmpeg` helper. `fetch-optimizer-tools.sh` fetches the remaining image helpers from Homebrew bottles for direct distribution builds. Homebrew, npm, and Bun are only maintainer-side fetch/build mechanisms; the built app does not call or require them.

Do not commit generated helper binaries. Run these before verifying, building, or archiving a release:

```sh
Scripts/fetch-oxipng.sh
Scripts/fetch-webp-tools.sh
Scripts/fetch-svgo-tool.sh
Scripts/fetch-optimizer-tools.sh
Scripts/fetch-ffmpeg-tools.sh
```

The app intentionally does not use system installs or native fallbacks for supported formats.

Run `Scripts/verify-bundled-tools.sh` before shipping a release.
