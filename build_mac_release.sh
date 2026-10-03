#!/bin/bash

# Exit on error
set -e

echo "🚀 Building macOS Release..."
flutter build macos --release

echo "📁 Creating release folder..."
RELEASE_DIR="build/mac_installer"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "📦 Copying the app..."
cp -R "build/macos/Build/Products/Release/wirelessconnect.app" "$RELEASE_DIR/"

echo "🔗 Adding Applications shortcut..."
ln -s /Applications "$RELEASE_DIR/Applications"

echo "💽 Creating DMG file..."
cd build
rm -f WirelessConnect_Mac.dmg
hdiutil create -volname "WirelessConnect" -srcfolder mac_installer -ov -format UDZO WirelessConnect_Mac.dmg
cd ..

echo "🎉 Done! Your distributable file is located at: build/WirelessConnect_Mac.dmg"
echo "Give 'WirelessConnect_Mac.dmg' to your users."
