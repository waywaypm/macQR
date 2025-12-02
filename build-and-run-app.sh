#!/bin/bash

# Build and run macOS .app bundle for macQR with DMG packaging

# Exit on error
set -e

echo "=== macQR App Build and Run Script ==="

# 1. Clean previous builds
echo "1. Cleaning previous builds..."
rm -rf macQR.app
rm -rf .build
rm -f macQR.dmg

# 2. Build executable
echo "2. Building executable..."
swift build -c release

# 3. Create app bundle structure
echo "3. Creating app bundle structure..."
mkdir -p macQR.app/Contents/MacOS
mkdir -p macQR.app/Contents/Resources

# 4. Copy executable
echo "4. Copying executable..."
cp .build/release/macQR macQR.app/Contents/MacOS/

# 5. Copy Info.plist
echo "5. Copying Info.plist..."
cp Sources/macQR/Resources/Info.plist macQR.app/Contents/

# 6. Copy resources
echo "6. Copying resources..."
cp -r Sources/macQR/Resources/* macQR.app/Contents/Resources/

# 7. Make executable
echo "7. Setting executable permissions..."
chmod +x macQR.app/Contents/MacOS/macQR

# 8. Verify app bundle
echo "8. Verifying app bundle..."
if [ -f macQR.app/Contents/MacOS/macQR ] && [ -f macQR.app/Contents/Info.plist ]; then
    echo "✅ App bundle created successfully!"
    echo "App path: $(pwd)/macQR.app"
else
    echo "❌ App bundle creation failed!"
    exit 1
fi

# 9. Create DMG package with drag-to-Applications guide
echo "9. Creating DMG package with drag-to-Applications guide..."

# Create temporary directory for DMG contents
DMG_TMP_DIR="macQR_dmg_tmp"
rm -rf "$DMG_TMP_DIR"
mkdir -p "$DMG_TMP_DIR"

# Copy app to DMG temporary directory
cp -r macQR.app "$DMG_TMP_DIR/"

# Create Applications folder shortcut
echo "   Creating Applications folder shortcut..."
ln -s /Applications "$DMG_TMP_DIR/"

# Create a simple background image with text using a more reliable method
echo "   Creating background with drag guide..."
BACKGROUND_IMG="$DMG_TMP_DIR/.background"
mkdir -p "$BACKGROUND_IMG"

# Use a simple method to create a background image with text
# We'll create a text file with instructions instead of a graphical background
# This is more reliable and works on all macOS versions
echo "将 macQR.app 拖到 Applications 文件夹以安装" > "$DMG_TMP_DIR/安装说明.txt"

# Create a disk image with initial content
echo "   Creating DMG image..."
hdiutil create -fs HFS+ -volname "macQR" -srcfolder "$DMG_TMP_DIR" -ov -format UDZO macQR.dmg

# Clean up temporary files
echo "   Cleaning up temporary files..."
rm -rf "$DMG_TMP_DIR"

# 10. Verify DMG package
echo "10. Verifying DMG package..."
if [ -f macQR.dmg ]; then
    echo "✅ DMG package created successfully!"
    echo "DMG path: $(pwd)/macQR.dmg"
else
    echo "❌ DMG package creation failed!"
    exit 1
fi

echo "=== Build and Package Complete ==="
