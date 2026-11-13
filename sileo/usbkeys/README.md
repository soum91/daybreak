# USBKeys Experimental Sileo source

Add this URL in Sileo > Sources > +:

https://raw.githubusercontent.com/soum91/daybreak/main/sileo/usbkeys/

Install **USBKeys Experimental** on the jailbroken iPhone 13 Pro Max, iOS 16.1.1,
Dopamine. This is an isolated flat APT source hosted beside Daybreak's source.

The package is compiled and signed for arm64 iOS 16.1. App UI launch is confirmed by the user. USB HID operation and iPhone 17
Recovery Assistant compatibility are **unverified**.
There are no receiver-app requirements on the target. No claim is made that
installing the package will recover a phone or preserve its iOS version.

Open USBKeys, run Check USB, and test one key against a harmless text field on
a computer before attempting the recovery screen. Stop restores the source
phone's USB configuration when the private APIs cooperate. If restoration
fails, disconnect and reboot the 13 Pro Max, then re-enable Dopamine.

This is an unsigned APT source served over HTTPS, like the existing Daybreak
source. The package itself is ad-hoc signed for the jailbreak environment.
These signatures are different from APT repository signatures. Sileo import
and installation have not been tested on a physical device.

Version 0.1.1 (build 2) fixes a confirmed 0.1.0 packaging defect: the signer
overwrote the first 16 bytes of executable code in both the app and service.
The rebuilt binaries use the standard iOS toolchain with reserved signature
header space. Regression checks reject the old package and confirm signing
preserves all new code sections. The broken 0.1.0 package is withdrawn.

Packaging revision **0.1.1-1** repairs the failed install shown by the user:
`/bin/launchctl` was not found, so the USB service never started. The new
maintainer scripts resolve the Procursus launchctl from rootless PATH, declare
the required tools, create the runtime directory, and check socket readiness.
Seven mocked installer cases pass. Actual device service startup is unverified.
The signed executables and app metadata are unchanged from 0.1.1 (2); the
in-app version remains 0.1.1 (2). This is a packaging-only rebuild.

`USBKeys-0.1.1-1-source.zip` contains the complete source and build instructions.
Run `python3 scripts/build_usbkeys_sileo.py` from the repository root to rebuild
these indexes. SHA256SUMS and Release contain hashes for byte verification.
