#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
bundle="$task_root/dist/NahtKey.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/NahtKey" "$bundle/Contents/MacOS/NahtKey"
cp "$task_root/assets/NahtKeyIcon.png" "$bundle/Contents/Resources/NahtKeyIcon.png"
cp "$task_root/assets/NahtKeyMenuBar.png" "$bundle/Contents/Resources/NahtKeyMenuBar.png"
iconset="$task_root/.build/NahtKey.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$task_root/assets/NahtKeyIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$task_root/assets/NahtKeyIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/NahtKey.icns"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>NahtKey</string>
<key>CFBundleDisplayName</key><string>NahtKey</string>
<key>CFBundleIdentifier</key><string>vn.nahtkey.mac</string>
<key>CFBundleExecutable</key><string>NahtKey</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.4</string>
<key>CFBundleVersion</key><string>7</string>
<key>CFBundleIconFile</key><string>NahtKey</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>NahtKey contributors</string>
</dict></plist>
PLIST
signing_identity="${NAHTKEY_SIGN_IDENTITY:-$(git config --local --get nahtkey.signingIdentity || true)}"
signing_identity="${signing_identity:--}"
codesign --force --sign "$signing_identity" --identifier vn.nahtkey.mac "$bundle"
codesign --verify --strict "$bundle"
if [ "$signing_identity" = "-" ]; then
    printf '%s\n' 'Ad-hoc build: macOS may require granting Accessibility again after the binary changes.'
fi
printf '%s\n' "$bundle"
