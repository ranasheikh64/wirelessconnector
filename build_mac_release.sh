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

echo "📜 Creating installer script..."
INSTALLER_PATH="$RELEASE_DIR/Install_WirelessConnect.command"

cat << 'EOF' > "$INSTALLER_PATH"
#!/bin/bash
clear
echo "=========================================="
echo "    WirelessConnect macOS Installer       "
echo "=========================================="
echo ""

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$DIR/wirelessconnect.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: wirelessconnect.app not found in this folder!"
    exit 1
fi

echo "📂 Installing to Applications folder..."
# Remove old version if it exists
rm -rf /Applications/wirelessconnect.app
cp -R "$APP_PATH" /Applications/

echo "🔓 Removing Apple Quarantine restrictions..."
xattr -cr /Applications/wirelessconnect.app

echo "✅ Installation Complete!"
echo "🚀 Opening WirelessConnect..."
open /Applications/wirelessconnect.app

echo ""
echo "You can now close this terminal window."
sleep 3
EOF

# Make the installer script executable
chmod +x "$INSTALLER_PATH"

echo "💽 Creating DMG file..."
cd build
hdiutil create -volname "WirelessConnect Installer" -srcfolder mac_installer -ov -format UDZO WirelessConnect_Mac.dmg
cd ..

echo "🎉 Done! Your distributable file is located at: build/WirelessConnect_Mac.dmg"
echo "Give 'WirelessConnect_Mac.dmg' to your users."
