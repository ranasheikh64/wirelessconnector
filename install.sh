#!/bin/bash

# WirelessConnect - One-line macOS Installer
# Usage: curl -sL https://raw.githubusercontent.com/ranasheikh64/wirelessconnector/main/install.sh | bash

set -e

echo ""
echo "  ██╗    ██╗██╗██████╗ ███████╗██╗     ███████╗███████╗███████╗"
echo "  ██║    ██║██║██╔══██╗██╔════╝██║     ██╔════╝██╔════╝██╔════╝"
echo "  ██║ █╗ ██║██║██████╔╝█████╗  ██║     █████╗  ███████╗███████╗"
echo "  ██║███╗██║██║██╔══██╗██╔══╝  ██║     ██╔══╝  ╚════██║╚════██║"
echo "  ╚███╔███╔╝██║██║  ██║███████╗███████╗███████╗███████║███████║"
echo "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝"
echo ""
echo "  WirelessConnect - macOS Installer"
echo "  By Jronix Software Solutions"
echo ""

VERSION="v1.0.0"
DMG_NAME="WirelessConnect_Mac.dmg"
DOWNLOAD_URL="https://github.com/ranasheikh64/wirelessconnector/releases/download/${VERSION}/${DMG_NAME}"
INSTALL_DIR="/Applications"
APP_NAME="wirelessconnect.app"
MOUNT_POINT="/tmp/WirelessConnect_Install"
DMG_PATH="/tmp/${DMG_NAME}"

echo "⬇️  Downloading WirelessConnect ${VERSION}..."
curl -L --progress-bar "$DOWNLOAD_URL" -o "$DMG_PATH"

echo ""
echo "💿 Mounting installer..."
rm -rf "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -quiet

echo "📂 Installing to /Applications..."
rm -rf "${INSTALL_DIR}/${APP_NAME}"
cp -R "${MOUNT_POINT}/${APP_NAME}" "${INSTALL_DIR}/"

echo "🔓 Removing macOS security restrictions..."
xattr -cr "${INSTALL_DIR}/${APP_NAME}"

echo "🧹 Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$DMG_PATH"

echo ""
echo "✅ WirelessConnect installed successfully!"
echo "🚀 Launching app..."
echo ""
open "${INSTALL_DIR}/${APP_NAME}"
