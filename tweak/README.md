# Daybreak Dopamine tweak

Source for an **iPhone 13 Pro Max / iOS 16.1.1 / Dopamine rootless** package.
The original iOS 17+ app and Runner remain under `App/` and `Runner/` for history.
The Sileo package installs **both** a native Daybreak Home Screen control app and
a Settings → Daybreak pane. Neither needs Siri, XCTest, a development image,
or a Windows host. The existing iOS 17+ app remains a separate historical target.

**0.2.9 recalculates tomorrow's wake every hour during the configured daytime window.**
Device diagnostics on iPhone 13 confirmed `HEALTH_PROBE schedule_found` in
Apple Health on iOS 16.1.1. The writer uses the private `HKSPSleepStore`
service rather than Health database edits, ordinary alarms, AlarmKit, or the
previous local-only MobileTimer override. By default, SpringBoard checks
tomorrow's calendar at least once per hour from 12 PM through 11 PM, and attempts the native write automatically,
without asking the user to press Apply. It is not yet verified that the
private Sleep service allows SpringBoard writes on iOS 16.1.1 or that those
changes propagate to the iPhone 17 and paired Watch.

## Plan and scope

1. Inject an engine into SpringBoard for evening calendar calculation and
   native Sleep schedule requests. It loads the private Sleep framework
   dynamically and fails closed when its service is unavailable.
   No LaunchDaemon or mobiletimerd hooks.
2. Use EventKit to select tomorrow's earliest non-all-day, non-cancelled,
   non-declined event before noon, from one selected calendar or all calendars.
   Subtract 0–720 minutes of preparation time. With no qualifying event use 08:30.
3. Refuse wake times crossing back into today, expired wake times, and attempts
   before noon. Automatic mode attempts at most once per target morning.
4. In Apple's Health process, run the confirmed `HKSleepSchedule` read-only
   query and inspect availability of `HKSPSleepStore` and the Sleep schedule
   model. Report fixed status codes via Darwin notifications.
5. At most once every calendar hour during a configurable daytime window
   (12:00 to 23:59 by default), store a short-lived one-shot calendar wake
   request in local preferences. SpringBoard
   attempts the native writer immediately. Health can consume the pending
   request on foreground if the background process lacks Sleep service access.
   A separate explicit app Apply remains available;
   refuse expired dates, missing framework methods, wrong morning, disabled
   alarms, invalid occurrences, or changes to repeating weekday occurrences.
6. Send only the new native **single-day override** through
   `HKSPSleepStore.saveCurrentSleepSchedule:completion:` and check the
   resulting Health schedule. This is a private iOS 16 runtime compatibility
   experiment. A local read-back is not proof of iCloud or Watch sync.

The private HealthKit read-only query and the Health injection were confirmed
on the user's iPhone 13. The new **write path has not yet been physically
verified**. It fails closed if the iOS 16 private Sleep APIs do not match the
researched signatures. The writer does not manufacture an alarm or edit SQLite.

SpringBoard's EventKit access is still unverified for unattended automation.
If Calendar access is denied to SpringBoard, the diagnostic reports
`CALENDAR_DENIED` and this route cannot autonomously read events. The app's
manual calendar planning is available with the user's Calendar authorization.
Hourly automation is enabled by default in 0.2.9, but reliable execution and
separate iPhone 17 / Watch alarm delivery require device evidence.

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
2. Open the **Daybreak Home Screen app**. Verify **0.2.9 (10)** in the app or
   Settings. In particular, inspect that the installed tweak was updated.
3. In the app, grant Calendar access, choose the calendar and tap **Preview
   tomorrow**. The preview should show a calculated time and event count.
4. **Automatic native Sleep schedule** should be switched ON. The engine runs
   once per hour from the configured start hour to end hour (12 PM to 11 PM default). To run it immediately
   without waiting, tap **Run automation now**.
5. Tap **Refresh status** after a few seconds. The SpringBoard engine will
   attempt the private Sleep service itself. If native service access fails in
   the background, the Health-app hook can try the pending request when opened
   within ten minutes. If the status says
   `native_api_ready`, the runtime API was found, but no save is proven.
   `native_readback_match` means the local native Sleep schedule contains the
   requested time. Other `native_*` codes explain why it refused or could
   not verify a write. The original `schedule_found` remains a read-only result.
6. Only after a local `native_readback_match`, compare the actual Sleep |
   Wake Up time on the iPhone 17 and paired Watch, and verify only the desired
   device rings. **Do not rely on this experimental writer as your sole
   wake-up alarm until that full test passes.**
7. Export diagnostics with **Copy**, **Share**, or **Save to Files**. These
   paths were adjusted in 0.2.5 but still require physical retesting.

The log is stored on-device at
`/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log`, with a readable
status plist alongside it. No event titles or calendar contents are uploaded.

## Safety / rollback

Uninstall in Sileo to remove the Health hook and Daybreak UI. A successful
native one-time override is Apple-owned and remains in the Health/Clock Sleep
schedule after uninstall; undo it there if needed. The repeating weekly
schedule is intentionally untouched by the writer.
