# iOS 16.1.1 USB interface investigation

The user's 0.1.2 screenshot fails at IOServiceOpen(type 123), after descriptions
were captured and the USB interface was published. That screenshot alone omits
the return code, so it does not establish permission denial versus another error.
The old failure message incorrectly called every error an unavailable user client.

The Apple-supplied iPhone14,3 / 20B101 kernel was extracted read-only from the IPSW
in `20B101-usb-evidence.json`. Its IOUSBDeviceFamily contains the real
IOUSBDeviceInterfaceUserClient implementation. Its dispatcher argument counts
match the selectors used here, as checked by `tests/usb_abi_test.py` against the
actual extracted kext. This rules out simply saying the class is absent. It does
not prove access or hardware behavior. The kernel and kext are not redistributed.

The prior helper incorrectly declared `com.apple.private.iokit-user-client-class`.
The corrected helper declares `com.apple.security.exception.iokit-user-client-class`
with only IOUSBDeviceInterfaceUserClient, matching the class exception used by
Apple's dmd service in the nearby 16.1.2 / 20B110 entitlement dump:
https://github.com/ChiChou/entdb-data/blob/main/iOS/16.1.2_20B110/bin/usr/libexec/dmd.xml
It also declares the USB device-access boolean documented by Apple:
https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.usb
A signed-binary check confirms both keys exist in the packaged helper. Runtime
permission reads and the exact IOServiceOpen error are included in 0.1.3 reports.

This is a concrete entitlement correction and more accurate error reporting,
not proof that it resolves the user's IOServiceOpen failure. The class exists;
the access failure's specific return code and the effect of the fix still need
on-device verification. No user-client type scanning or kernel patch was added.

## 0.1.5 host control ABI

The user's latest 0.1.4 report shows all local setup calls returning zero and
transfers completing, but no target input. The code had no class-request callback.
Native 20B101 disassembly confirms selector 8 takes three scalar flags plus an
async reference; selector 9 accepts a variable scalar count. Selector 24 returns
a native active boolean and an integer state. All 15 used signatures are tested.

`classCommandNotifyHandler` at 0xfffffff009d6b05c emits five arguments: stage 0,
packed request type/request/value, packed index/length, length, transaction token.
`completeClassCommandCallbackGated` at 0xfffffff009d6b190 checks at least five
scalars for setup and consumes handled/length/address/status/token.
`classCommandDataFinishHandler` at 0xfffffff009d6b4c4 emits six arguments: stage
1 for IN or 2 for OUT, the same packed request fields, length, token, status.
Stage 1 needs no second completion. Stage 2 expects two scalars: status/token.
These details avoid the upstream callback's TODO that completes both phases
using the same five arguments. No native binary is redistributed.

The class callback ABI follows libusbd discovery, but setup/OUT completion and
HID request validation are implemented separately. Request behavior follows
USB HID 1.11 section 7.2: https://www.usb.org/sites/default/files/hid1_11.pdf .
Apple's generic async dispatch callback receives refcon/result/args/count:
https://github.com/apple-oss-distributions/IOKitUser/blob/main/IOKitLib.h .
Standard report descriptors normally remain kernel-served and need not appear
in the class counters. A count of zero is not proof of host enumeration failure.
