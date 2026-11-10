#!/usr/bin/env python3
"""Build a reproducible unsigned APT index from one verified rootless .deb.

The publishing workflow commits the complete index and matching .deb together.
No package metadata or success claims are invented when the build fails.
"""
import bz2
import gzip
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "sileo"
FIELDS = ("Package", "Name", "Version", "Architecture", "Maintainer", "Author",
          "Section", "Depends", "Conflicts", "Description", "Homepage")


def digest(blob):
    return hashlib.md5(blob).hexdigest(), hashlib.sha256(blob).hexdigest()


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: build_sileo.py path/to/verified-rootless.deb")
    deb = Path(sys.argv[1]).resolve()
    if not deb.is_file() or deb.suffix != ".deb":
        sys.exit("Missing .deb; refusing to publish a feed without an installable package")
    raw = subprocess.check_output(["dpkg-deb", "-f", str(deb)], text=True)
    if "Architecture: iphoneos-arm64" not in raw or "Package: com.soum91.daybreak.tweak" not in raw:
        sys.exit("Unexpected package identity or architecture")
    metadata = []
    for line in raw.splitlines():
        if line.startswith(" "):
            metadata.append(line)
        elif any(line.startswith(field + ":") for field in FIELDS):
            metadata.append(line)
    if OUT.exists():
        # Preserve nothing stale. The index must refer to the exact current package.
        if not (OUT / "README.md").exists():
            sys.exit("Unexpected sileo directory; inspect before replacing generated files")
        for name in ("Packages", "Packages.gz", "Packages.bz2", "Release", "SHA256SUMS"):
            (OUT / name).unlink(missing_ok=True)
        for old in (OUT / "debs").glob("*.deb"):
            old.unlink()
    (OUT / "debs").mkdir(parents=True, exist_ok=True)
    target = OUT / "debs" / deb.name
    shutil.copyfile(deb, target)
    package_blob = target.read_bytes()
    package_md5, package_sha256 = digest(package_blob)
    metadata += [f"Filename: debs/{deb.name}", f"Size: {len(package_blob)}",
                 f"MD5sum: {package_md5}", f"SHA256: {package_sha256}"]
    packages = ("\n".join(metadata) + "\n\n").encode()
    (OUT / "Packages").write_bytes(packages)
    with (OUT / "Packages.gz").open("wb") as dest:
        with gzip.GzipFile(filename="", mode="wb", fileobj=dest, mtime=0) as stream:
            stream.write(packages)
    (OUT / "Packages.bz2").write_bytes(bz2.compress(packages))
    items = ("Packages", "Packages.gz", "Packages.bz2")
    release = ["Origin: Daybreak", "Label: Daybreak Dopamine", "Suite: stable",
               "Codename: daybreak", "Version: 1.0", "Architectures: iphoneos-arm64",
               "Components: main", "Description: Soumen's rootless Daybreak tweak for iOS 16",
               "MD5Sum:"]
    for item in items:
        blob = (OUT / item).read_bytes()
        release.append(f" {digest(blob)[0]} {len(blob)} {item}")
    release.append("SHA256:")
    for item in items:
        blob = (OUT / item).read_bytes()
        release.append(f" {digest(blob)[1]} {len(blob)} {item}")
    (OUT / "Release").write_text("\n".join(release) + "\n", encoding="utf-8")
    (OUT / "SHA256SUMS").write_text(f"{package_sha256}  debs/{deb.name}\n", encoding="utf-8")
    print(f"SILEO_INDEX_OK {target.name} {package_sha256}")


if __name__ == "__main__":
    main()
