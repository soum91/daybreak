# Daybreak Dopamine tweak

Source for an **iPhone 13 Pro Max / iOS 16.1.1 / Dopamine rootless** package.
The original iOS 17+ app and Runner remain under `App/` and `Runner/` for history.
The Sileo package installs **both** a native Daybreak Home Screen control app and
a Settings → Daybreak pane. Neither needs Siri, XCTest, a development image,
or a Windows host. The existing iOS 17+ app remains a separate historical target.

**0.2.4 is a read-only diagnostic update, not a working cross-device alarm
automation release.** The user requires the *native* Health Sleep schedule to
change on iPhone 13 and sync to the iPhone 17 and the Watch paired with that
iPhone. The old MobileTimer override operation affected only one phone and
cannot establish that requirement; it has been disabled to prevent conflicting
wake alarms. No ordinary alarms or AlarmKit alarms are created.

## Plan and scope

1. Inject a small engine into SpringBoard for calendar preview and diagnostics,
   with all schedule mutations disabled. No LaunchDaemon or mobiletimerd hooks.
2. Use EventKit to select tomorrow's earliest non-all-day, non-cancelled,
   non-declined event before noon, from one selected calendar or all calendars.
   Subtract 0–720 minutes of preparation time. With no qualifying event use 08:30.
3. Refuse wake times crossing back into today, expired wake times, and attempts
   before noon. Automatic mode attempts at most once per target morning.
4. Separately inject the read-only `DaybreakHealthProbe.dylib` into Apple's
   Health app. Resolve private HealthKit `HKSleepSchedule` and
   `HKObjectType.sleepScheduleType`, then query at most one sample. Transmit
   only fixed outcome codes through Darwin notification; no private Sleep
   values, database files or calendar contents leave the Health process.
5. Confirm from device diagnostics that the Health read path succeeds before
   developing an actual native schedule write, and separately test whether a
   **manual native Health schedule change** syncs to the second iPhone/Watch.
   The existence of a HealthKit sample is not proof that Apple syncs alarms.
6. Preview tomorrow's calendar-driven wake in the Daybreak app. The prior
   local-only MobileTimer mutation and automatic writes are disabled in
   0.2.4. Copy, Share, Save to Files and selectable diagnostics remain.

The Health probe is a **device-verification preview**. Query permissions, process
injection and iCloud schedule propagation have not been verified on the physical
device. All native schedule writes are intentionally disabled. The probe does
not manufacture an alarm, patch any database or alter existing Sleep schedules.

SpringBoard's EventKit access is unverified for future automation. The app's
manual calendar preview is available, but automatic edits must wait for a
verified native Health Sleep schedule write and a separate iCloud/Watch test.

## Build

Use a macOS Xcode toolchain with Theos and its rootless packaging prerequisites:

```sh
cd tweak
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The build workflow performs an actual `arm64/arm64e` compile and creates a
`iphoneos-arm64` `.deb`. It then generates matching `sileo/Packages`, `.gz`,
`.bz2`, `Release`, SHA256 and package bytes. No feed is generated without a .deb.

## First-phone test

1. Add `https://raw.githubusercontent.com/soum91/daybreak/main/sileo/` to Sileo
   and install **Daybreak (Dopamine)** after the build has published its index.
   Restart SpringBoard if Sileo does not automatically respring.
2. Open the **Daybreak Home Screen app**. Verify **0.2.4 (5)**. The Settings
   pane and app should both display that schedule writes are unavailable.
3. In the app, grant Calendar access, choose the calendar and tap **Preview
   tomorrow**. The preview should show a calculated time and event count.
4. Open **Apple Health** on the iPhone 13, wait ten seconds while the injected
   read-only probe runs, return to Daybreak, and tap **Refresh status**.
5. Export the diagnostic with **Copy**, **Share** or **Save to Files**. A result
   of `schedule_found` only means a private schedule sample was readable. A
   `query_error` or `query_empty` needs investigation and must not be treated
   as proof that the sleep schedule does not exist.
6. Keep native Sleep alarms unchanged until a safe update mechanism and actual
   iCloud/Watch propagation have been demonstrated.

The log is stored on-device at
`/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log`, with a readable
status plist alongside it. No event titles or calendar contents are uploaded.

## Safety / rollback

Uninstall in Sileo to remove the read-only Health probe and Daybreak UI.
The 0.2.4 package does not edit the base Sleep schedule or any other alarm.
Any overrides written by an *earlier* package remain Apple-owned and can be
reviewed in Clock or Health; uninstalling cannot undo those historic changes.
