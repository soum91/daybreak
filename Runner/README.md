# On-device Siri runner experiment

The normal Daybreak app was denied access to `com.apple.MobileTimer.alarmserver` on the user's iOS 27 phone (sandbox lookup error 159). Building an `INUpdateAlarmIntent` did not make it executable; an independent iOS 18.5 Simulator construction test rejected it as an `INShortcut` because it had no valid parameter combinations.

This experiment uses a **real XCTest runner** and Apple's `XCUIDevice.shared.siriService.activate(voiceRecognitionText:)`. It does not use the blocked MobileTimer connection or an imported Siri donation. The on-device runner startup approach is informed by the Apache-2.0 OpenMinis/iCTRL project, pinned for research at `c1e4268859ba858d1579f7b846a56cb40641b7f6`. Daybreak's implementation is independently written and limited to a fixed Sleep-alarm command with explicit device approval. It exposes no remote-control actions.

## Requirements

- Developer Mode enabled.
- **Development signing**, including `get-task-allow`, for the runner. A free Apple ID can supply this. A distribution/enterprise signing profile cannot become a development profile just by adding an entitlement.
- The nested `PlugIns/DaybreakUITests.xctest` must also be signed, from the inside out, using a compatible identity. Its bundle ID must match the runner's installed ID. EmberSign's pinned Zsign engine (`c4ba9da4283031c07efa03bce42c4b8602d22e73`, `src/bundle.cpp`) explicitly enumerates `.xctest` bundles and signs deepest bundles first. Use **Provision with Apple Account** and **Prepare for JIT** (to validate the development profile and preserve debugger permission), and keep the bundle identifier unchanged. This source check is not a real-device signing test. The latest SideStore is another documented signing route.
- A compatible developer image already mounted on the phone, using the existing pairing file, LocalDevVPN and an on-device tool such as StikDebug/EmberSign. Mounting and the runner's signing remain separate requirements. Mount again after reboot.
- Accept the system's UI Automation/passcode prompt and the runner's Notifications prompt.

No computer is used by the runtime design. Initial signing/provisioning and image preparation still must succeed. This has not yet been verified on the user's iOS 27 hardware. Simulator tests verify API availability and request parsing only; they never activate Siri or change alarms.

## First test

1. Install the updated `Daybreak.ipa` normally.
2. Development-sign and install `DaybreakRunner.ipa`, including the nested test bundle.
3. Mount the developer image using the user's already configured on-device developer tool.
4. Tap Daybreak Runner once. Allow UI Automation and Notifications. It is expected to move into the background; look for its Ready notification.
5. In Daybreak, choose a test wake time and tap **Start on-device Siri runner test**.
6. Long-press the runner's notification and choose **Apply Sleep alarm test**.
7. Siri receives exactly `Change my next sleep alarm to H:MM AM/PM.` The runner then tries to open Clock using XCTest. Check **Sleep | Wake Up** yourself; a returned Siri API call is never called a verified change.
8. In Daybreak, tap **Read runner status / report**, then share the report.

The read-only status service binds to `127.0.0.1:8275`; it has no mutation endpoint and no LAN listener. URL requests are restricted to integer hour/minute values, bounded in number and de-duplicated within the process. Every request needs approval before Siri runs.

Calendar-based scheduling, automatic authorization and locked-screen execution are not implemented or demonstrated yet. First prove that this on-device test can launch and change the intended entry. No future alarm time is silently substituted if setup fails.

## Sources

- https://github.com/OpenMinis/iCTRL
- https://developer.apple.com/documentation/xcuiautomation/xcuisiriservice
- https://appium.github.io/appium-xcuitest-driver/latest/guides/run-preinstalled-wda/

## Confirmed host handoff

The main test button now confirms the selected time in Daybreak and sends a fixed, session-bound Sleep test to the runner over IPv4 loopback. It no longer depends on URL capture or notification actions. Start the runner first, return to Daybreak, then confirm Apply with Siri. Both apps must be updated together. The original URL/notification path remains available for diagnostics. A user report confirms runner startup and status access on iOS 27; Siri execution remains unverified. CI exercises the local handoff, duplicate rejection and invalid-session rejection without entering the Siri execution loop.
