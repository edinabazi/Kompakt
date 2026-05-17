# Contributing

Thanks for helping improve Kompakt.

## Development

- Use Xcode 17 or newer.
- Keep runtime behavior self-contained. Do not add a dependency on user-installed command-line tools.
- Prefer small Swift types with explicit names over broad utility objects.
- Keep UI code, file detection, process execution, and compression rules separated.
- Add or update tests for behavior changes.

Run before opening a pull request:

```sh
xcodebuild test -scheme Kompakt -project Kompakt.xcodeproj -destination 'platform=macOS'
```

App builds require every bundled helper listed in `Scripts/bundle-optimizer-tools.sh`. Do not bypass missing helpers in PRs; refresh the bundled helper set first.

The shared project intentionally does not include an Apple Developer Team ID. Use local Xcode signing settings or command-line overrides for signed release builds.

## Bundled Tools

Any optimizer used at runtime must be committed under `Vendor/Tools/macos-universal` and copied into `Kompakt.app/Contents/Helpers`.

When changing bundled tools:

- Update `Vendor/Tools/README.md`.
- Update `THIRD_PARTY_NOTICES.md`.
- Verify architectures with `file` or `lipo -info`.
- Verify linked libraries with `otool -L`.
- Keep non-system dylib references relative to `@loader_path`.

## Code Style

- Keep APIs small and behavior explicit.
- Avoid clever abstractions.
- Avoid force unwraps and unchecked assumptions in app code.
- Prefer tests around file handling, process command construction, and user-visible behavior.
