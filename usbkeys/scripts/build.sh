#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SDKROOT:?Set SDKROOT to an iPhoneOS SDK}"
: "${CC:?Set CC to the Theos iOS toolchain clang executable}"
: "${LDID:?Set LDID to ldid}"
mkdir -p build dist
stage="$PWD/build/stage"
rm -rf "$stage"
mkdir -p "$stage/DEBIAN" "$stage/var/jb/Applications/USBKeys.app" "$stage/var/jb/usr/libexec" "$stage/var/jb/Library/LaunchDaemons"
app="$stage/var/jb/Applications/USBKeys.app"
flags=(-target arm64-apple-ios16.1 -isysroot "$SDKROOT" -fobjc-arc -fblocks -Os -Wall -Wno-nullability-completeness -Wno-macro-redefined -Wno-unknown-warning-option -Wl,-headerpad,0x1000)
"$CC" "${flags[@]}" -framework UIKit -framework Foundation src/App.m -o "$app/USBKeys"
"$CC" "${flags[@]}" -framework Foundation -framework CoreFoundation -framework IOKit src/Daemon.m src/Backend.m src/USBControl.m -o "$stage/var/jb/usr/libexec/usbkeysd"
cp "$app/USBKeys" build/USBKeys.unsigned
cp "$stage/var/jb/usr/libexec/usbkeysd" build/usbkeysd.unsigned
"$LDID" -Spackaging/app-entitlements.plist "$app/USBKeys"
"$LDID" -Spackaging/entitlements.plist "$stage/var/jb/usr/libexec/usbkeysd"
LDID="$LDID" python3 scripts/check_entitlements.py "$stage/var/jb/usr/libexec/usbkeysd"
python3 scripts/check_macho_signing.py build/USBKeys.unsigned "$app/USBKeys"
python3 scripts/check_macho_signing.py build/usbkeysd.unsigned "$stage/var/jb/usr/libexec/usbkeysd"
python3 scripts/package_metadata.py "$stage"
cp packaging/control packaging/postinst packaging/prerm packaging/postrm "$stage/DEBIAN/"
chmod 0755 "$stage/DEBIAN/"{postinst,prerm,postrm} "$app/USBKeys" "$stage/var/jb/usr/libexec/usbkeysd"
version=$(sed -n 's/^Version: //p' packaging/control)
dpkg-deb --root-owner-group -Zxz --build "$stage" "dist/dev.usbkeys.keyboard_${version}_iphoneos-arm64.deb"
