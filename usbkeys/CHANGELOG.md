# Changelog

## 0.1.7 (8): phone-only source trace

- Automatically retain the last 64 timestamped HID control callbacks and replies, including request metadata, stage and status. Never record payloads, transaction tokens, typed keys or passcodes.
- Timestamp setup and interrupt-transfer events; retain actual transfer lengths/errors and native activation/state transitions in existing selectable Copy/Share/Save reports. Preserve the trace after Stop.
- This is source-side recording for a recovery-mode target, not a full USB bus sniffer or a keyboard compatibility fix. Device behavior remains unverified.

## 0.1.6 (7): data-stage callbacks and interrupt counters

- Correction to the initial release claim: replacing the control buffer address with its token is a no-op on native 20B101. `_createBuffer` writes the same value into outputs 0 and 2. It must not be described as a demonstrated transport fix.
- Enable both IN and OUT control data notifications. OUT completions now reach the existing status acknowledgement handler rather than leaving it disabled during registration.
- Add separate interrupt IN attempt, completion, byte and error counters. EP0 control-data completions and kernel-served descriptor callbacks cannot establish interrupt-transfer failure.
- Physical target input remains unverified. The callback and counter changes do not establish that Recovery Assistant accepts this keyboard. No root cause for the input failure has been demonstrated.

## 0.1.5 (6): HID host control requests and live activation evidence

- Added the missing USB HID control-request handler: GET/SET_PROTOCOL, GET/SET_IDLE, GET/SET_REPORT, plus a descriptor fallback. A dedicated notification run loop handles setup, IN completion and OUT data/status phases; a separate mapped buffer receives and discards LED reports. Stop joins the callback thread before releasing its buffers.
- Honor nonzero HID idle periods using released-state reports between manual taps. Never repeat a typed key. Manual keys now require the native driver to report the interface active; failed control transfers stop the session without retry.
- Show live request counts by type, completion/rejection/error counts, boot/report protocol, idle interval and native interface state. Heartbeats refresh this evidence without requiring another key or screenshot. Label app activation as local setup and preserve control evidence after Stop.
- Verified 15 used selector signatures against the actual iPhone14,3 iOS 16.1.1 / 20B101 dispatcher, including callback registration/completion and isActive. Checked native callback packing and its distinct OUT completion acknowledgement. Added portable HID request tests including malformed and short requests.
- Built using the Theos clang/ld64 toolchain and iPhoneOS 16.5 SDK. Signed-code preservation, scoped entitlements, package metadata, seven mocked installer cases, HID mapping and address/undefined-behavior-sanitized HID control tests pass (leak detection disabled because the host cannot run LeakSanitizer). No physical iPhone is connected here. The user's 0.1.4 setup/transport succeeded locally but produced no target input; this release corrects a code omission and does not claim verified recovery-screen compatibility.

## 0.1.4 (5): controller-create hang detection

- The user's 0.1.2 report stopped at "BEGIN: Create controller" with no return code: `IOUSBDeviceControllerCreate` never returned, so no USB change was ever attempted. Create now runs on a worker thread with a 4 s deadline. On timeout the service reports "hung", refuses further USB calls, replies, and exits so launchd relaunches it clean; the hung report is preserved for Last result.
- Check USB and Start first run a read-only service scan: whether an `IOUSBDeviceController` service exists, plus counts of USB device-mode IOService class names (usbdevice/otg/synopsys/dwc/usbmux/tristar/hydra/usbport). Class names only, no property values or identifiers.
- Retains 0.1.3's entitlement correction. Built with clang 18 + ld64.lld against the iPhoneOS 16.5 SDK; signing, entitlement, package and seven installer checks pass. Physical behavior is unverified: this release diagnoses the hang, it does not fix it.

## 0.1.3 (4): USB user-client permission correction

