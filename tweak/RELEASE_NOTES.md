## Daybreak Dopamine 0.2.2 (Home Screen app + Settings repair)

- Fixed the blank Settings pane by using the real `Preferences/PSListController.h`
  superclass and its inherited `_specifiers` list, not a shadowed property.
- Added a native **Daybreak Home Screen app** to the same rootless Sileo package,
  with wake-time preview, configuration, calendar selection, manual Apply,
  status refresh, and Copy/Share/native Save to Files diagnostics.
- Added a one-time, 60-second CFPreferences handoff for the app's authorized
  calendar plan to the SpringBoard tweak. The engine continues to require an
  exact next-only Sleep override and verified MobileTimer read-back.
- Added Home Screen icon generation and CI checks that the compiled `.deb`
  contains both the app executable and PreferenceLoader bundle.
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
