## Daybreak Dopamine 0.2.14 (sleepd sync structure dump)

- `tweak/DBSleepDaemonProbe.xm`: on its first report after sleepd starts, the probe writes a one-time, read-only list to the system log (prefix `[DaybreakDump]`): Objective-C class names containing cloud/sync from the sleepd, Sleep and HealthKit images, plus cloud/sync-named properties (value class or YES/NO) on the daemon, its environment, sleep storage, synced defaults and behavior objects. No schedule contents are logged and nothing is changed.
- Why: with 0.2.13 the `sleepCloudKitSync` override reads ON inside sleepd, but on-device `oslog` showed no Sleep CloudKit activity at all after a schedule change. The dump is meant to identify which object or gate actually starts Sleep sync on iOS 16.1.1.
- Limitations: diagnostic only; unverified on device. No sync behavior changed from 0.2.13.

## Daybreak Dopamine 0.2.13 (live sleepd status, override pref fallback)

- `tweak/DBSleepDaemonProbe.xm`: sleepd now re-reports its state at 8 s, 45 s and 180 s after start and whenever it receives `com.soum91.daybreak.daemonprobe.request`. Previously it reported once at 8 s; after a userspace reboot sleepd starts before SpringBoard subscribes, so that single Darwin notification was lost and the override result never appeared.
- `tweak/DBSleepDaemonProbe.xm`: if cfprefsd refuses the Daybreak domain inside sandboxed sleepd, the override switch is read directly from the preferences plist. If neither source is readable the daemon reports `unreadable` instead of silently behaving as OFF.
- `tweak/Tweak.m`: SpringBoard discards `sleepDaemon*` status fields left from a previous boot and requests a fresh daemon report on launch.
- `tweak/app/main.m`: Refresh status asks sleepd for a live report and reloads after 1.5 s. When sleepd is idle (launch-on-demand) the screen says so instead of showing old values.
- Limitations: unverified on device. The cloud override itself is unchanged from 0.2.12; whether iOS 16 sleepd can sync Sleep schedules with iOS 27 devices is still unknown.

## Daybreak Dopamine 0.2.12 (reversible experimental Sleep cloud feature)

- Added an **OFF by default** `experimentalSleepCloudSync` switch in the Home Screen app and Settings. An enabled switch takes effect after **Dopamine → Reboot Userspace** and can be reversed by switching OFF and rebooting userspace again; a full device reboot is not required.
- Limited the experiment to `sleepd`'s `_HKFeatureFlags.sleepCloudKitSync` getter. The untouched system return value is recorded before an enabled override returns `YES`; the daemon report shows original and effective values separately.
- Kept native one-day Sleep updates, hourly calendar automation, notifications, Apple Health injection, and the iPhone 13's existing repeating Sleep schedule unchanged. No force-sync or Health data mutation API was introduced; Apple's existing cloud code may start operating when the flag is enabled.
- **Experimental limitations:** Overriding a private feature may change or conflict with iCloud Sleep schedule state. iOS 16 CloudKit support, successful upload, cross-iPhone propagation, and Watch alarms are **unverified**. Keep a backup alarm. Disabling the override and restarting userspace restores the getter but does not automatically undo any cloud data changes already made during the experiment.

## Daybreak Dopamine 0.2.11 (read-only sleepd cloud gate diagnostics)

- Added a separate rootless dylib targeting only `sleepd`. After Apple's `HDSPSleepDaemon.start` completes, the probe reads the **existing** environment's `sleepCloudKitSync` feature flag and `HDSPSyncedDefaults.syncDisabled` cloud preference.
- Reports whether initial cloud sync and a cloud pull are marked pending. All results are fixed codes passed back to SpringBoard and displayed in the Daybreak app's selectable diagnostics. No sleep times or personal records leave the process.
- Explicitly reports **not observed** if sleepd hasn't started with the updated package. A respring by itself may not restart sleepd; avoid restarting the service near an expected wake alarm.
- **Limit:** A flag or pending status is not proof that an override uploaded to iCloud or reached the iPhone 17 or its paired Watch. The new probe does not toggle feature flags, force sync, change alarms, or alter the working native writer. Physical device behavior remains unverified.

