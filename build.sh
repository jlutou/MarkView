#!/bin/bash
set -e

SDK=$(xcrun --show-sdk-path)
TARGET="arm64-apple-macosx14.0"

echo "Building MarkView app..."
swiftc -parse-as-library -O \
    -sdk "$SDK" \
    -target "$TARGET" \
    Sources/MarkViewApp.swift \
    Sources/MarkdownDocument.swift \
    Sources/ContentView.swift \
    Sources/MarkdownRenderer.swift \
    -o MarkView

echo "Building Quick Look extension..."
swiftc -parse-as-library -O \
    -sdk "$SDK" \
    -target "$TARGET" \
    -module-name MarkViewQL \
    -application-extension \
    -Xlinker -e -Xlinker _NSExtensionMain \
    Sources/PreviewViewController.swift \
    Sources/MarkdownParser.swift \
    -o MarkViewQL

# --- Assemble .app bundle ---
APP="build/MarkView.app"
rm -rf build
mkdir -p build

# Main app
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp MarkView "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Sources/marked.min.js "$APP/Contents/Resources/"
cp MarkView.icns "$APP/Contents/Resources/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Quick Look extension
EXT="$APP/Contents/PlugIns/MarkViewQL.appex/Contents"
mkdir -p "$EXT/MacOS"
cp MarkViewQL "$EXT/MacOS/"
cp QLExtension-Info.plist "$EXT/Info.plist"

# Sign extension (sandbox required for QL extensions) and app
codesign --force --sign - --entitlements QLExtension.entitlements "$APP/Contents/PlugIns/MarkViewQL.appex"
codesign --force --sign - "$APP"

# Cleanup
rm -f MarkView MarkViewQL

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(pwd)/$APP" 2>/dev/null || true

echo ""
echo "MarkView.app ready! (with Quick Look extension)"
echo ""
echo "  Run:      open $APP"
echo "  Install:  cp -r $APP /Applications/ && qlmanage -r"
