Added a direct read-only check of the named MobileTimer SystemGroup before inode discovery. The previous version reached Clock's app preferences on a user's iOS 27.0.1 phone but found only default sound/timer settings; it did not locate live alarms.

- Tries `/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobiletimerd` directly before querying/listing container parents. A denied parent listing no longer prevents testing that fixed Clock path.
- Reports the child's token result, directory accessibility and errno, distinguishing an attempted path from a verified readable store. The path is identified as a fixed MobileTimer path rather than claiming its metadata was verified.
- Includes immutable SQLite base-file table definitions, providing column names without reading alarm rows or writing database sidecars. WAL contents remain excluded.

This continues the filesystem investigation and does not implement alarm mutation, daemon reload, or unattended execution. No XCTest or Siri session is started by the filesystem button. Existing calendar application still uses the separate runner. The direct SystemGroup check and diagnostic exports need physical-device verification; the earlier report verifies only the previous build's access to Clock's app container.

Validation: installed-version preflight, device and simulator compilation, cache preservation/recovery tests and existing simulator launch/planner and runner API checks are required by CI. No live alarm change is claimed.

Source baseline: https://github.com/soum91/daybreak/commit/a08071d7a416aa67b013c008da516610f0752840
Path evidence: https://github.com/blacktop/ipsw-diffs/blob/178049c35e1625cce0fe377dda3b938e76030a80/iOS/18_5_22F76__vs_26_0_23A5260n/DYLIBS/MobileTimer.md
