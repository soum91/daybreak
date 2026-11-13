#!/usr/bin/env python3
"""Update Daybreak without erasing other packages in the shared Sileo source."""
from pathlib import Path
import shutil
import subprocess
import sys
from build_tweaks_repo import build

ROOT = Path(__file__).resolve().parents[1]


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: build_sileo.py path/to/verified-rootless.deb")
    deb = Path(sys.argv[1]).resolve()
    identity = subprocess.check_output(["dpkg-deb", "-f", str(deb), "Package"], text=True).strip()
    arch = subprocess.check_output(["dpkg-deb", "-f", str(deb), "Architecture"], text=True).strip()
    if identity != "com.soum91.daybreak.tweak" or arch != "iphoneos-arm64":
        sys.exit("Unexpected package identity or architecture")
    target = ROOT / "sileo/debs/daybreak-tweak.deb"
    if target.resolve() != deb:
        shutil.copyfile(deb, target)
    build(ROOT)


if __name__ == "__main__":
    main()
