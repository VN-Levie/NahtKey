#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$task_root/.build/InputProbe.app"
if pgrep -x InputProbe >/dev/null; then
    printf '%s\n' 'Close the Input Probe window before rebuilding it.' >&2
    exit 2
fi
mkdir -p "$bundle/Contents/MacOS"
swiftc "$task_root/scripts/input-probe.swift" -o "$bundle/Contents/MacOS/InputProbe"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>vn.nahtkey.input-probe</string>
<key>CFBundleExecutable</key><string>InputProbe</string>
<key>CFBundleName</key><string>NahtKey Input Probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
printf '%s\n' "$bundle"
