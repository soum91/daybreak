Clock storage discovery no longer stops after finding the Clock app preferences container. Build 18 found only default sound/timer preferences on the user's device; that does not establish that daemon/shared storage was searched completely.

- Continue all remaining inode ranges after a Clock container is found. Completion now requires reaching the scan bound or an explicit error.
- Remember identified Clock paths locally and inspect them directly on subsequent runs before discovery. Paths are validated against allowed container roots and Clock identifiers.
- Give each identified container its own ten-second listing budget, extend traversal from four to eight levels, and report file stat failures.
- Compare Clock identifiers without case sensitivity and report how many candidate containers could not be identified. An inode-range completion is not proof that every container was visible.
- Preserve automatic progress, cursor saving, and owned App Group cache recovery.

Validation: required installed-version preflight and existing CI compilation/cache recovery/simulator checks. Physical-device verification of these discovery changes remains pending. Alarm database discovery, writes, Clock service access and locked-screen operation remain unverified. No alarm mutation is implemented.
