# Third-party code

The worse_query technique in `App/ClockAccess.m` is adapted from Taj C (forcequit), copyright 2026, licensed under GNU GPL version 3 or later:

https://github.com/forcequitOS/worse_query

The source header retains the upstream attribution. Daybreak's combined distribution containing that code is provided under GPL-3.0-or-later; see `LICENSE`. The complete corresponding source and build scripts are in this repository at the release's source commit. Daybreak modifications preserve and recover the owned App Group cache directory instead of deleting its contents, inspect only identified Clock storage, release sandbox extensions, and limit discovery work. There is no warranty.

The container identifier and inode discovery approach was cross-checked against the GPL-3.0 WQ Files implementation:

https://github.com/kolbicz/WQFiles
