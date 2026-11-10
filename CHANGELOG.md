# Changelog

## Unreleased

Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.

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


