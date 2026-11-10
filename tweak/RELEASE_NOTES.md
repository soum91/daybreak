## Daybreak Dopamine 0.2.6 (experimental native Health Sleep override)

- The user's iOS 16.1.1 device reported `HEALTH_PROBE schedule_found`; this confirms the Health-app read-only `HKSleepSchedule` path was accessible.
- Added `DBNativeSleep.m` to the Health-app-only tweak. It dynamically loads Apple's private `Sleep.framework`, checks `HKSPSleepStore` and model selectors, and attempts a **one-time native Sleep override**, not an ordinary alarm or MobileTimer override.
- The Daybreak Home Screen app now offers an explicit Apply that sends a ten-minute calendar plan to Health. The Health writer checks the target morning, existing enabled Sleep alarm, override validity, and preservation of every repeating weekday before saving. A successful callback is followed by a native read-back.
- Health reports fixed native status codes to SpringBoard, and the Settings pane routes manual Apply to the Home Screen app. Unattended automatic schedule writes remain off.
- **Unverified on device:** whether iOS 16.1.1 exposes the expected native Sleep-store methods, accepts the write, and syncs to the iPhone 17 / Watch. No synchronized or Watch-only wake alarm is claimed until those tests pass.

## Earlier 0.2.5 changes (diagnostic Copy and export repair)

- Shared the diagnostic Copy and Save logic between the Home Screen app and Settings pane in `DBDiagnosticExport.h`.
- Copy now verifies the full clipboard content, tries a standard UTF-8 pasteboard item as a fallback, and gives a specific error when verification fails. Copy does **not** write to `/tmp`.
- Save to Files now writes and verifies a unique `.txt` file in the user cache, then opens the native Files exporter. This avoids relying on `NSTemporaryDirectory()`, which can resolve to an unwritable path in a jailbreak app or the Preferences host.
- Neither diagnostic path uploads health data. **Physical-device Copy, cross-app paste, and Files export still need verification.** The Health schedule probe remains read-only and the native write/Watch synchronization work remains pending.

## Earlier 0.2.4 changes (Apple Health schedule investigation)

- Added a separate **read-only HealthKit probe dylib** targeted at Apple's Health app on iOS 16.1.1. It checks for the private `HKSleepSchedule` class and `HKObjectType.sleepScheduleType`, then makes a one-sample read query and returns only fixed outcome codes. No schedule times, sleep data, calendar contents, or identifiers are exported.
- SpringBoard now records `healthProbe` / `healthProbeUpdated` in the Daybreak diagnostic. Open Apple Health, wait ten seconds, then use **Refresh status** in Daybreak. `schedule_found` indicates the Health process could read an `HKSleepSchedule` sample; it **does not** prove an editable schedule or iCloud synchronization.
- Disabled the previous MobileTimer next-only local override writer and automatic evening writes. That path could not establish that the iPhone 17 and paired Watch would share the same Sleep alarm. Existing Sleep schedules and alarms are left untouched by this update.
- Updated the Home Screen and Settings descriptions to differentiate verified device-local previewing from unverified native Health Sleep schedule editing. Installed version is 0.2.4 (5).

**Not yet working:** Automatically changing the native Sleep schedule, iCloud propagation to another iPhone, and the Watch's alarm. No device has been available to verify Health process injection, read-query authorization, or synchronization. The probe is a diagnostic for the next development step, not a claimed alarm fix.

## Earlier 0.2.3 changes (Home Screen app + Settings repair)

- Fixed the blank Settings pane by using the real `Preferences/PSListController.h`
  superclass and its inherited `_specifiers` list, not a shadowed property.
- Added a native **Daybreak Home Screen app** to the same rootless Sileo package,
  with wake-time preview, configuration, calendar selection, manual Apply,
  status refresh, and Copy/Share/native Save to Files diagnostics plus a
  selectable full-text fallback.
- Added a one-time, 60-second CFPreferences handoff for the app's authorized
  calendar plan to the SpringBoard tweak. The engine continues to require an
  exact next-only Sleep override and verified MobileTimer read-back.
- Added Home Screen icon generation and CI checks that the compiled `.deb`
  contains both the app executable and PreferenceLoader bundle. Corrected the
  Theos maintainer script location to `layout/DEBIAN/postinst`, so rootless
  `uicache` registration is actually included in the package; CI now checks it.
- Package author and maintainer metadata use only `soum91`, without a personal
  legal name.

- Added a Theos rootless `arm64/arm64e` SpringBoard tweak, separate from the original Daybreak and XCTest Runner app targets.
- Ported the earliest-before-noon calendar planner, preparation minutes, fallback wake time, and after-noon guard into a background engine.
- Added next-only Sleep override identification, `updateAlarm:` request, timeout/error handling, and a fresh alarm-ID/time read-back. The tweak rejects recurring Sleep schedules and ordinary alarms.
- Added a PreferenceLoader Settings screen for manual preview/apply, evening automation, fallback/preparation options, and verified Copy/Share/Files diagnostics.
- Added planner unit tests, macOS rootless package workflow, and a generated flat APT source for Sileo.

**Known limitations:** Calendar planning in the new app and rendering in Settings
need physical-device testing on iOS 16.1.1. MobileTimer write authorization,
next-only override availability and visible Clock propagation remain unverified.
No working alarm update is claimed until a real `READBACK_MATCH` and visible
Clock change. Unattended SpringBoard calendar access remains unverified and
automatic updates default to OFF. The Sileo index is unsigned and GitHub raw
redirects may need a Pages mirror for some clients.

See `tweak/README.md` for exact behavior, first-phone test and rollback.
