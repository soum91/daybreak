# USBKeys 0.1.5 (6), experimental

A rootless jailbreak package for an iPhone 13 Pro Max on iOS 16.1.1 with
Dopamine. The Home Screen app controls a root service that attempts to publish
a USB HID boot keyboard over Lightning. The target end uses USB-C.

**This is an experimental port. App UI launch has been confirmed by the user; USB HID operation is not verified.**
No iPhone is connected to the build environment. The user reports that 0.1.4 opened the iOS 16 interface and completed local
setup and transport, but no character appeared on the target. iPhone 17 / iOS 27
Recovery Assistant keyboard input remains unverified. A successful build or local configuration is not evidence of host
recognition. It cannot guarantee recovery or preservation of an iOS version.

## Install and use

1. Install `dev.usbkeys.keyboard_0.1.5_iphoneos-arm64.deb` with Filza on the
   jailbroken 13 Pro Max. This is a jailbreak package, not a sideloadable IPA.
2. Open USBKeys from the Home Screen. Tap **Check USB**.
3. For the first test, connect Lightning to the 13 Pro Max and USB-C to a
   computer. Open a harmless text field there. Tap **Start**, then a single
   digit. Check it appears once. Tap **Stop**.
4. If that succeeds, connect the cable to the target iPhone instead. Tap
   **Start**, then enter keys manually. The numeric pad has Backspace and
   Return; the full keyboard field supports US ASCII. Input is sent immediately.
5. Tap **Stop** before unplugging. If anything fails, **Copy diagnostics** or
   **Share diagnostics** exports the exact stage and IOKit return code.

The target must act as USB host and accept a keyboard in its current screen.
This package does not change the target's firmware, recovery system, USB
accessory policy, or passcode. No receiver app is used on the target.

## Corrected launch packaging in 0.1.1

Version 0.1.0 was broken: signing added a 16-byte LC_CODE_SIGNATURE load command
without reserved header space and overwrote the first 16 bytes of __text in both
binaries. The new build uses the standard iOS clang/ld64 toolchain and reserves
0x1000 bytes of header space. A mandatory check rejects command/section overlap
and compares every __TEXT section before and after signing. It rejects the old
artifacts and passes both new binaries. The user has confirmed app UI launch. USB calls require an explicit Check USB or
Start action, and keyboard operation remains unverified.

## Installer correction in 0.1.1-1

This packaging-only revision replaces the incorrect `/bin/launchctl` call with
rootless PATH lookup, declares required tools, prepares the runtime directory,
and checks that the service creates its control socket. It preserves the signed
binaries and app metadata from 0.1.1 (2), so that is still the in-app version.
Seven mocked installer tests pass; physical service startup remains unverified.

## Diagnostic update in 0.1.2

Version 0.1.1 omitted snapshot results from its log. A lone successful controller
line could not distinguish a successful check, missing snapshot, or failed Start.
The new report includes operation, last stage, status, active state, service
version/PID, and snapshot results. **Last result** reads a diagnostic-only journal
independently of the service socket, so a pending call or service restart can be
identified. The journal contains no typed keys, text, serial numbers, or registry
property values. Keys stay disabled until a live setup response activates them.

This update does not establish why the user's keyboard setup stopped and does
not claim USB HID compatibility. If the original USB description is unavailable,
Start still refuses to publish a keyboard because it cannot preserve restoration.

## USB user-client correction in 0.1.3

The user's report now identifies failure at IOServiceOpen(type 123), after
publication of the custom interface. The prior helper used an incorrect IOKit
class entitlement key. Version 0.1.3 corrects it, adds USB device access, verifies
the signed permissions, and reports the exact kernel return code instead of
calling every failure an unavailable user client.

Inspection of the actual iPhone14,3 / 20B101 kernel confirms the user-client class
and the argument counts for all used selectors. See `research/README.md` and
`tests/usb_abi_test.py`. This does not prove that the permissions correction
resolves the user's failure; physical user-client access and HID operation still
require testing. No kernel patch or alternate user-client type guessing is used.

## Implemented behavior

- Finds the real `IOUSBDeviceController` through IOKit's private API.
- Captures two independent descriptions before publishing: an untouched
  snapshot for restoration and a working description for the keyboard.
