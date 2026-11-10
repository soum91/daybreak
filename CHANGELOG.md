# Changelog

## Daybreak Dopamine tweak 0.2.2 (2026-11-10)

- Fixed the blank Settings preference controller by inheriting and populating
  the actual `PSListController` specifier storage. The former declaration
  shadowed that storage, leaving the preference table empty.
- Added a native Home Screen app within the existing rootless package, alongside
  Settings → Daybreak. The app offers Calendar access and selection, wake preview,
  adjustable preparation/fallback/evening settings, manual Apply, installed
  version/build, and diagnostic Copy/Share/Save to Files.
- Added a short-lived one-time calendar-plan handoff from the app to the
  SpringBoard engine for manual updates, preserving the next-only Sleep override
  safety checks and requiring fresh alarm read-back.
- Updated tweak CI to generate Home Screen icons and verify that the `.deb`
  includes the app and preference bundle. Device behavior awaits testing.

## [v0.1.20] - 2026-11-10

## Verified changes since v0.1.19

- feat: add Daybreak iOS 16 Dopamine tweak and Sileo build pipeline ([`1f5aaeaa`](https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37); `.github/workflows/build.yml`, `.github/workflows/tweak.yml`, `scripts/build_sileo.py`, and 16 more)
- Update Daybreak source to build 19 ([`d04172fb`](https://github.com/soum91/daybreak/commit/d04172fb99383d66892c39413c59799b83d09bb9); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.19...v0.1.20)

## [tweak-v0.2.0] - 2026-11-10

## Verified changes since v0.1.19

- fix: dynamically resolve Settings Preferences host in rootless bundle ([`cae94861`](https://github.com/soum91/daybreak/commit/cae948618db1543d175c1977994f25b78c9682b3); `tweak/prefs/Makefile`)
- feat: add Daybreak iOS 16 Dopamine tweak and Sileo build pipeline ([`1f5aaeaa`](https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37); `.github/workflows/build.yml`, `.github/workflows/tweak.yml`, `scripts/build_sileo.py`, and 16 more)
- Update Daybreak source to build 19 ([`d04172fb`](https://github.com/soum91/daybreak/commit/d04172fb99383d66892c39413c59799b83d09bb9); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.19...tweak-v0.2.0)

## 0.1.20

Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.

Source commit: https://github.com/soum91/daybreak/commit/1f5aaeaab9461242e4db3351e8d4ea28c4fa1d37

## [v0.1.19] - 2026-11-10

## Verified changes since v0.1.18

- Continue Clock discovery beyond preferences and remember identified storage ([`1ed16f96`](https://github.com/soum91/daybreak/commit/1ed16f964a7ee54069c14cede6fdf4180ef5f5b9); `App/ClockAccess.m`, `App/main.m`, `release-notes/current.md`, and 1 more)
- Update Daybreak source to build 18 ([`3c80198c`](https://github.com/soum91/daybreak/commit/3c80198c25f40a157173252c63256379a23a88cb); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.18...v0.1.19)

## 0.1.19

Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.

Source commit: https://github.com/soum91/daybreak/commit/1ed16f964a7ee54069c14cede6fdf4180ef5f5b9

## [v0.1.18] - 2026-11-10

## Verified changes since v0.1.17

- Continue Clock scan ranges automatically ([`5d9db671`](https://github.com/soum91/daybreak/commit/5d9db6713c00ab787ea0bfb5e1c27898c41463e1); `.github/workflows/build.yml`, `App/ClockAccess.h`, `App/ClockAccess.m`, and 3 more)
- Pin Daybreak feed downloads to verified v0.1.17 assets ([`bd43e19e`](https://github.com/soum91/daybreak/commit/bd43e19e712d6ce4ab2a16cc258a05d0fa301183); `repo.json`)
- Update Daybreak source to build 17 ([`6f434271`](https://github.com/soum91/daybreak/commit/6f4342710c14d3e5015c158038038633de053723); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.17...v0.1.18)

## 0.1.18

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

The Clock scan now continues through saved inode ranges automatically after one tap instead of requiring a tap for every roughly 25-second range. It reports each range, preserves the cursor so an interrupted scan can resume, keeps the screen awake while it runs, and stops when it finds a matching Clock container or reaches the end of the inode range. Keep Daybreak open during the scan; iOS may suspend it if the user switches apps or locks the phone.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. Automatic range chaining and the direct SystemGroup check need physical-device verification; previous reports verify only the earlier build's access to Clock's app container and do not establish that the complete scan will find the live alarm store.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md

Source commit: https://github.com/soum91/daybreak/commit/5d9db6713c00ab787ea0bfb5e1c27898c41463e1

## [v0.1.17] - 2026-11-10

## Verified changes since v0.1.15

- Allow hosted Simulator more time to finish app installation ([`5d7df606`](https://github.com/soum91/daybreak/commit/5d7df606a281fccb0484e3af18c79f5a666fcac1); `release-notes/current.md`, `scripts/smoke.py`)
- Probe MobileTimer SystemGroup directly before inode scan ([`0d9f02fa`](https://github.com/soum91/daybreak/commit/0d9f02fabded7815fd29328a222c9df591d7494b); `App/ClockAccess.m`, `README.md`, `release-notes/current.md`, and 1 more)
- Update Daybreak source to build 15 ([`303ffbac`](https://github.com/soum91/daybreak/commit/303ffbacc886e3e795ccaa01763352459ec1befc); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.15...v0.1.17)

## 0.1.17

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. The direct SystemGroup check and diagnostic exports need physical-device verification; the earlier report verifies only the previous build's access to Clock's app container.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md

Source commit: https://github.com/soum91/daybreak/commit/5d7df606a281fccb0484e3af18c79f5a666fcac1

## [v0.1.15] - 2026-11-10

## Verified changes since v0.1.12

- Prevent release metadata updates from triggering another build ([`a57b7c19`](https://github.com/soum91/daybreak/commit/a57b7c196aa18873c8cce8190093f4e561fe6022); `.github/workflows/build.yml`)
- Add worse_query Clock storage experiment without XCTest ([`276f1e53`](https://github.com/soum91/daybreak/commit/276f1e533d57e8266b8675935ff30ddd75d91531); `.github/workflows/build.yml`, `App/ClockAccess.h`, `App/ClockAccess.m`, and 11 more)
- Enforce visible installed version/build across app releases ([`9146e933`](https://github.com/soum91/daybreak/commit/9146e933ec6043caf196e85c726d554d5f72ca2f); `.github/workflows/build.yml`, `.github/workflows/version-ui.yml`, `scripts/check_version_ui.py`, and 1 more)
- Update Daybreak source to build 12 ([`b6dc3cb1`](https://github.com/soum91/daybreak/commit/b6dc3cb1ba8653e58218f4237a0ecee74a261f13); `repo.json`)

[Inspect exact code changes](https://github.com/soum91/daybreak/compare/v0.1.12...v0.1.15)

## Unreleased

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.
- Raises the CI Simulator installation timeout from 60 to 180 seconds after a hosted runner timed out during installation. Launch and planner assertions remain mandatory and unchanged.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. The direct SystemGroup check and diagnostic exports need physical-device verification; the earlier report verifies only the previous build's access to Clock's app container.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md


## Unreleased

Added a Clock filesystem access experiment using worse_query. This is a read-only investigation of a possible replacement for XCTest, not a working replacement for changing alarms.

- Added **Test Clock filesystem access** in Daybreak. It checks the actual signed App Group, searches container metadata for Clock, and reports matching preference keys and immutable SQLite base-file table names. Alarm values and database rows are omitted. The scan is partial when its work budget expires; another tap resumes inode discovery.
- Preserves and restores the App Group Caches directory, including recovery after an interrupted swap. Sandbox extensions are released after inspection. No Clock files are written and no XCTest/Siri session is started by this test.
- Added selectable diagnostics, Copy with clipboard read-back and a visible result, native Share, and native Save to Files. Runner session credentials are redacted from the displayed/exported report.
- Added the App Group signing entitlement and upstream GPL license/attribution. The signer must supply a matching, accessible App Group in the provisioning profile; the app checks the actual entitlement after signing.

Existing calendar planning and the separate Siri/XCTest runner remain available. Clock-service access, changing a live Sleep alarm through filesystem access, daemon reload, and unattended/locked-screen operation are **not implemented or verified** by this experiment. SQLite inspection excludes WAL contents and reports base-file schema only.

Validation: release CI compiles device and simulator targets, enforces installed-version metadata, and runs the existing planner/launch inspection. The exploit is disabled in Simulator. Filesystem access and Copy/paste, Share, and Files export require signed physical-device verification and have not been verified by the developer on a phone.

Source baseline: https://github.com/soum91/daybreak/commit/9191ec10e594bda9cfafb5618d1e45f65f98dbf8


This log records verified, release-specific changes. The [Factual release changelog](.github/workflows/release-changelog.yml) GitHub Action adds entries based on the actual commits between published releases. Entries are not fabricated for older versions that have not been audited.


# Daybreak Dopamine 0.2.0 (tweak preview; device verification pending)

- Introduced the rootless iOS 16 SpringBoard/PreferenceLoader tweak under `tweak/` for the iPhone 13 Pro Max with Dopamine, leaving the iOS 17+ app and Runner intact.
- Ported tomorrow's earliest timed event before noon, preparation minutes and 08:30 fallback into `tweak/DBPlanner.m`; added deterministic planner tests in `tests/DaybreakTweakPlannerTests.m`.
- Added guarded MobileTimer next-only Sleep override updates and fresh read-back verification in `tweak/Tweak.m`. An absent or ambiguous next-only override is rejected; no recurring Sleep schedule or regular alarm is changed.
- Added Settings controls for manual preview/apply, evening automation, calendar selection and diagnostic export in `tweak/prefs/`.
- Added `.github/workflows/tweak.yml` and `scripts/build_sileo.py` to compile a real rootless `.deb` and publish its matching Sileo flat APT index under `sileo/` only after build checks pass.
- **Limitation:** Not yet verified on an iOS 16.1.1 Dopamine device. EventKit access, MobileTimer write authorization, next-only override persistence and Sileo installation require a real-device check. Automatic mode is off by default.

