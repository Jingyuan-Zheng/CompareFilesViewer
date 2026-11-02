#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$PROJECT_DIR"
# A temporary build path also supports checkouts whose paths contain colons.
BUILD_DIR="$(/usr/bin/mktemp -d -t compare-files-compile)"
SIGN_DIR=""
trap '/bin/rm -rf "$BUILD_DIR"; if [[ -n "$SIGN_DIR" ]]; then /bin/rm -rf "$SIGN_DIR"; fi' EXIT
swift build --scratch-path "$BUILD_DIR" -c release
BIN_DIR="$(swift build --scratch-path "$BUILD_DIR" -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/.build/CompareFilesViewer.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/CompareFilesViewer" "$APP_DIR/Contents/MacOS/CompareFilesViewer"
/usr/bin/ditto "$BIN_DIR/CompareFilesViewer_CompareFilesViewer.bundle" "$APP_DIR/Contents/Resources/CompareFilesViewer_CompareFilesViewer.bundle"
/usr/bin/ditto "$PROJECT_DIR/Sources/CompareFilesViewer/Resources/en.lproj" "$APP_DIR/Contents/Resources/en.lproj"
/usr/bin/ditto "$PROJECT_DIR/Sources/CompareFilesViewer/Resources/zh-Hans.lproj" "$APP_DIR/Contents/Resources/zh-Hans.lproj"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Compare Files</string>
<key>CFBundleDisplayName</key><string>Compare Files</string>
<key>CFBundleExecutable</key><string>CompareFilesViewer</string>
<key>CFBundleIdentifier</key><string>dev.jingyuan.CompareFilesViewer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Sign outside cloud-synced folders, which can add Finder metadata during signing.
SIGN_DIR="$(/usr/bin/mktemp -d -t compare-files-build)"
/usr/bin/ditto --norsrc "$APP_DIR" "$SIGN_DIR/CompareFilesViewer.app"
/usr/bin/xattr -cr "$SIGN_DIR/CompareFilesViewer.app"
/usr/bin/codesign --force --deep --sign - "$SIGN_DIR/CompareFilesViewer.app"
/usr/bin/codesign --verify --deep --strict "$SIGN_DIR/CompareFilesViewer.app"
/usr/bin/ditto --norsrc "$SIGN_DIR/CompareFilesViewer.app" "$APP_DIR"
printf 'Built app: %s\n' "$APP_DIR"
