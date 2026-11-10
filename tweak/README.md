# Daybreak Dopamine tweak

Source for an **iPhone 13 Pro Max / iOS 16.1.1 / Dopamine rootless** package.
The original iOS 17+ app and Runner remain under `App/` and `Runner/` for history.
This tweak has no dependency on the Daybreak app, Siri, XCTest, a development image,
a Windows host, or a separate companion application.

## Plan and scope

1. Inject a small engine into the already-running SpringBoard process, where
   a timer fires after the configured evening hour (18:00 by default). No
   LaunchDaemon, hooks in sleepd or injected code in mobiletimerd.
2. Use EventKit to select tomorrow's earliest non-all-day, non-cancelled,
   non-declined event before noon, from one selected calendar or all calendars.
   Subtract 0–720 minutes of preparation time. With no qualifying event use 08:30.
3. Refuse wake times crossing back into today, expired wake times, and attempts
   before noon. Automatic mode attempts at most once per target morning.
4. Read MobileTimer's `sleepAlarms` asynchronous API. Require exactly one future
   alarm on the correct date with `isSleepAlarm`, `repeatSchedule == 0` and a
   nonempty overridden-date marker. Refuse base schedules and ordinary alarms.
5. Set only the override's hour/minute, optionally enable it, and submit
   `updateAlarm:`. Check the callback **and freshly query the same Sleep alarm ID**.
   Never claim a verified change based on a callback alone. Even when read-back
   matches, the first test needs visual confirmation in Clock.
6. Configure through Settings → Daybreak (PreferenceLoader); export full
   diagnostics with verified Copy, Share, or native Save to Files.

This is a **device-verification preview**. iOS 16.1.1 SpringBoard EventKit access,
the async MobileTimer update permission, and propagation to Health's next-only
Sleep override are not yet verified on the test device. The tweak fails closed if
an interface or permission is absent. It does not manufacture a regular alarm,
patch the Clock database, alter the underlying recurring Sleep schedule, or claim
that an update worked without reading it back. Automatic operation is OFF by default.

If SpringBoard cannot read calendars, or if MobileTimer only returns a base
schedule, diagnostics will say so. Those require an iOS 16 device-specific hook
before unattended Sleep editing can be considered operational.

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
2. Open Settings → Daybreak. Verify the installed version/build at the top.
   Leave **Automatic evening update** off.
3. Tap **Preview tomorrow**, wait several seconds, then **Show / export diagnostic**.
   Check `PREVIEW` or an actionable `CALENDAR_DENIED` status.
4. In Clock → Sleep | Wake Up, manually create a **next alarm only** override for
   tomorrow, preserving your recurring Health sleep schedule.
5. After noon, tap **Apply once now**; re-open diagnostics. Success requires
   `READBACK_MATCH` and the exact next Sleep time in Clock. `TARGET_UNAVAILABLE`
   or `READBACK_MISMATCH` means the feature is not yet working on this device.
6. Only after that real-device test, turn on the automatic evening update and
   set preparation minutes, fallback time, and evening hour.

The log is stored on-device at
`/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log`, with a readable
status plist alongside it. No event titles or calendar contents are uploaded.

## Safety / rollback

Turn off automatic operation in Settings, or uninstall the tweak in Sileo.
It does not replace the base sleep schedule. If a runtime interface changes or
an update cannot be checked, the engine stops without retry loops. An uninstall
does not undo a Sleep override already accepted by iOS; use Clock's next-alarm
editor to restore that specific time.
