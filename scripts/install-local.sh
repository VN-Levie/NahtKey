#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$task_root/dist/NahtKey.app"
destination="/Applications/NahtKey.app"
if pgrep -x NahtKey >/dev/null; then
    printf '%s\n' 'Choose “Thoát hoàn toàn NahtKey” before installing (Cmd+Q only hides it).' >&2
    exit 2
fi
codesign --verify --strict "$bundle"
ditto "$bundle" "$destination"
touch "$destination"
codesign --verify --strict "$destination"
# Refresh only this app, never delete global caches or restart Finder/Dock.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
mdimport -i "$destination"
printf '%s\n' "$destination"
