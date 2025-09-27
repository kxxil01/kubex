#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION=${1:-release}
PRODUCT_NAME=kubex
APP_NAME=Kubex
BUILD_DIR=".build/${CONFIGURATION}"
BINARY_PATH="${BUILD_DIR}/${PRODUCT_NAME}"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PLIST_PATH="${CONTENTS_DIR}/Info.plist"
PKGINFO_PATH="${CONTENTS_DIR}/PkgInfo"
ICON_NAME="AppIcon"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cat > "${PLIST_PATH}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>kubex</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.kubex</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Kubex</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "${PKGINFO_PATH}"

# Provide a placeholder icon if none exists.
if [[ ! -f "${RESOURCES_DIR}/${ICON_NAME}.icns" ]]; then
  sips -s format icns /System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns --out "${RESOURCES_DIR}/${ICON_NAME}.icns" >/dev/null 2>&1 || true
fi

cp "${BINARY_PATH}" "${MACOS_DIR}/kubex"
chmod +x "${MACOS_DIR}/kubex"

cat <<EOM
Created app bundle at ${APP_DIR}
EOM
