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
# Refuse an unstripped build without printing any developer-specific paths.
if LC_ALL=C grep -a -E '/Users/|/home/|/private/var/folders/|/var/folders/' "$bundle/Contents/MacOS/NahtKey" >/dev/null; then
    printf '%s\n' 'The executable contains local build paths. Rebuild with scripts/build-app.sh before packaging.' >&2
    exit 2
fi
archive="NahtKey-${version}-macos-arm64.zip"
# Bundle resources and its signature are normal files; omit filesystem metadata.
ditto -c -k --norsrc --noqtn --keepParent "$bundle" "$task_root/dist/$archive"
cd "$task_root/dist"
shasum -a 256 "$archive" > "$archive.sha256"
printf '%s\n' "$task_root/dist/$archive" "$task_root/dist/$archive.sha256"
