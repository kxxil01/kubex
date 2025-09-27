#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION=${1:-release}
PRODUCT_NAME=kubex
APP_NAME=Kubex
BUILD_DIR=".build/${CONFIGURATION}"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DESTINATION="/Applications/${APP_NAME}.app"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_SCRIPT="${SCRIPT_DIR}/package_app.sh"

if [[ ! -x "${PACKAGE_SCRIPT}" ]]; then
  echo "error: expected packaging script at ${PACKAGE_SCRIPT}" >&2
  exit 1
fi

swift build --configuration "${CONFIGURATION}"
"${PACKAGE_SCRIPT}" "${CONFIGURATION}"

if [[ -d "${DESTINATION}" ]]; then
  echo "Removing existing ${DESTINATION}"
  rm -rf "${DESTINATION}"
fi

echo "Installing ${APP_BUNDLE} -> ${DESTINATION}"
cp -R "${APP_BUNDLE}" "${DESTINATION}"

echo "Done."