## Daybreak Dopamine 0.2.10 (read-only Sleep cloud eligibility diagnostics)

- Added a Health-process read-only probe for the installed iOS 16 `_HKBehavior.features.sleepCloudKitSync` feature flag. Reports on, off, or unknown without changing it.
- Added a read-only inspection of `HDSPSleepStorage.standardConfiguration.allKeysToSync` to report whether the one-night override key is listed as eligible for cloud synchronization on the installed OS. Reports yes, no, or unknown on framework/API failure.
- Kept cloud results separate from native-write status and included them in the Home Screen app's selectable diagnostic report. The cloud probes do not alter alarms, force iCloud synchronization, or create ordinary alarms.
- **Limit:** eligibility and the Health process feature flag do not establish live iCloud upload, the Sleep daemon's individual cloud setting, or iPhone 17 / paired Watch receipt. Those remain unverified. Manual native Sleep writing remains unchanged.

## Daybreak Dopamine 0.2.9 (hourly Sleep recalculation and notifications)

- Replaced the one-attempt-per-morning schedule guard with one new calendar calculation per hour between configurable daytime hours (12 PM to 11 PM by default). The native writer avoids re-saving a wake time that already matches; failures can be retried next hour.
- Added optional local status notifications from the SpringBoard tweak when the native writer confirms a matching read-back, or when Calendar/native write failures need attention. The app asks for notification permission; SpringBoard notification delivery remains unverified on-device.
- Added Hourly start/end controls and a Notifications switch in the Home Screen app and Settings pane. Repeating weekly Sleep schedule remains protected, and no ordinary alarms are created.
- The user confirmed that manually applying a test event changed the iPhone 13's native next wake time. Its iPhone 17 counterpart still showed the old time. iCloud Health data synchronization is not evidence that next-only Sleep alarm overrides synchronize across iPhones. No Watch-only ringing is claimed.

## Daybreak Dopamine 0.2.8 (automatic native Sleep requests)

- Removed the legacy `automaticEnabled` reset and the early-return that blocked all scheduled native Sleep writes. Existing installs migrate once to automatic mode ON, but the user can switch it off afterward.
- SpringBoard now calculates tomorrow's calendar wake at the configured evening hour (18:00 default), passes a one-shot request to the native `HKSPSleepStore` writer, and records fixed success/failure status codes. It does not submit an ordinary alarm or call the former device-local MobileTimer update path.
- The Daybreak Home Screen app and Settings pane now expose an enabled **Automatic native Sleep schedule** switch. Added **Run automation now** to trigger the background plan immediately without manually using Preview/Apply.
- The Health-app writer remains available for processing a pending request if the direct SpringBoard Sleep-service call cannot access it.
- **Physical limitations unverified:** whether SpringBoard can access Calendar events and the private Sleep XPC service without user interaction, whether the native update persists on iOS 16.1.1, and whether iCloud propagates to the iPhone 17 / paired Watch. Watch-only ringing is not implemented or claimed.

## Daybreak Dopamine 0.2.7 (native Sleep trial, Sileo metadata correction)

- Corrected the Sileo package Description: it now accurately identifies the experimental one-time native Health Sleep writer rather than wrongly claiming the whole package is read-only.
- The Health-process writer now performs its synchronous read-back on a separate background queue after the native save callback to avoid callback-queue reentrancy or deadlock.
- Added an explicit `native_request_missing` diagnostic when Health cannot see the one-shot request. iPhone 17 / Watch synchronization and iOS 16 private API compatibility are still unverified.

## Earlier 0.2.6 changes (experimental native Health Sleep override)

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