- Replaced the incorrect `com.apple.private.iokit-user-client-class` entitlement with the scoped `com.apple.security.exception.iokit-user-client-class` entry for IOUSBDeviceInterfaceUserClient. Added the USB device-access boolean; retained the existing description-publication permission. Verify these keys in the signed helper during the build.
- The actual iPhone14,3 iOS 16.1.1 / 20B101 kernel contains IOUSBDeviceInterfaceUserClient. Added reproducible evidence and a test against its real dispatcher: all 12 used selector argument counts match. This validates class presence and argument shapes, not user-client access or USB behavior.
- Removed the misleading generic claim that any IOServiceOpen failure means the user client is unavailable. The visible error now includes the exact return code and distinguishes permission, unsupported request, exclusive access and missing-device results.
- Log known runtime permission booleans/class grant, service UID/EUID and advertised kernel user-client class without exposing user data. No user-client type scanning or kernel patch was added.
- Cross-compile/signing/package checks, native-kernel ABI checks and seven mocked installer cases pass. The effect of the entitlement correction on the user's open failure and keyboard operation remains device-unverified.

## 0.1.2 (3): complete operation diagnostics

- Fixed a confirmed reporting gap: successful controller creation was logged, but USB snapshot calls and their NULL results were not. Check USB and Start could therefore show the same one-line log.
- Record operation, API stage, snapshot result, service version/PID, activity state, and final status together in the on-screen and exported report. Show specific IPC stage/errno rather than leaving an old success line visible.
- Persist diagnostic-only step state before private USB calls. Add Last result, which reads it independently of the socket; preserve the last interrupted session through service restart. No typed text or key values are recorded.
- Capture read-only controller class and relevant registry property names/types, without property values or device identifiers. Reject aliased snapshot objects before editing a working description.
- Disable keys until live setup succeeds; a saved report cannot activate them. Catch service Objective-C exceptions and disable keys on failure. After an interrupted publication, refuse another setup in the same boot because the prior in-memory restoration snapshot is lost.
- Retain the corrected rootless installer and signing checks. Build/package checks, seven mocked installer tests, and HID mapping tests pass. This is a diagnostics and error-handling update; snapshot failure, physical journal/export access, and USB keyboard operation are not device-verified.

## 0.1.1-1 (packaging revision)

- Rebuild only; app and daemon binaries and app metadata are byte-for-byte identical to 0.1.1 (2). The user's screenshot confirms the UI now launches, but installation failed because the maintainer script called nonexistent `/bin/launchctl`.
- Resolve launchctl from an explicit rootless Procursus PATH in install/remove scripts; declare launchctl and uikittools dependencies.
- Create the runtime socket directory with root/mobile permissions before service loading. Replace a stale socket, attempt bootstrap with load fallback, and check that the control socket appears before reporting installation success.
- Added seven installer tests using mocked launchctl/uicache/chown and socket-type filesystem fixtures. They cover both rootless executable locations, bootstrap fallback, startup failure, missing command, missing socket, and removal. Actual launchd service startup and USB HID operation still require physical verification.

## 0.1.1 (2)

- Fixed a verified binary corruption in 0.1.0: the signature load command overwrote the first 16 bytes of executable code in both app and daemon.
- Rebuilt with the standard iOS clang/ld64 toolchain and explicit header padding. Added mandatory before/after signing checks for all __TEXT sections and load-command boundaries. Both old binaries fail this check; both rebuilt binaries pass.
- Removed the unnecessary app IOKit dependency and automatic USB probe on app launch.
- Added explicit container entitlements and complete platform bundle metadata.
- Read the app version/build from installed Info.plist. Added clipboard read-back verification and native Save report.
- Cross-compiled and checked package/signatures/ASCII mappings. Physical launch, export UI, and USB HID operation remain unverified.

## 0.1.0 (1)

- Added experimental Lightning USB HID keyboard publication via IOKit.
- Added rootless Home Screen app and privileged service with restricted local IPC.
- Added numeric keypad, US ASCII typing, navigation keys, and explicit Start/Stop.
- Added snapshot restoration, inactivity timeout, and transport error handling.
- Added installed version, copy/share diagnostics, and generated app icon.
- Cross-compiled and signed arm64 binaries; tested ASCII mapping and descriptor
  boundaries. Hardware operation and Recovery Assistant support remain untested.
