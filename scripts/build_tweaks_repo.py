#!/usr/bin/env python3
"""Build the shared Sileo catalog from verified, unchanged first-party packages."""
import argparse
import bz2
import gzip
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/soum91/daybreak/main/sileo/"
GENERATED = {"Filename", "Size", "MD5sum", "SHA1", "SHA256", "SHA512"}


def paragraphs(text):
    result = []
    for block in re.split(r"\n\s*\n", text.strip()):
        fields = {}
        last = None
        for line in block.splitlines():
            if line.startswith((" ", "\t")) and last:
                fields[last] += "\n" + line
            else:
                key, separator, value = line.partition(":")
                if not separator or key in fields:
                    raise ValueError("Malformed or duplicate control field")
                fields[key] = value.lstrip()
                last = key
        if fields:
            result.append(fields)
    return result


def newer(a, b):
    return subprocess.run(["dpkg", "--compare-versions", a, "gt", b], check=False).returncode == 0


def newest(entries, package):
    chosen = None
    for item in entries:
        if item.get("Package") != package or item.get("Architecture") != "iphoneos-arm64":
            continue
        if chosen and item["Version"] == chosen["Version"] and item.get("SHA256") != chosen.get("SHA256"):
            raise ValueError(f"Conflicting content for {package} {item['Version']}")
        if chosen is None or newer(item["Version"], chosen["Version"]):
            chosen = item
    if chosen is None:
        raise ValueError(f"No published rootless package: {package}")
    return chosen


def relative_path(value):
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or urllib.parse.urlsplit(value).scheme:
        raise ValueError("Package filename must be a relative path")
    return str(path)


