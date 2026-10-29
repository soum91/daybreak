#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-device}"
build_number="${BUILD_NUMBER:-1}"
version="0.1.${build_number}"
if [[ "$mode" == "simulator" ]]; then
  sdk=iphonesimulator
  arch="$(uname -m)"
  target="${arch}-apple-ios17.0-simulator"
  app="build/simulator/Daybreak.app"
else
  sdk=iphoneos
  target=arm64-apple-ios17.0
  app="build/device/Payload/Daybreak.app"
fi
mkdir -p "$app" dist
sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
xcrun --sdk "$sdk" clang -target "$target" -isysroot "$sdk_path" \
  -fobjc-arc -fblocks -O2 -g -Wall -Wextra -Wno-unused-parameter \
  -Wno-deprecated-declarations -IApp \
  -framework UIKit -framework Foundation -framework Intents -framework IntentsUI \
  App/main.m App/Probe.m -o "$app/Daybreak"
APP_PATH="$app" APP_VERSION="$version" BUILD_NUMBER="$build_number" SDK_NAME="$sdk" python3 scripts/info.py
swift scripts/Icon.swift "$app"
codesign --force --sign - "$app"
if [[ "$mode" != "simulator" ]]; then
  (cd build/device && /usr/bin/zip -qry ../../dist/Daybreak.ipa Payload)
  shasum -a 256 dist/Daybreak.ipa > dist/SHA256SUMS.txt
  python3 scripts/validate_ipa.py dist/Daybreak.ipa
fi
