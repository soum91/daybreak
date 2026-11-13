# Changelog

## USBKeys 0.1.4 (5): controller-create hang detection (2026-11-13)

- The user's 0.1.2 report stopped at "BEGIN: Create controller" with no return code: `IOUSBDeviceControllerCreate` never returned, so no USB change was ever attempted. Create now runs on a worker thread with a 4 s deadline. On timeout the service reports "hung", refuses further USB calls, replies, and exits so launchd relaunches it clean; the hung report is preserved for Last result.
- Check USB and Start first run a read-only service scan: whether an `IOUSBDeviceController` service exists, plus counts of USB device-mode IOService class names (usbdevice/otg/synopsys/dwc/usbmux/tristar/hydra/usbport). Class names only, no property values or identifiers.
- Retains 0.1.3's entitlement correction. Built with clang 18 + ld64.lld against the iPhoneOS 16.5 SDK; signing, entitlement, package and seven installer checks pass. Physical behavior is unverified: this release diagnoses the hang, it does not fix it.

## USBKeys 0.1.3 (4): USB user-client permission correction (2026-11-13)

- Corrected the helper's IOKit class exception entitlement key, added USB device access, and added a signed-binary permission gate. Runtime reports include only the relevant permission grant states and advertised user-client class.
- Investigated the actual iPhone14,3 / iOS 16.1.1 20B101 kernel: IOUSBDeviceInterfaceUserClient exists and its dispatcher matches the 12 selector argument counts used here. The source archive includes reproducible evidence and the native-kernel test; no proprietary kernel binary is redistributed.
- Replaced the generic "unavailable on this build" message with the exact IOServiceOpen return code and error classification. No kernel patch or user-client type scanning was added.
- Build/signing/package, native ABI and seven mocked installer checks pass. Permission correction effects and physical USB keyboard operation remain unverified. Daybreak executables and its existing source are unchanged.

## USBKeys 0.1.2 (3): operation and failure reporting (2026-11-13)

- Fixed the reporting gap behind the user's one-line controller log: snapshot calls/results were omitted, and a failed IPC request could leave old diagnostics visible. Reports now include operation, last step, full status, active state, and service version/PID; IPC errors include stage and errno.
- Added a diagnostic-only journal written before private USB calls and a Last result button that reads it without contacting the service. Preserve interrupted-stage evidence across service restart; log no typed input, serial numbers, or registry property values.
- Disable key controls until live setup succeeds, reject aliased snapshots before editing, and report service Objective-C exceptions. Prevent a repeat setup in the same boot after a service restart loses an interrupted USB publication's restoration snapshot.
- Retained rootless installer and binary-signing checks. Build/package checks, seven mocked installer tests and keyboard mapping tests pass. USB operation and physical diagnostic access remain unverified; this release does not claim to fix the unknown USB compatibility failure.

## USBKeys 0.1.1-1: rootless installer correction (2026-11-13)

- Rebuild only; both signed binaries and app metadata are unchanged from 0.1.1 (2). The user confirmed app UI launch but reported dpkg exit 127 because `/bin/launchctl` does not exist on their Dopamine installation.
- Fixed install/removal scripts to resolve Procursus launchctl through rootless PATH; added launchctl/uikittools dependencies, runtime directory setup, bootstrap/load handling, and socket-readiness checks.
- Seven mocked installer test cases pass. Package binary preservation and APT metadata checks pass. Physical service startup and USB keyboard operation remain unverified.
- Replaced the 0.1.1 APT candidate and source archive with 0.1.1-1. Daybreak app code and its Sileo source are unchanged.

## USBKeys 0.1.1 (2): corrected launch binaries (2026-11-13)

- Replaced the broken USBKeys 0.1.0 package with 0.1.1. The old signer added a 16-byte signature load command over the first 16 bytes of executable code in both binaries. Rebuilt with iOS clang/ld64 and reserved header padding.
- Added a mandatory signing regression check: load commands cannot overlap sections, and all __TEXT bytes must match before and after signing. Both old binaries fail; both new binaries pass.
- Removed automatic USB probing at launch and the app's unnecessary IOKit dependency. Added container entitlements and platform metadata; app version now comes from installed Info.plist. Diagnostics now verify clipboard reads and support native Save report.
- Updated USBKeys package indexes, checksums, and full source archive; withdrew 0.1.0. No Daybreak executable changes. Physical launch and USB keyboard operation remain unverified.

## USBKeys experimental Sileo hosting (2026-11-13)

