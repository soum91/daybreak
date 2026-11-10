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
