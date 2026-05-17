# Third-Party Notices

Kompakt bundles command-line optimizer tools so users do not need to install anything separately.

This file is a maintainer checklist, not legal advice. Confirm licenses and redistribution requirements before publishing a release.

## Bundled Runtime Tools

- `oxipng` - PNG optimizer. Check upstream license and release notes before updating.
- `optipng` - PNG optimizer. Check upstream license and release notes before updating.
- `jpegtran` and `cjpeg` - JPEG tools from mozjpeg/libjpeg-compatible distributions. Check upstream license and notices before updating.
- `jpegoptim` - JPEG optimizer. Check upstream license and notices before updating.
- `cwebp` - WebP encoder from Google's WebP tools. Check upstream license and notices before updating.
- `gifsicle` - GIF optimizer. Check upstream license and notices before updating.
- `ffmpeg` - video/audio processing. FFmpeg builds can include components under different licenses; follow the upstream legal guidance for the exact build that is redistributed.
- `libjpeg.62.dylib`, `libjpeg.8.dylib`, `libpng16.16.dylib` - runtime libraries required by bundled helpers.

## Maintainer Requirements

- Record the exact upstream version and source URL for every bundled binary.
- Keep checksums for release artifacts.
- Ensure non-system dynamic libraries are bundled and loaded with `@loader_path`.
- Include required license texts in release artifacts.
