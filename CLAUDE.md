# Claude development instructions

Read and follow [AGENTS.md](AGENTS.md) before changing app source, build scripts, GitHub Actions, or release feeds.

Mandatory: retain a discoverable runtime **Installed version + build** display for every app target. Run `python3 scripts/check_version_ui.py` before any release work. Never bypass the version contract; if a screen moves, update `version-ui-contract.json` and its evidence instead. Preserve the existing direct-to-main release workflow and unrelated app behavior.


## Diagnostic/reporting rule for Claude

Before implementing or changing any diagnostics or logs, follow the **Universal diagnostic copy and export contract** in `AGENTS.md`: verified Copy with visible feedback, native Share, native plain-text Files export, and complete selectable report. Avoid claiming these work until a signed-device paste and export check is complete.


## Universal diagnostic export contract

Every diagnostic/log report requires Copy with clipboard read-back verification where supported and visible success/failure, native Share, native Save as `.txt` with Files picker (`fileExporter` or `UIDocumentPickerViewController` on iOS), and selectable full text fallback. No silent clipboard-only buttons. Include app/version, device/OS, actionable return codes and redact secrets. Test cross-app paste, Share, Save on a signed device; otherwise mark unverified. Preserve existing policies.


## Shared Sileo catalog (all contributors)

Use **soum91 Tweaks** at `https://raw.githubusercontent.com/soum91/daybreak/main/sileo/`
for first-party rootless tweak distribution. Keep each project's implementation in
its existing repository or branch. The host's `sileo/sources.json` selects packages;
`python3 scripts/build_tweaks_repo.py --sync` mirrors exact published artifacts.
Do not change package identities, dependencies or versions merely to consolidate
hosting. Do not delete unrelated package files or rebuild the root index with a
single-package scanner. Both existing publisher scripts refresh the combined index.
Preserve compatibility sources while users migrate. Add new packages to the explicit
manifest and retain provenance/checksums. Version changes and verified builds remain
mandatory for actual app/tweak changes; hosting-only updates require factual notes,
index/package checks and `python3 scripts/check_version_ui.py`. The `[catalog only]`
commit marker is reserved for changes without app/tweak implementation changes; it
skips only the unchanged Daybreak compilation job, while catalog/version CI still runs.