- Publishes one HID interface, installs a 63-byte standard boot keyboard report
  descriptor, creates an eight-byte interrupt IN endpoint, and re-enumerates.
- Attempts interface user client type 123 and the method layout documented by
  the upstream macOS proof of concept. Argument counts match the actual 20B101
  dispatcher; successful access and behavior are unverified.
- Sends a key press and an all-keys-up report for each user action.
- Stops on transport failure, without automatically retrying any input.
- Restores the original description on Stop, handled failure, backgrounding,
  normal service termination, or 30 seconds without app heartbeat.
- Uses a Unix socket restricted to root and mobile; it opens no network port.
- Does not log or store typed characters, passcodes, or USB serial numbers.
- Shows installed version and build in the app and diagnostics.

## Limits and recovery

USB mode changes temporarily replace the source iPhone's normal USB functions.
The process could crash, the kernel could reject a private call, or the host
could reject the resulting device. The runtime snapshot is in memory, not a
firmware backup. It cannot survive a daemon crash. If Stop fails or the app loses
USB functionality, disconnect and reboot the **13 Pro Max**; a full reboot
requires re-enabling Dopamine. This does not guarantee recovery from a kernel
fault. No MobileGestalt, system volume, or persistent USB configuration is edited.

HID class requests are explicitly handled in 0.1.5. Live request counters and
native interface activation distinguish local setup from host communication.
A host may enumerate without issuing optional HID class requests, so zero
request counts alone do not establish failed enumeration.
The diagnostic screen distinguishes local setup from reports transferred. It
cannot observe whether the target actually entered a character.

## Build

On Linux with the Theos iOS clang/ld64 toolchain, an iPhoneOS 16.5 SDK, ldid, dpkg-deb, Python and Pillow:

```sh
export SDKROOT=/absolute/path/iPhoneOS16.5.sdk
export CC=/absolute/path/toolchain/linux/iphone/bin/clang
export LDID=/absolute/path/ldid
bash scripts/build.sh
gcc -Wall -Wextra -Werror tests/hid_test.c -o /tmp/usbkeys-hid-test
/tmp/usbkeys-hid-test
python3 scripts/validate_package.py
python3 tests/installer_test.py
gcc -Wall -Wextra -Werror tests/hid_control_test.c -o /tmp/usbkeys-hid-control-test
/tmp/usbkeys-hid-control-test
```

Outputs go to `dist/`. Only arm64 device binaries are included, targeting iOS
16.1. Dependencies and SDKs are not included in the source archive.

## Research and attribution

- [libusbd](https://github.com/shinyquagsire23/libusbd), MIT, Max Thomas.
  Method numbers and descriptor/endpoint sequence adapted from its macOS
  implementation. The applicable notice is in `THIRD_PARTY_LICENSES.txt`.
- [macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc):
  demonstrated USB keyboard device mode on Apple Silicon Macs. Its custom macOS
  kernel extension is not used or included. This is not proof of iPhone support.
- [Synacktiv, iOS: a journey in the USB networking stack](https://www.synacktiv.com/en/publications/ios-a-journey-in-the-usb-networking-stack):
  iOS device-mode architecture and configuration publication.

The build SDK exports the controller and description symbols used by this
package. Runtime symbol resolution and entitlements still require device tests.

**0.1.4 (5)** adds hang detection. The 0.1.2 report showed the service stuck inside
`IOUSBDeviceControllerCreate` with no return code. Create now has a 4 s deadline;
on timeout the service reports it, refuses further USB calls and restarts. Check USB
and Start also list whether an `IOUSBDeviceController` service exists and which USB
device-mode IOService classes are present (names only). Diagnostic only; the hang
itself is not fixed.

## Host control handling in 0.1.5

The previous code never registered a class request callback. This release handles
keyboard protocol, idle and report requests, including the native driver's
separate OUT status acknowledgement. SET_REPORT LED payloads are discarded, not
logged. A separate thread services host requests while manual report writes run.
Diagnostics refresh every app heartbeat and retain only counts, protocol, idle
and driver state, never input values. Nonzero idle requests resend only the
released state. This is a concrete implementation change, not verified target input.
