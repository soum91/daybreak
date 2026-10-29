# Daybreak

An experimental iPhone diagnostic for the **actual Clock → Sleep | Wake Up alarm**.

## New: on-device Siri runner

The direct MobileTimer route was blocked by the iOS 27 sandbox. A separate **DaybreakRunner.ipa** now tests a different route: a genuine XCTest runner running on the iPhone itself, using Apple's Siri testing service. It uses a mounted developer image and development signing, which can be obtained with a free Apple ID. It does not require a computer during operation. The `.xctest` plug-in must also be signed correctly.

Install/setup instructions and the distinction between building, launching and actually changing an alarm are in [Runner/README.md](Runner/README.md). This remains an on-device test, not proven calendar automation. The legacy diagnostics below are retained for reference; they are not the recommended route on the device that reported a sandbox denial.

## Current build

This is a feasibility probe, not a finished automatic alarm app. Calendar reading, bedtime changes, Sleep Focus control and unattended scheduling are not implemented yet. Siri changing an alarm manually does not prove a third-party app can do it.

The app has two separate probes:

1. **Siri shortcut support:** inspect `INUpdateAlarmIntent`, discover its set-time operation from runtime enum names, target a real Sleep alarm, set `proposedTime`, then ask the standard Add Voice Shortcut UI whether it can save it. Construction, serialization and saving are logged separately. None is called successful execution. If reading the actual Sleep alarm is denied, this probe stops rather than inventing an identifier or matching all alarms.
2. **Direct MobileTimer update:** read the actual next future Sleep alarm and attempt a time/enabled update only if it is already a single-time override. A recurring/base schedule is never edited. Save the original snapshot first, await the asynchronous result with a timeout, then re-read through a new manager. A matching read-back still needs visual confirmation in Clock.

These observed private interfaces may be absent, changed, or permission-protected on iOS 27. A signing certificate does not automatically grant system entitlements. No restricted entitlements are fabricated. Failure and timeout details are the point of this first build.

## Install and test

Download `Daybreak.ipa` from the latest GitHub release and sign/install using FlareStore or EmberSign with your existing certificate. No certificate or Apple ID is stored in this repository.

1. Open Daybreak and tap **Inspect Sleep alarm access**.
2. Try **Test Siri shortcut support**. If an actual action can be saved, run it yourself and check that Clock's Sleep entry changes, rather than a separate regular alarm.
3. If a future next-only override was returned, select a future time on that alarm's date and use **Apply to next-only override**. If needed, establish an override once with Siri first, then inspect again.
4. Check Clock's visible Sleep | Wake Up entry. Use **Restore saved override** to restore the matching, still-future snapshot, or set the desired time in Clock/Siri.
5. Share the diagnostic report using the top-right share button. The log is also available through Files sharing. It records OS/interface/error and alarm timing details, but never reads calendar events, credentials or pairing records.

The first probe will not request a change on launch. No regular alarm is created as a hidden fallback. An error-free callback alone is not presented as success.

## Builds and downloads

Every main push builds a device IPA on a macOS GitHub runner, validates its structure, compiles a Simulator build and smoke-tests a read-only inspection. The release step runs only after these checks pass. The build is ad-hoc signed as a packaging aid; it **must be re-signed** to install on an iPhone. Release versions and build numbers increase with `GITHUB_RUN_NUMBER`.

`repo.json` is a FlareStore/AltStore-style source feed. This repository is private, so its raw feed and release downloads require GitHub authentication; a sideloader without private GitHub authentication cannot fetch them anonymously. Browser download while signed in, followed by importing the IPA, is the supported first-build path. Repository visibility is not changed by the workflow.

For local builds on a Mac with Xcode command-line tools:

```sh
bash scripts/build.sh
bash scripts/build.sh simulator
python3 scripts/smoke.py
```

No third-party build dependencies are required. Minimum deployment target is iOS 17; the intended test device is iOS 27. Simulator success confirms launch/inspection behavior only, not permission to modify device alarms.

## Research sources

- Observed interfaces: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/Frameworks/Intents.framework/INUpdateAlarmIntent.h
- Exact-target model: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/Frameworks/Intents.framework/INAlarm.h
- Single-time override manager: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/MobileTimer.framework/MTAlarmManager.h
- Observed asynchronous callbacks: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/NetAppsUtilities.framework/NAFuture.h
- Historic Siri donation inspected during research: https://www.icloud.com/shortcuts/54661787f1584383bf2c369507222382 (contains `MTUpdateAlarmIntent` with only `alarmID`, no time parameter).