- Added a separate flat APT source at `sileo/usbkeys/`, with the original USBKeys 0.1.0 rootless package, source archive, icon, compressed package indexes, and Release checksums.
- Added `scripts/build_usbkeys_sileo.py` to regenerate only the USBKeys source. The existing Daybreak source and app code are unchanged.
- Hosting only: no new USBKeys app behavior or hardware compatibility is claimed. USB HID operation, Sileo installation, and iPhone 17 Recovery Assistant support remain unverified on physical devices.

## [tweak-v0.2.14] - 2026-11-12

## Verified changes since tweak-v0.2.13

- feat(daybreak): one-shot sleepd cloud/sync structure dump to oslog (0.2.14) ([`7de3dc90`](https://github.com/soum91/daybreak/commit/7de3dc90a52f74769791d111baab751fb08cc3e8); `tweak/DBSleepDaemonProbe.xm`, `tweak/RELEASE_NOTES.md`, `tweak/app/Resources/Info.plist`, and 2 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.13...tweak-v0.2.14)

## Daybreak Dopamine tweak 0.2.14 (2026-11-12)

- `tweak/DBSleepDaemonProbe.xm`: on its first report after sleepd starts, the probe writes a one-time, read-only list to the system log (prefix `[DaybreakDump]`): Objective-C class names containing cloud/sync from the sleepd, Sleep and HealthKit images, plus cloud/sync-named properties (value class or YES/NO) on the daemon, its environment, sleep storage, synced defaults and behavior objects. No schedule contents are logged and nothing is changed.
- Why: with 0.2.13 the `sleepCloudKitSync` override reads ON inside sleepd, but on-device `oslog` showed no Sleep CloudKit activity at all after a schedule change. The dump is meant to identify which object or gate actually starts Sleep sync on iOS 16.1.1.
- Limitations: diagnostic only; unverified on device. No sync behavior changed from 0.2.13.

## [tweak-v0.2.13] - 2026-11-11

## Verified changes since tweak-v0.2.12

- fix(daybreak): live sleepd status refresh and override pref fallback (0.2.13) ([`9346556c`](https://github.com/soum91/daybreak/commit/9346556c67e7787590024e3d9c66ec85e9544908); `tweak/DBSleepDaemonProbe.xm`, `tweak/RELEASE_NOTES.md`, `tweak/Tweak.m`, and 4 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.12...tweak-v0.2.13)

## [tweak-v0.2.12] - 2026-11-11

## Verified changes since tweak-v0.2.11

- feat(daybreak): add opt-in reversible sleepd cloud feature override ([`c5ad503d`](https://github.com/soum91/daybreak/commit/c5ad503dfc9169bf71d84e9e566ac5c266123121); `tweak/DBSleepDaemonProbe.xm`, `tweak/Makefile`, `tweak/RELEASE_NOTES.md`, and 6 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.11...tweak-v0.2.12)

## Daybreak Dopamine tweak 0.2.13 (2026-11-11)

- `tweak/DBSleepDaemonProbe.xm`: sleepd now re-reports its state at 8 s, 45 s and 180 s after start and whenever it receives `com.soum91.daybreak.daemonprobe.request`. Previously it reported once at 8 s; after a userspace reboot sleepd starts before SpringBoard subscribes, so that single Darwin notification was lost and the override result never appeared.
- `tweak/DBSleepDaemonProbe.xm`: if cfprefsd refuses the Daybreak domain inside sandboxed sleepd, the override switch is read directly from the preferences plist. If neither source is readable the daemon reports `unreadable` instead of silently behaving as OFF.
- `tweak/Tweak.m`: SpringBoard discards `sleepDaemon*` status fields left from a previous boot and requests a fresh daemon report on launch.
- `tweak/app/main.m`: Refresh status asks sleepd for a live report and reloads after 1.5 s. When sleepd is idle (launch-on-demand) the screen says so instead of showing old values.
- Limitations: unverified on device. The cloud override itself is unchanged from 0.2.12; whether iOS 16 sleepd can sync Sleep schedules with iOS 27 devices is still unknown.

## Daybreak Dopamine tweak 0.2.12 (2026-11-11)

- Added a disabled-by-default, reversible `experimentalSleepCloudSync` control in the Daybreak app and Settings bundle. A Dopamine userspace reboot activates or deactivates it.
- The existing `sleepd` probe now conditionally overrides only `_HKFeatureFlags.sleepCloudKitSync` at runtime, capturing the original getter value and displaying original vs. effective flags and configured vs. loaded override status. No explicit CloudKit sync call is made.
- Preserved the working native one-night Sleep writer and hourly planner. Apple Health and daemon cloud preferences are not changed; the operating system may initiate cloud operations when the experimental feature is enabled.
- Limitations: This could affect iCloud Sleep schedules. Sleep cross-iPhone / Watch delivery, effective cloud upload, and iOS 16 private API behavior are unverified. Disabling and userspace-rebooting rolls back the code override, not any data already synced.

## [tweak-v0.2.11] - 2026-11-11

## Verified changes since tweak-v0.2.10

- feat(daybreak): inspect live sleepd cloud sync gates without mutation ([`f9a7f453`](https://github.com/soum91/daybreak/commit/f9a7f453c831fe50ac1fd1776480abe6cc26e12a); `.github/workflows/tweak.yml`, `tweak/DBSleepDaemonProbe.xm`, `tweak/DaybreakSleepDaemonProbe.plist`, and 7 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.10...tweak-v0.2.11)

## [tweak-v0.2.10] - 2026-11-11

## Verified changes since tweak-v0.2.9

- feat(daybreak): add read-only iOS 16 native Sleep cloud sync eligibility diagnostics (0.2.10) ([`5a09cd2d`](https://github.com/soum91/daybreak/commit/5a09cd2d40d48b6c0e831db32e7358b8fa5da620); `tweak/DBNativeSleep.m`, `tweak/RELEASE_NOTES.md`, `tweak/Tweak.m`, and 4 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.9...tweak-v0.2.10)

## [tweak-v0.2.9] - 2026-11-10

## Verified changes since tweak-v0.2.8

- feat(daybreak): hourly native Sleep checks and status notifications (0.2.9) ([`e4d2c198`](https://github.com/soum91/daybreak/commit/e4d2c1984224da06681b07575be6858c9852dcf5); `tweak/Makefile`, `tweak/README.md`, `tweak/RELEASE_NOTES.md`, and 8 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.8...tweak-v0.2.9)

## [tweak-v0.2.8] - 2026-11-10

## Verified changes since tweak-v0.2.7

- fix(daybreak): remove obsolete MobileTimer helpers blocking tweak build ([`18747d0f`](https://github.com/soum91/daybreak/commit/18747d0f4972c7dc16365d15695c0dbb6f0b7288); `tweak/Tweak.m`)
- feat(daybreak): automate native Sleep schedule requests daily (0.2.8) ([`76692b78`](https://github.com/soum91/daybreak/commit/76692b78b01d2fc66ed3920353dd2cc19330efb8); `tweak/Makefile`, `tweak/README.md`, `tweak/RELEASE_NOTES.md`, and 7 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.7...tweak-v0.2.8)

## [tweak-v0.2.7] - 2026-11-10

## Verified changes since tweak-v0.2.6

- fix(daybreak): correct Sileo metadata and decouple Sleep readback (0.2.7) ([`2c56fbe6`](https://github.com/soum91/daybreak/commit/2c56fbe63ce11295e0c617b6259378637ed55454); `tweak/DBNativeSleep.m`, `tweak/README.md`, `tweak/RELEASE_NOTES.md`, and 4 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.6...tweak-v0.2.7)

## [tweak-v0.2.6] - 2026-11-10

## Verified changes since tweak-v0.2.5

- feat(daybreak): guarded native Health Sleep single-day override trial (0.2.6) ([`5ed13c2c`](https://github.com/soum91/daybreak/commit/5ed13c2cf4d1d73da54574ab723c738de5792023); `tweak/DBHealthProbe.m`, `tweak/DBNativeSleep.h`, `tweak/DBNativeSleep.m`, and 10 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.5...tweak-v0.2.6)

## [tweak-v0.2.5] - 2026-11-10

## Verified changes since tweak-v0.2.4

- Fix Daybreak diagnostic clipboard read-back and avoid unwritable temporary export ([`a524b249`](https://github.com/soum91/daybreak/commit/a524b249269d8ebf6e0415cf485b204be3bcc110); `.github/workflows/tweak.yml`, `tweak/DBDiagnosticExport.h`, `tweak/README.md`, and 6 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.4...tweak-v0.2.5)

## [tweak-v0.2.4] - 2026-11-10

## Verified changes since tweak-v0.2.3

- Add read-only Apple Health Sleep schedule probe and disable unsynced local writes ([`fedc1178`](https://github.com/soum91/daybreak/commit/fedc11785e3722043652d93f648a77f96c817529); `.github/workflows/tweak.yml`, `tweak/DBHealthProbe.m`, `tweak/DaybreakHealthProbe.plist`, and 9 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.3...tweak-v0.2.4)

## Daybreak Dopamine tweak 0.2.11 (2026-11-11)

- Added `DBSleepDaemonProbe.xm` and a `sleepd`-only injection filter. Observes the live daemon's `sleepCloudKitSync` feature and its distinct `HDSPSyncedDefaults.syncDisabled` preference, plus pending initial/pull sync flags, without modifying any of them.
- Added `sleepDaemon*` fixed-code handling in SpringBoard and clear daemon status fields in Daybreak's selectable report. An unobserved daemon remains explicitly unverified.
- Updated package checks to require the daemon probe dylib and filter. The working next-only native Sleep writer, hourly automation, and notifications are unchanged.
- Limitation: iPhone 17 / paired Apple Watch receipt is still unverified; this release does not enable cloud synchronization or force the daemon to restart. Source commit to be recorded upon publication.

## Daybreak Dopamine tweak 0.2.10 (2026-11-10)

- Added two read-only Health-process diagnostics to `DBNativeSleep.m`: the installed iOS 16 `sleepCloudKitSync` feature flag, and whether the one-night Sleep override appears in the installed Sleep daemon's `allKeysToSync` configuration.
- Updated SpringBoard's diagnostic notifications to store these results separately from native Sleep save/read-back outcomes. The Daybreak app now prints the two cloud fields and their last-check time in the full selectable report.
- Kept the successful native one-night writer and hourly planner unchanged. This release cannot claim that iCloud or the iPhone 17 / paired Apple Watch receives a Sleep override; it only checks eligibility on the iPhone 13.


## Daybreak Dopamine tweak 0.2.9 (2026-11-10)

- Changed the SpringBoard scheduler from one evening attempt per morning to an hourly calendar recheck, defaulting to 12 PM through 11 PM. Persisted hourly slots suppress duplicate retries within an hour, but a failed attempt does not block the next hourly check.
- Added optional local status notifications for successful native Sleep read-back and actionable native/Calendar failures. Kept no-change hours silent; notification delivery from SpringBoard has not been physically verified.
- Added editable hourly start/end hours and a notifications switch to Daybreak's Home Screen app and Settings pane, with one-time notification authorization in the app.
- The user confirmed one manual native Sleep override changed the iPhone 13's next wake time on iOS 16.1.1. The iPhone 17 still displayed its previous wake time. This build does not claim cross-device synchronization or Watch alarm delivery.

## Daybreak Dopamine tweak 0.2.8 (2026-11-10)

- Enabled native Sleep automation in `tweak/Tweak.m`: SpringBoard no longer disables `automaticEnabled` on launch or rejects scheduled writes before planning. It now attempts one calendar-driven native Sleep override every evening (18:00 default), retaining the no-repeat-per-morning guard.
- Compiled the existing guarded native Sleep writer into the SpringBoard tweak in addition to the Health-only helper. Automatic requests are sent directly to the private Sleep service from SpringBoard, while Health can process an unconsumed request on foreground.
- Enabled the automatic switch in Daybreak's Home Screen app and Settings and added a **Run automation now** action. Updated package description and installed metadata to 0.2.8 (9).
- **Not yet physically verified:** Calendar authorization in SpringBoard, background Sleep XPC write authorization, cross-iPhone or Watch propagation, and Watch-only wake delivery. An unsuccessful native write does not create a fallback ordinary alarm.

## Daybreak Dopamine tweak 0.2.7 (2026-11-10)

- Corrected `tweak/control`'s package description so Sileo no longer says Sleep schedule writes are disabled. It now describes the experimental, explicit one-time native Health override and makes the unverified sync limitation clear.
- Moved `HKSPSleepStore` read-back onto a separate background queue after the asynchronous save callback, preventing synchronous Sleep XPC calls from re-entering their own completion queue.
- Added `native_request_missing` result code for an unavailable shared one-time request. Updated package and both visible installed targets to 0.2.7 (8). Actual on-device write and Watch delivery remain to be verified.

## Daybreak Dopamine tweak 0.2.6 (2026-11-10)

- Implemented a guarded, one-time native Sleep schedule override in `tweak/DBNativeSleep.m`, injected only into Apple's Health app. This uses the system `HKSPSleepStore` path, not ordinary alarms, AlarmKit, or direct Health database writes.
- Added a ten-minute, single-use calendar plan handoff from the Daybreak Home Screen app. Health verifies the requested morning, existing enabled alarm, one-day override and unchanged repeating weekdays before submitting a save, then queries native Sleep for a local read-back.
- Extended the SpringBoard diagnostic bridge for explicit native status codes and retired the Settings button's old local-only Apply behavior. Automatic recurring changes remain disabled.
- Bumped the installed Home Screen app, Settings bundle and package to 0.2.6 (7). The earlier `HEALTH_PROBE schedule_found` read test succeeded on the owner's iOS 16.1.1 device, but **this write path, cross-device propagation and Watch-only ringing remain unverified**.

## Daybreak Dopamine tweak 0.2.5 (2026-11-10)

- Fixed diagnostic export paths in `tweak/app/main.m` and `tweak/prefs/DBRootListController.m` using a shared `DBDiagnosticExport.h` helper.
- Copy now explicitly verifies full pasteboard read-back and retries using a UTF-8 pasteboard item. Failures show an actionable error instead of silently reporting success.
- Save to Files uses a unique file under the device's user cache rather than `NSTemporaryDirectory()` and verifies the saved bytes before launching the native Files picker. This targets the observed temporary-directory write problem.
- Updated package/app/Settings installed version to 0.2.5 (6). Real-device clipboard and Save to Files verification are pending. Health Sleep schedule writes and iPhone/Watch sync remain disabled and unverified.

## Daybreak Dopamine tweak 0.2.4 (2026-11-10)

- Added `tweak/DBHealthProbe.m` and a Health-app-only injection filter to check private iOS HealthKit `HKSleepSchedule` and `sleepScheduleType` support. The query reads at most one schedule sample and reports only fixed presence/error codes to SpringBoard, with no patient data and no database edits.
- Updated `tweak/Tweak.m` to record the Health probe outcome in exported diagnostics and disable the legacy MobileTimer override writer and unattended writes. This avoids incorrectly presenting per-device alarm mutation as iCloud-synchronized Sleep schedule control.
- Updated the Daybreak app and Settings messaging, package control, and visible installed version/build to 0.2.4 (5). Existing Sleep alarms are not modified by this update.
- Physical verification remains outstanding: whether the Health app loads the probe, whether its private schedule query succeeds, whether native schedule modification can be safely implemented, and whether schedule updates synchronize to the iPhone 17 and paired Watch. No such functionality is claimed in this build.

## [tweak-v0.2.3] - 2026-11-10

## Verified changes since tweak-v0.2.2

- fix: package rootless uicache postinst and publish Daybreak 0.2.3 ([`3301cd45`](https://github.com/soum91/daybreak/commit/3301cd459733cd36c6eb768558842778be4f946f); `.github/workflows/tweak.yml`, `tweak/README.md`, `tweak/RELEASE_NOTES.md`, and 5 more)
- Update Daybreak source to build 21 ([`975ab43e`](https://github.com/soum91/daybreak/commit/975ab43e9dd9d36bf21f905602384752ef6a43fb); `repo.json`)
- Purge outdated Daybreak Actions artifact with private author metadata ([`7bc7f44d`](https://github.com/soum91/daybreak/commit/7bc7f44dfdeb7bb87fb0e02d094e1cef5ba7fc08); `.github/workflows/privacy-cleanup.yml`)
- Remove superseded Daybreak package containing private attribution ([`f9656326`](https://github.com/soum91/daybreak/commit/f9656326545b267ce160aebf38a0367088c1c3d1); `.github/workflows/privacy-cleanup.yml`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.2...tweak-v0.2.3)

## [tweak-v0.2.2] - 2026-11-10

## Verified changes since tweak-v0.2.1

- test: cover companion version UI and add selectable full diagnostic ([`5750bfe5`](https://github.com/soum91/daybreak/commit/5750bfe5bcb58885d17927770a49163c781f6c6d); `tweak/RELEASE_NOTES.md`, `tweak/app/main.m`, `version-ui-contract.json`)
- Remove superseded Daybreak release with private package attribution ([`d8371669`](https://github.com/soum91/daybreak/commit/d83716697427b797698f5516b246893396d685b2); `.github/workflows/tweak.yml`)
- fix: restore Daybreak Settings controls and add native Home Screen app ([`092f076c`](https://github.com/soum91/daybreak/commit/092f076c5c90c1fa7ef6b60feebd6e8e3324e6e8); `.github/workflows/tweak.yml`, `tweak/Makefile`, `tweak/README.md`, and 10 more)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/tweak-v0.2.1...tweak-v0.2.2)

## [v0.1.21] - 2026-11-10

## Verified changes since v0.1.20

- test: cover companion version UI and add selectable full diagnostic ([`5750bfe5`](https://github.com/soum91/daybreak/commit/5750bfe5bcb58885d17927770a49163c781f6c6d); `tweak/RELEASE_NOTES.md`, `tweak/app/main.m`, `version-ui-contract.json`)
- Remove superseded Daybreak release with private package attribution ([`d8371669`](https://github.com/soum91/daybreak/commit/d83716697427b797698f5516b246893396d685b2); `.github/workflows/tweak.yml`)
- fix: restore Daybreak Settings controls and add native Home Screen app ([`092f076c`](https://github.com/soum91/daybreak/commit/092f076c5c90c1fa7ef6b60feebd6e8e3324e6e8); `.github/workflows/tweak.yml`, `tweak/Makefile`, `tweak/README.md`, and 10 more)
- Remove personal identity from Daybreak tweak and Sileo packages ([`f8c6256d`](https://github.com/soum91/daybreak/commit/f8c6256d3b4965aacdaa329ceac5a2668080fcf8); `scripts/build_sileo.py`, `sileo/Packages`, `sileo/Packages.bz2`, and 7 more)
- docs: make Dopamine tweak the primary Daybreak path ([`ca37c261`](https://github.com/soum91/daybreak/commit/ca37c261877cc5639b5cc766511e3f78c6e7a955); `README.md`)
- Update Daybreak source to build 20 ([`53818286`](https://github.com/soum91/daybreak/commit/538182866003e156b5dff705025b8048b7400cf3); `repo.json`)
- fix: dynamically resolve Settings Preferences host in rootless bundle ([`cae94861`](https://github.com/soum91/daybreak/commit/cae948618db1543d175c1977994f25b78c9682b3); `tweak/prefs/Makefile`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.20...v0.1.21)

## [tweak-v0.2.1] - 2026-11-10

## Verified changes since v0.1.20

- Remove personal identity from Daybreak tweak and Sileo packages ([`f8c6256d`](https://github.com/soum91/daybreak/commit/f8c6256d3b4965aacdaa329ceac5a2668080fcf8); `scripts/build_sileo.py`, `sileo/Packages`, `sileo/Packages.bz2`, and 7 more)
- docs: make Dopamine tweak the primary Daybreak path ([`ca37c261`](https://github.com/soum91/daybreak/commit/ca37c261877cc5639b5cc766511e3f78c6e7a955); `README.md`)
- Update Daybreak source to build 20 ([`53818286`](https://github.com/soum91/daybreak/commit/538182866003e156b5dff705025b8048b7400cf3); `repo.json`)
- fix: dynamically resolve Settings Preferences host in rootless bundle ([`cae94861`](https://github.com/soum91/daybreak/commit/cae948618db1543d175c1977994f25b78c9682b3); `tweak/prefs/Makefile`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.20...tweak-v0.2.1)

## 0.1.21

Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.

Source commit: https://github.com/soum91/daybreak/commit/5750bfe5bcb58885d17927770a49163c781f6c6d

## Daybreak Dopamine tweak 0.2.3 (2026-11-10)

- Fixed the blank Settings preference controller by inheriting and populating
  the actual `PSListController` specifier storage. The former declaration
  shadowed that storage, leaving the preference table empty.
- Added a native Home Screen app within the existing rootless package, alongside
  Settings → Daybreak. The app offers Calendar access and selection, wake preview,
  adjustable preparation/fallback/evening settings, manual Apply, installed
  version/build, and diagnostic Copy/Share/Save to Files with full selectable text.
- Added a short-lived one-time calendar-plan handoff from the app to the
  SpringBoard engine for manual updates, preserving the next-only Sleep override
  safety checks and requiring fresh alarm read-back.
- Updated tweak CI to generate Home Screen icons and verify that the `.deb`
  includes the app and preference bundle, as well as the `postinst` rootless
  icon registration script from `layout/DEBIAN`. A 0.2.2 build revealed that
  keeping that script in the project root did not include it in the `.deb`.
  Device behavior awaits testing.

## [v0.1.20] - 2026-11-10

## Verified changes since v0.1.19

- feat: add Daybreak iOS 16 Dopamine tweak and Sileo build pipeline ([`1f5aaeaa`](https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37); `.github/workflows/build.yml`, `.github/workflows/tweak.yml`, `scripts/build_sileo.py`, and 16 more)
- Update Daybreak source to build 19 ([`d04172fb`](https://github.com/soum91/daybreak/commit/d04172fb99383d66892c39413c59799b83d09bb9); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.19...v0.1.20)

## [tweak-v0.2.0] - 2026-11-10

## Verified changes since v0.1.19

- fix: dynamically resolve Settings Preferences host in rootless bundle ([`cae94861`](https://github.com/soum91/daybreak/commit/cae948618db1543d175c1977994f25b78c9682b3); `tweak/prefs/Makefile`)
- feat: add Daybreak iOS 16 Dopamine tweak and Sileo build pipeline ([`1f5aaeaa`](https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37); `.github/workflows/build.yml`, `.github/workflows/tweak.yml`, `scripts/build_sileo.py`, and 16 more)
- Update Daybreak source to build 19 ([`d04172fb`](https://github.com/soum91/daybreak/commit/d04172fb99383d66892c39413c59799b83d09bb9); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.19...tweak-v0.2.0)

## 0.1.20

Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.

Source commit: https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37

## [v0.1.19] - 2026-11-10

## Verified changes since v0.1.18

- Continue Clock discovery beyond preferences and remember identified storage ([`1ed16f96`](https://github.com/soum91/daybreak/commit/1ed16f964a7ee54069c14cede6fdf4180ef5f5b9); `App/ClockAccess.m`, `App/main.m`, `release-notes/current.md`, and 1 more)
- Update Daybreak source to build 18 ([`3c80198c`](https://github.com/soum91/daybreak/commit/3c80198c25f40a157173252c63256379a23a88cb); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.18...v0.1.19)

## 0.1.19

Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.

Source commit: https://github.com/soum91/daybreak/commit/1ed16f964a7ee54069c14cede6fdf4180ef5f5b9

## [v0.1.18] - 2026-11-10

## Verified changes since v0.1.17

- Continue Clock scan ranges automatically ([`5d9db671`](https://github.com/soum91/daybreak/commit/5d9db6713c00ab787ea0bfb5e1c27898c41463e1); `.github/workflows/build.yml`, `App/ClockAccess.h`, `App/ClockAccess.m`, and 3 more)
- Pin Daybreak feed downloads to verified v0.1.17 assets ([`bd43e19e`](https://github.com/soum91/daybreak/commit/bd43e19e712d6ce4ab2a16cc258a05d0fa301183); `repo.json`)
- Update Daybreak source to build 17 ([`6f434271`](https://github.com/soum91/daybreak/commit/6f4342710c14d3e5015c158038038633de053723); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.17...v0.1.18)

## 0.1.18

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

The Clock scan now continues through saved inode ranges automatically after one tap instead of requiring a tap for every roughly 25-second range. It reports each range, preserves the cursor so an interrupted scan can resume, keeps the screen awake while it runs, and stops when it finds a matching Clock container or reaches the end of the inode range. Keep Daybreak open during the scan; iOS may suspend it if the user switches apps or locks the phone.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. Automatic range chaining and the direct SystemGroup check need physical-device verification; previous reports verify only the earlier build's access to Clock's app container and do not establish that the complete scan will find the live alarm store.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md

Source commit: https://github.com/soum91/daybreak/commit/5d9db6713c00ab787ea0bfb5e1c27898c41463e1

## [v0.1.17] - 2026-11-10

## Verified changes since v0.1.15

- Allow hosted Simulator more time to finish app installation ([`5d7df606`](https://github.com/soum91/daybreak/commit/5d7df606a281fccb0484e3af18c79f5a666fcac1); `release-notes/current.md`, `scripts/smoke.py`)
- Probe MobileTimer SystemGroup directly before inode scan ([`0d9f02fa`](https://github.com/soum91/daybreak/commit/0d9f02fabded7815fd29328a222c9df591d7494b); `App/ClockAccess.m`, `README.md`, `release-notes/current.md`, and 1 more)
- Update Daybreak source to build 15 ([`303ffbac`](https://github.com/soum91/daybreak/commit/303ffbacc886e3e795ccaa01763352459ec1befc); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.15...v0.1.17)

## 0.1.17

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. The direct SystemGroup check and diagnostic exports need physical-device verification; the earlier report verifies only the previous build's access to Clock's app container.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md

Source commit: https://github.com/soum91/daybreak/commit/5d7df606a281fccb0484e3af18c79f5a666fcac1

## [v0.1.15] - 2026-11-10

## Verified changes since v0.1.12

- Prevent release metadata updates from triggering another build ([`a57b7c19`](https://github.com/soum91/daybreak/commit/a57b7c196aa18873c8cce8190093f4e561fe6022); `.github/workflows/build.yml`)
- Add worse_query Clock storage experiment without XCTest ([`276f1e53`](https://github.com/soum91/daybreak/commit/276f1e533d57e8266b8675935ff30ddd75d91531); `.github/workflows/build.yml`, `App/ClockAccess.h`, `App/ClockAccess.m`, and 11 more)
- Enforce visible installed version/build across app releases ([`9146e933`](https://github.com/soum91/daybreak/commit/9146e933ec6043caf196e85c726d554d5f72ca2f); `.github/workflows/build.yml`, `.github/workflows/version-ui.yml`, `scripts/check_version_ui.py`, and 1 more)
- Update Daybreak source to build 12 ([`b6dc3cb1`](https://github.com/soum91/daybreak/commit/b6dc3cb1ba8653e58218f4237a0ecee74a261f13); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.12...v0.1.15)

## Unreleased

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. The direct SystemGroup check and diagnostic exports need physical-device verification; the earlier report verifies only the previous build's access to Clock's app container.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md


## Unreleased

Added a Clock filesystem access experiment using worse_query. This is a read-only investigation of a possible replacement for XCTest, not a working replacement for changing alarms.

- Added **Test Clock filesystem access** in Daybreak. It checks the actual signed App Group, searches container metadata for Clock, and reports matching preference keys and immutable SQLite base-file table names. Alarm values and database rows are omitted. The scan is partial when its work budget expires; another tap resumes inode discovery.
- Preserves and restores the App Group Caches directory, including recovery after an interrupted swap. Sandbox extensions are released after inspection. No Clock files are written and no XCTest/Siri session is started by this test.
- Added selectable diagnostics, Copy with clipboard read-back and a visible result, native Share, and native Save to Files. Runner session credentials are redacted from the displayed/exported report.
- Added the App Group signing entitlement and upstream GPL license/attribution. The signer must supply a matching, accessible App Group in the provisioning profile; the app checks the actual entitlement after signing.

Existing calendar planning and the separate Siri/XCTest runner remain available. Clock-service access, changing a live Sleep alarm through filesystem access, daemon reload, and unattended/locked-screen operation are **not implemented or verified** by this experiment. SQLite inspection excludes WAL contents and reports base-file schema only.

Validation: release CI compiles device and simulator targets, enforces installed-version metadata, and runs the existing planner/launch inspection. The exploit is disabled in Simulator. Filesystem access and Copy/paste, Share, and Files export require signed physical-device verification and have not been verified by the developer on a phone.

Source baseline: https://github.com/soum91/daybreak/commit/9191ec10e594bda9cfafb5618d1e45f65f98dbf8


This log records verified, release-specific changes. The [Factual release changelog](.github/workflows/release-changelog.yml) GitHub Action adds entries based on the actual commits between published releases. Entries are not fabricated for older versions that have not been audited.


# Daybreak Dopamine 0.2.0 (tweak preview; device verification pending)

- Introduced the rootless iOS 16 SpringBoard/PreferenceLoader tweak under `tweak/` for the iPhone 13 Pro Max with Dopamine, leaving the iOS 17+ app and Runner intact.
- Ported tomorrow's earliest timed event before noon, preparation minutes and 08:30 fallback into `tweak/DBPlanner.m`; added deterministic planner tests in `tests/DaybreakTweakPlannerTests.m`.
- Added guarded MobileTimer next-only Sleep override updates and fresh read-back verification in `tweak/Tweak.m`. An absent or ambiguous next-only override is rejected; no recurring Sleep schedule or regular alarm is changed.
- Added Settings controls for manual preview/apply, evening automation, calendar selection and diagnostic export in `tweak/prefs/`.
- Added `.github/workflows/tweak.yml` and `scripts/build_sileo.py` to compile a real rootless `.deb` and publish its matching Sileo flat APT index under `sileo/` only after build checks pass.
- **Limitation:** Not yet verified on an iOS 16.1.1 Dopamine device. EventKit access, MobileTimer write authorization, next-only override persistence and Sileo installation require a real-device check. Automatic mode is off by default.

