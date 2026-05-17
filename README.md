# Kompakt

Kompakt is a small macOS menu bar app for compressing images and videos by dropping files or folders onto the app.

The app is designed to be self-contained. End users should only install Kompakt; runtime optimizer tools are bundled into `Kompakt.app/Contents/Helpers` during the Xcode build.

## Requirements

- macOS 14 or newer
- Xcode 17 or newer

## Build

Open `Kompakt.xcodeproj` in Xcode and run the shared `Kompakt` scheme.

From the command line:

```sh
xcodebuild test -scheme Kompakt -project Kompakt.xcodeproj -destination 'platform=macOS'
```

The build intentionally fails if a required bundled optimizer is missing. While preparing a missing helper locally, maintainers can compile the Swift app with:

```sh
xcodebuild test -scheme Kompakt -project Kompakt.xcodeproj -destination 'platform=macOS'
```

## Bundled Optimizers

Runtime helpers live in `Vendor/Tools/macos-universal` and are copied into the app bundle by `Scripts/bundle-optimizer-tools.sh`.
The shared Xcode project does not commit an Apple Developer Team ID. Set a local team in Xcode or pass signing settings on the command line when producing signed release builds.

Kompakt does not call Homebrew, MacPorts, or system-installed optimizer tools at runtime. Maintainer fetch scripts may use local tools to refresh vendored binaries, but the app itself must remain self-contained.

See `Vendor/Tools/README.md` and `THIRD_PARTY_NOTICES.md` before updating binaries.

## Contributing

Keep changes small, explicit, and easy to review. See `CONTRIBUTING.md`.
