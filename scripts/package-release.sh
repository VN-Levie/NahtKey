#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$task_root/dist/NahtKey.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
architecture="$(lipo -archs "$bundle/Contents/MacOS/NahtKey")"
if [ "$architecture" != "arm64" ]; then
    printf '%s\n' "Expected the Apple Silicon release, got: $architecture" >&2
    exit 2
fi
codesign --verify --strict "$bundle"
archive="NahtKey-${version}-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$bundle" "$task_root/dist/$archive"
cd "$task_root/dist"
shasum -a 256 "$archive" > "$archive.sha256"
printf '%s\n' "$task_root/dist/$archive" "$task_root/dist/$archive.sha256"
