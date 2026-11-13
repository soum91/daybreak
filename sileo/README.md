# soum91 Tweaks: shared Sileo source

Add this source in Sileo:

https://raw.githubusercontent.com/soum91/daybreak/main/sileo/

It currently includes Daybreak, USBKeys, Timbre Audio, HomePod Bridge, its homed
Capability Bridge experiment, Reynard Default Browser and WebKit Patch.
Package identities, versions, dependencies, experimental labels and exact signed
binary bytes are retained. Hosting adds no claim of hardware compatibility.
The old USBKeys, Timbre, HomePodBridge and Reynard sources still work. After the
shared source refreshes successfully, remove redundant old sources in Sileo;
installed packages can continue receiving upgrades through their existing IDs.
Reynard's browser application remains in its original source; keep that source
if you use the browser `.deb`. Its two tweaks are included in this catalog.

## Publishing

- Project source and build pipelines remain in their original repositories and branches.
- `sources.json` lists explicit first-party package IDs and upstream indexes.
- Run `python3 scripts/build_tweaks_repo.py --sync` to verify and mirror the newest
  published rootless packages. Debian version comparison selects `.13` over `.9`.
- The hourly GitHub Actions sync performs the same checks. It also supports manual
  dispatch. Upstream outages or mismatches fail without publishing a partial index.
- `catalog.json` records original download URLs, versions, sizes and SHA-256 hashes.
  Those cached, verified packages allow Daybreak publication without network reads.
- `build_sileo.py` replaces only Daybreak's package; `build_usbkeys_sileo.py` refreshes
  the legacy USBKeys source and the shared catalog. Neither wipes unrelated packages.
- Every indexed filename contains its version and content digest. Keep old package
  files available so clients with cached indexes can still download them.
- Reject archive/index identity, size or hash mismatches, downgrades and changed
  content using an already-published version. Rebuilds need a package revision.
- New tweaks must be added to `sources.json` before syncing. Do not automatically
  import third-party bootstrap components, unbuilt source trees or rootful packages.

This is currently an unsigned APT source over HTTPS. APT repository signing is
separate from the existing signatures inside the jailbreak packages. The public
files are checked after publication; physical Sileo source migration is unverified.
