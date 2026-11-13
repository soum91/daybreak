# Project rules

- Keep the package explicitly experimental until physical source and target
  testing proves keyboard enumeration and input.
- Do not claim successful input based solely on compilation or local setup.
- Never log typed keys, passcodes, or full device identifiers.
- Capture original USB descriptions before mutating anything; preserve rollback.
- Do not write MobileGestalt, persistent USB plists, firmware, or the system volume.
- Do not add auto typing, automatic retries, or key generation at launch.
- Every release needs concrete CHANGELOG entries and an in-app version/build.
- Do not include personal legal names in identifiers, metadata, or artifacts.
