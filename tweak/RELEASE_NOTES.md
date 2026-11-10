## Daybreak Dopamine 0.2.0 (preview, physical test pending)

- Added a Theos rootless `arm64/arm64e` SpringBoard tweak, separate from the original Daybreak and XCTest Runner app targets.
- Ported the earliest-before-noon calendar planner, preparation minutes, fallback wake time, and after-noon guard into a background engine.
- Added next-only Sleep override identification, `updateAlarm:` request, timeout/error handling, and a fresh alarm-ID/time read-back. The tweak rejects recurring Sleep schedules and ordinary alarms.
- Added a PreferenceLoader Settings screen for manual preview/apply, evening automation, fallback/preparation options, and verified Copy/Share/Files diagnostics.
- Added planner unit tests, macOS rootless package workflow, and a generated flat APT source for Sileo.

**Known limitations:** This is compiled-source preview until verified on the iPhone 13 Pro Max with Dopamine and iOS 16.1.1. Calendar entitlement access in SpringBoard, MobileTimer write authorization, next-only override availability and visible Clock propagation remain device tests. No unattended alarm update is claimed yet. Automatic updates default to OFF. The Sileo index is unsigned, and GitHub raw redirects may need a Pages mirror for some clients.

See `tweak/README.md` for exact behavior, first-phone test and rollback.
