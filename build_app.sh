#!/bin/bash
set -e

SRC_DIR="/Users/suddharay/Library/Mobile Documents/com~apple~CloudDocs/Mac Projects/DNS Switcher (Swift)"
DEST_APP_DIR="/Users/suddharay/Applications"
APP_NAME="DNS Switcher.app"
FINAL_APP_PATH="${DEST_APP_DIR}/${APP_NAME}"

echo "Building Swift Application: ${APP_NAME}..."

mkdir -p "${DEST_APP_DIR}"

BUILD_TMP=$(mktemp -d)
trap 'rm -rf "$BUILD_TMP"' EXIT

cd "${SRC_DIR}"

echo "Compiling Swift files..."
swiftc -O \
    -parse-as-library \
    -target arm64-apple-macosx13.0 \
    DNS_SwitcherApp.swift ContentView.swift DNSManager.swift \
    -o "${BUILD_TMP}/DNS Switcher"

echo "Creating App Bundle..."
rm -rf "${FINAL_APP_PATH}"
mkdir -p "${FINAL_APP_PATH}/Contents/MacOS"
mkdir -p "${FINAL_APP_PATH}/Contents/Resources"

cp "${BUILD_TMP}/DNS Switcher" "${FINAL_APP_PATH}/Contents/MacOS/DNS Switcher"
chmod +x "${FINAL_APP_PATH}/Contents/MacOS/DNS Switcher"

# Convert AppIcon.png to AppIcon.icns if present
if [ -f "${SRC_DIR}/AppIcon.png" ]; then
    echo "Generating AppIcon.icns..."
    ICONSET="${BUILD_TMP}/AppIcon.iconset"
    mkdir -p "${ICONSET}"
    
    sips -s format png -z 16 16     "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 "${SRC_DIR}/AppIcon.png" --out "${ICONSET}/icon_512x512@2x.png" > /dev/null 2>&1
    
    iconutil -c icns "${ICONSET}" -o "${FINAL_APP_PATH}/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "${FINAL_APP_PATH}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DNS Switcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.suddharay.DNS-Switcher</string>
    <key>CFBundleName</key>
    <string>DNS Switcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Touch app bundle to notify macOS Finder of icon update
touch "${FINAL_APP_PATH}"

echo "App Bundle successfully built with icon and saved to ${FINAL_APP_PATH}"
