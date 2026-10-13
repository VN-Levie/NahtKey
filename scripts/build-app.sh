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
# Finder's large preview needs the modern icon stack, not only a legacy ICNS.
# actool also renders the ICNS fallback for our macOS 14 deployment target.
icon_output="$task_root/.build/app-icon"
mkdir -p "$icon_output"
xcrun actool "$task_root/assets/NahtKey.icon" \
    --compile "$icon_output" \
    --app-icon NahtKey \
    --target-device mac \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --bundle-identifier vn.nahtkey.mac \
    --output-partial-info-plist "$icon_output/icon.plist" \
    --output-format human-readable-text --warnings --errors --notices
cp "$icon_output/Assets.car" "$bundle/Contents/Resources/Assets.car"
cp "$icon_output/NahtKey.icns" "$bundle/Contents/Resources/NahtKey.icns"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>NahtKey</string>
<key>CFBundleDisplayName</key><string>NahtKey</string>
<key>CFBundleIdentifier</key><string>vn.nahtkey.mac</string>
<key>CFBundleExecutable</key><string>NahtKey</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.3</string>
<key>CFBundleVersion</key><string>11</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>NahtKey contributors</string>
</dict></plist>
PLIST
# Merge both CFBundleIconName (Assets.car) and CFBundleIconFile (ICNS) exactly
# as emitted by the compiler, so the two representations stay in sync.
/usr/libexec/PlistBuddy -c "Merge $icon_output/icon.plist" "$bundle/Contents/Info.plist"
signing_identity="${NAHTKEY_SIGN_IDENTITY:-$(git config --local --get nahtkey.signingIdentity || true)}"
signing_identity="${signing_identity:--}"
codesign --force --sign "$signing_identity" --identifier vn.nahtkey.mac "$bundle"
codesign --verify --strict "$bundle"
# Package mtime is used by Finder/Spotlight/icon caches. mkdir/ditto alone can
# leave the original 0.1 package date even while every file inside is updated.
touch "$bundle"
if [ "$signing_identity" = "-" ]; then
    printf '%s\n' 'Ad-hoc build: macOS may require granting Accessibility again after the binary changes.'
fi
printf '%s\n' "$bundle"
