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

## Review of 0.1.6 claims

The supplied 0.1.5 report contains six host HID class setup requests, two each
of SET_REPORT, SET_IDLE and SET_PROTOCOL. This demonstrates host interaction;
it contradicts claims that the target never enumerated at all. The report's
`completed` counter belongs only to class-control callbacks on EP0. It cannot
establish failure of the separate synchronous interrupt-IN selector 14.

Native `_createBuffer` at 0xfffffff009d69180 writes the value at stack offset
0 to output scalar 0 (instructions at 0xfffffff009d691d8..0xfffffff009d691e0).
It then loads that same stack value into x10 and stores it as output scalar 2
(0xfffffff009d691e4..0xfffffff009d691e8). Thus the source-level pointer/token
substitution in 0.1.6 has no effect on this firmware. A unit test with different
synthetic values checks packing only, not this native behavior.

Registration flags were changed from 1/0/0 to 1/1/1. This enables data-stage
notifications; its effect on target input is unverified. It does not by itself
prove the previous host control transactions failed. Do not present 0.1.6 as
an established fix for the user's input failure.

The unresolved boundary is between interrupt reports on the USB bus and target
input handling. A USB host descriptor/transfer capture or target HID logs are
needed to distinguish a malformed/rejected report from Recovery Assistant
ignoring an otherwise valid keyboard. This environment has no connected source
or target iPhone. Compilation and source analysis cannot perform that test.