def download(url, limit=16 * 1024 * 1024):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or parsed.netloc != "raw.githubusercontent.com" or not parsed.path.startswith("/soum91/"):
        raise ValueError("Only configured first-party public HTTPS sources are accepted")
    request = urllib.request.Request(url, headers={"User-Agent": "soum91-tweaks-catalog", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Upstream package exceeds catalog size limit")
    return data


def verify_archive(blob, expected):
    if len(blob) != int(expected["Size"]) or hashlib.sha256(blob).hexdigest() != expected["SHA256"]:
        raise ValueError(f"Upstream hash/size mismatch: {expected['Package']}")


def control(blob):
    with tempfile.NamedTemporaryFile(suffix=".deb") as file:
        file.write(blob)
        file.flush()
        raw = subprocess.check_output(["dpkg-deb", "-f", file.name], text=True)
    return paragraphs(raw)[0]


def build(root=ROOT, sync=False):
    out = root / "sileo"
    config = json.loads((out / "sources.json").read_text())
    assert config["schema_version"] == 1
    old = json.loads((out / "catalog.json").read_text()) if (out / "catalog.json").exists() else {"packages": []}
    cache = {item["package"]: item for item in old["packages"]}
    pending = {}
    catalog = []
    stanzas = []
    identities = set()
    for source in config["sources"]:
        entries = None
        if source.get("local_index"):
            index = root / relative_path(source["local_index"])
            entries = paragraphs(index.read_text())
        elif sync and source.get("index_url"):
            entries = paragraphs(download(source["index_url"], 1024 * 1024).decode())
        for package in source["packages"]:
            if package in identities:
                raise ValueError("Duplicate package in source manifest")
            identities.add(package)
            expected = None
            if source.get("local_deb"):
                location = relative_path(source["local_deb"])
                blob = (root / location).read_bytes()
                origin = BASE + location.removeprefix("sileo/")
            elif entries is not None:
                expected = newest(entries, package)
                location = relative_path(expected["Filename"])
                if source.get("local_index"):
                    base = (root / source["local_index"]).parent
                    blob = (base / location).read_bytes()
                    origin = BASE + str((base / location).relative_to(out))
                else:
                    origin = urllib.parse.urljoin(source["index_url"], location)
                    blob = download(origin)
                verify_archive(blob, expected)
            else:
                if package not in cache:
                    raise ValueError("Run --sync to populate the external package cache first")
                previous = cache[package]
                blob = (out / relative_path(previous["filename"])).read_bytes()
                verify_archive(blob, {"Size": previous["size"], "SHA256": previous["sha256"], "Package": package})
                origin = previous["upstream_url"]
                expected = dict(Package=package, Version=previous["version"], Architecture=previous.get("architecture", "iphoneos-arm64"), **previous.get("presentation", {}))
            metadata = control(blob)
            if metadata.get("Package") != package or metadata.get("Architecture") != "iphoneos-arm64":
                raise ValueError(f"Unexpected binary identity: {package}")
            if expected and any(metadata.get(key) != expected.get(key) for key in ("Package", "Version", "Architecture")):
                raise ValueError("Binary and upstream index disagree")
            # Public first-party metadata uses the account alias. Do not rewrite binaries.
            if metadata.get("Maintainer") != "soum91" or metadata.get("Author") != "soum91":
                raise ValueError(f"Review first-party attribution before mirroring {package}")
            digest = hashlib.sha256(blob).hexdigest()
            previous = cache.get(package)
            if previous and (newer(previous["version"], metadata["Version"]) or
                (previous["version"] == metadata["Version"] and previous["sha256"] != digest)):
                raise ValueError(f"Refusing downgrade or same-version replacement: {package}")
            safe_version = re.sub(r"[^A-Za-z0-9.+~_-]", "_", metadata["Version"])
            filename = f"debs/{package}_{safe_version}_{digest[:12]}.deb"
            pending[filename] = blob
            fields = {key: value for key, value in metadata.items() if key not in GENERATED}
            if expected:
                index_base = source.get("index_url") or BASE + source["local_index"].removeprefix("sileo/")
                for key in ("Icon", "Depiction", "SileoDepiction"):
                    if expected.get(key):
                        fields[key] = urllib.parse.urljoin(index_base, expected[key])
            fields.update(Filename=filename, Size=str(len(blob)), MD5sum=hashlib.md5(blob).hexdigest(), SHA256=digest)
            stanzas.append((package, "\n".join(f"{k}: {v}" for k, v in fields.items())))
            record = dict(package=package, name=metadata.get("Name", package), version=metadata["Version"],
                architecture=metadata["Architecture"], source=source["name"], upstream_url=origin,
                filename=filename, size=len(blob), sha256=digest)
            presentation = {key: fields[key] for key in ("Icon", "Depiction", "SileoDepiction") if key in fields}
            if presentation:
                record["presentation"] = presentation
            catalog.append(record)
    packages = ("\n\n".join(s for _, s in sorted(stanzas)) + "\n\n").encode()
    pending.update({"Packages": packages, "Packages.gz": gzip.compress(packages, mtime=0), "Packages.bz2": bz2.compress(packages)})
    release = ["Origin: soum91 Tweaks", "Label: soum91 Tweaks", "Suite: stable", "Codename: daybreak", "Version: 1.0",
        "Architectures: iphoneos-arm64", "Components: main", "Description: Shared rootless jailbreak packages by soum91"]
    for field, algorithm in (("MD5Sum", "md5"), ("SHA256", "sha256")):
        release.append(field + ":")
        for path in ("Packages", "Packages.gz", "Packages.bz2"):
            data = pending[path]
            release.append(f" {hashlib.new(algorithm, data).hexdigest()} {len(data)} {path}")
    pending["Release"] = ("\n".join(release) + "\n").encode()
    pending["catalog.json"] = (json.dumps({"schema_version": 1, "packages": sorted(catalog, key=lambda x: x["package"])}, indent=2) + "\n").encode()
    pending["SHA256SUMS"] = "".join(f"{row['sha256']}  {row['filename']}\n" for row in sorted(catalog, key=lambda x: x["package"])).encode()
    rows = "".join(f"<tr><td>{html.escape(r['name'])}</td><td>{html.escape(r['version'])}</td></tr>" for r in sorted(catalog, key=lambda x: x["name"]))
    pending["index.html"] = (f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>soum91 Tweaks</title><style>body{font:17px system-ui;max-width:850px;margin:3rem auto;padding:0 20px;background:#101827;color:#edf5ff}a{color:#6ee7cf}td,th{text-align:left;padding:10px;border-bottom:1px solid #334155}code{overflow-wrap:anywhere}table{width:100%}</style>'
        f'<h1>soum91 Tweaks</h1><p>One Sileo source for rootless jailbreak packages.</p><p><code>{BASE}</code></p>'
        f'<p><a href="sileo://source/{BASE}">Add to Sileo</a></p><table><tr><th>Package</th><th>Version</th></tr>{rows}</table>'
        '<p>Existing package identities, dependencies and binaries are preserved. Experimental labels remain applicable. Hosting does not establish device compatibility.</p></html>').encode()
    # Validate everything before mutating the working tree. A Git commit publishes the set together.
    for name, data in pending.items():
        target = out / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(f"Shared Sileo catalog: {len(catalog)} unchanged rootless packages")
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sync", action="store_true", help="Refresh configured public upstream package indexes")
    options = parser.parse_args()
    build(sync=options.sync)
