# Release

## Sparkle Updates

Kompakt uses Sparkle 2 for in-app updates. The appcast is published to:

```text
https://edinabazi.github.io/Kompakt/appcast.xml
```

Generate Sparkle keys from the Sparkle tools bundled by Swift Package Manager:

```sh
xcodebuild -resolvePackageDependencies -project Kompakt.xcodeproj -scheme Kompakt
SPARKLE_BIN="$(find ~/Library/Developer/Xcode/DerivedData -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys' -type f | head -n 1)"
"$SPARKLE_BIN"
"$SPARKLE_BIN" -x sparkle-private-key.txt
```

Add the printed public key as:

```text
SPARKLE_PUBLIC_ED_KEY
```

Add the contents of `sparkle-private-key.txt` as:

```text
SPARKLE_PRIVATE_ED_KEY
```

The release workflow compiles the public key into `Info.plist`, signs update archives with the private key, and pushes `appcast.xml` plus versioned update zips to the `gh-pages` branch.
