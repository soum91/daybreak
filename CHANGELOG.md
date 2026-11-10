# Changelog

## [v0.1.15] - 2026-11-10

## Verified changes since v0.1.12

- Prevent release metadata updates from triggering another build ([`a57b7c19`](https://github.com/soum91/daybreak/commit/a57b7c196aa18873c8cce8190093f4e561fe6022); `.github/workflows/build.yml`)
- Add worse_query Clock storage experiment without XCTest ([`276f1e53`](https://github.com/soum91/daybreak/commit/276f1e533d57e8266b8675935ff30ddd75d91531); `.github/workflows/build.yml`, `App/ClockAccess.h`, `App/ClockAccess.m`, and 11 more)
- Enforce visible installed version/build across app releases ([`9146e933`](https://github.com/soum91/daybreak/commit/9146e933ec6043caf196e85c726d554d5f72ca2f); `.github/workflows/build.yml`, `.github/workflows/version-ui.yml`, `scripts/check_version_ui.py`, and 1 more)
- Update Daybreak source to build 12 ([`b6dc3cb1`](https://github.com/soum91/daybreak/commit/b6dc3cb1ba8653e58218f4237a0ecee74a261f13); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.12...v0.1.15)

## 0.1.15

Added a Clock filesystem access experiment using worse_query. This is a read-only investigation of a possible replacement for XCTest, not a working replacement for changing alarms.

- Added **Test Clock filesystem access** in Daybreak. It checks the actual signed App Group, searches container metadata for Clock, and reports matching preference keys and immutable SQLite base-file table names. Alarm values and database rows are omitted. The scan is partial when its work budget expires; another tap resumes inode discovery.
- Preserves and restores the App Group Caches directory, including recovery after an interrupted swap. Sandbox extensions are released after inspection. No Clock files are written and no XCTest/Siri session is started by this test.
- Added selectable diagnostics, Copy with clipboard read-back and a visible result, native Share, and native Save to Files. Runner session credentials are redacted from the displayed/exported report.
- Added the App Group signing entitlement and upstream GPL license/attribution. The signer must supply a matching, accessible App Group in the provisioning profile; the app checks the actual entitlement after signing.

Existing calendar planning and the separate Siri/XCTest runner remain available. Clock-service access, changing a live Sleep alarm through filesystem access, daemon reload, and unattended/locked-screen operation are **not implemented or verified** by this experiment. SQLite inspection excludes WAL contents and reports base-file schema only.

Validation: release CI compiles device and simulator targets, enforces installed-version metadata, and runs the existing planner/launch inspection. The exploit is disabled in Simulator. Filesystem access and Copy/paste, Share, and Files export require signed physical-device verification and have not been verified by the developer on a phone.

Source baseline: https://github.com/soum91/daybreak/commit/9191ec10e594bda9cfafb5618d1e45f65f98dbf8

Source commit: https://github.com/soum91/daybreak/commit/a57b7c196aa18873c8cce8190093f4e561fe6022

