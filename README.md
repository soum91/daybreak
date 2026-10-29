# Daybreak

Calendar-based wake planning for the actual Clock → Sleep | Wake Up alarm, using an on-device XCTest Siri runner.

## Current behavior

- Choose one calendar or all calendars. Read tomorrow's timed events starting before noon, skip all-day/cancelled/declined events, and subtract 0–720 preparation minutes from the earliest event.
- With no morning event, use a saved fallback (default 08:30). Preview always shows the date and time, then Apply recalculates before confirmation.
- A separate button asks Siri to enable the next Sleep alarm. That enable command needs device verification.
- Repeated requests are rejected while queued, executing, cooling down for 60 seconds, or awaiting reset after an activation exception. No automatic Siri retry or app switch interrupts the dialog.
- The older unsupported direct-access and Add Voice Shortcut controls are removed from the main screen. Their research implementation remains in the repository.

A device report demonstrates that the runner reaches Siri and receives a Sleep | Wake Up confirmation. Other reports show ambiguous alarm dialogs and XCTest interruptions. Daybreak does not claim an alarm changed merely because Siri activation returned. Check the actual Sleep entry in Clock, dismiss Siri, and clear the previous request before a manual retry. Bedtime and Sleep Focus are unchanged.

## Install

Download both IPAs from the latest release. Sign Daybreak normally. **DaybreakRunner requires development signing**, including its nested .xctest bundle; a distribution certificate is insufficient. A free Apple ID can provide development signing. Mount the developer image with your existing on-device developer tool, start Runner, approve UI Automation, and return to Daybreak. No computer is required during operation.

See [Runner/README.md](Runner/README.md) for detailed requirements.

## Daily evening trigger

In Daybreak, allow Calendar access and configure preparation time, calendar and fallback. Enable **Allow daily calendar URL to apply without asking**. Then create a Time of Day personal automation in Shortcuts, choose an evening time and Run Immediately, and add **Open URLs** with:

```
daybreak://calendar-run
```

This is Daybreak's own URL handler; it does not depend on saving Apple's internal Sleep intent as a shortcut. The runner must already be active. Opening the app or invoking Siri may require unlocking. Locked-screen execution is unverified. There is no guarantee that iOS will keep the runner alive overnight.

The URL calculates tomorrow's plan on each invocation, makes at most one automatic attempt per target morning, and skips before-noon invocations, past wake times, and wake times crossing into the previous date. A failed handoff still counts as an attempt; manually Apply after checking Clock to retry. Calendar data stays on the phone and no calendar event is modified.

## Builds

Every main push builds both IPAs, launches the host in Simulator, checks planner arithmetic, and tests the local runner handoff, session rejection, busy rejection and duplicate rejection without invoking Siri. GitHub releases and repo.json update only after checks pass. Re-sign release IPAs before installation. Both apps should use the same release version.

Minimum iOS version is 17. The target phone runs iOS 27. Simulator checks do not prove real-device alarm changes or locked-screen execution.

## Research sources

- Observed interfaces: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/Frameworks/Intents.framework/INUpdateAlarmIntent.h
- Exact-target model: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/Frameworks/Intents.framework/INAlarm.h
- Single-time override manager: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/MobileTimer.framework/MTAlarmManager.h
- Observed asynchronous callbacks: https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/NetAppsUtilities.framework/NAFuture.h
- Historic Siri donation inspected during research: https://www.icloud.com/shortcuts/54661787f1584383bf2c369507222382 (contains `MTUpdateAlarmIntent` with only `alarmID`, no time parameter).
