import bz2
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/build_tweaks_repo.py'
spec = importlib.util.spec_from_file_location('catalog', SCRIPT)
repo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repo)


class CatalogTests(unittest.TestCase):
    def test_platform_independent_gzip(self):
        data = b'Package: example\n\n'
        archive = repo.portable_gzip(data)
        self.assertEqual(archive[4:8], b'\0\0\0\0')
        self.assertEqual(archive[9], 255)
        self.assertEqual(gzip.decompress(archive), data)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'sileo/debs').mkdir(parents=True)

    def deb(self, package, version, suffix=''):
        staging = self.root / ('stage-' + package + version + suffix)
        (staging / 'DEBIAN').mkdir(parents=True)
        (staging / 'DEBIAN/control').write_text(
            f'Package: {package}\nName: Example\nVersion: {version}\nArchitecture: iphoneos-arm64\n'
            'Maintainer: soum91\nAuthor: soum91\nDescription: Original description\n continuation preserved\n'
            'Depends: ellekit, preferenceloader\n')
        (staging / 'payload').write_text(suffix)
        target = self.root / f'{package}-{version}{suffix}.deb'
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(staging), str(target)], check=True, stdout=subprocess.DEVNULL)
        return target.read_bytes()

    def configure(self):
        first = self.deb('com.soum91.daybreak.tweak', '1.0.0')
        second = self.deb('com.soum91.example', '0.1.0.13')
        (self.root / 'sileo/debs/daybreak-tweak.deb').write_bytes(first)
        remote = self.root / 'sileo/debs/cached.deb'
        remote.write_bytes(second)
        manifest = {'schema_version': 1, 'sources': [
            {'name': 'Daybreak', 'local_deb': 'sileo/debs/daybreak-tweak.deb', 'packages': ['com.soum91.daybreak.tweak']},
            {'name': 'Other', 'index_url': 'https://raw.githubusercontent.com/soum91/example/main/Packages', 'packages': ['com.soum91.example']}]}
        (self.root / 'sileo/sources.json').write_text(json.dumps(manifest))
        cached = {'package': 'com.soum91.example', 'version': '0.1.0.13', 'filename': 'debs/cached.deb', 'size': len(second),
            'sha256': hashlib.sha256(second).hexdigest(), 'upstream_url': 'https://raw.githubusercontent.com/soum91/example/main/cached.deb'}
        (self.root / 'sileo/catalog.json').write_text(json.dumps({'schema_version': 1, 'packages': [cached]}))
        return first, second

    def test_debian_version_order(self):
        entries = [{'Package': 'test', 'Architecture': 'iphoneos-arm64', 'Version': v, 'SHA256': v} for v in ['0.1.0.9', '0.1.0.13', '0.1.0.10']]
        self.assertEqual(repo.newest(entries, 'test')['Version'], '0.1.0.13')
        self.assertTrue(repo.newer('1.0', '1.0~rc1'))

    def test_reject_conflicting_same_version(self):
        entries = [{'Package': 'test', 'Architecture': 'iphoneos-arm64', 'Version': '1.0', 'SHA256': s} for s in ['aaa', 'bbb']]
        with self.assertRaises(ValueError): repo.newest(entries, 'test')

    def test_cache_preserved_on_daybreak_update(self):
        _, second = self.configure()
        repo.build(self.root)
        updated = self.deb('com.soum91.daybreak.tweak', '1.0.1')
        (self.root / 'sileo/debs/daybreak-tweak.deb').write_bytes(updated)
        result = repo.build(self.root)
        self.assertEqual(len(result), 2)
        other = next(r for r in result if r['package'] == 'com.soum91.example')
        self.assertEqual((self.root / 'sileo' / other['filename']).read_bytes(), second)
        for row in result:
            self.assertEqual(hashlib.sha256((self.root / 'sileo' / row['filename']).read_bytes()).hexdigest(), row['sha256'])
        packages = (self.root / 'sileo/Packages').read_bytes()
        self.assertEqual(gzip.decompress((self.root / 'sileo/Packages.gz').read_bytes()), packages)
        self.assertEqual(bz2.decompress((self.root / 'sileo/Packages.bz2').read_bytes()), packages)
        self.assertIn(b'Depends: ellekit, preferenceloader', packages)
        self.assertIn(b'\n continuation preserved', packages)

    def test_failure_does_not_replace_published_index(self):
        self.configure()
        repo.build(self.root)
        before = (self.root / 'sileo/Packages').read_bytes()
        with patch.object(repo, 'download', side_effect=OSError('upstream unavailable')):
            with self.assertRaises(OSError): repo.build(self.root, sync=True)
        self.assertEqual((self.root / 'sileo/Packages').read_bytes(), before)

    def test_changed_same_version_refused(self):
        self.configure()
        repo.build(self.root)
        before = (self.root / 'sileo/Packages').read_bytes()
        replacement = self.deb('com.soum91.daybreak.tweak', '1.0.0', 'changed')
        (self.root / 'sileo/debs/daybreak-tweak.deb').write_bytes(replacement)
        with self.assertRaises(ValueError): repo.build(self.root)
        self.assertEqual((self.root / 'sileo/Packages').read_bytes(), before)

    def test_corrupted_cache_refused(self):
        self.configure()
        (self.root / 'sileo/debs/cached.deb').write_bytes(b'corrupted')
        with self.assertRaises(ValueError): repo.build(self.root)
        self.assertFalse((self.root / 'sileo/Packages').exists())

    def test_paths_and_duplicate_control_fields_rejected(self):
        for path in ['../../escape', '/debs/file', 'https://host/deb']:
            with self.subTest(path=path), self.assertRaises(ValueError): repo.relative_path(path)
        with self.assertRaises(ValueError): repo.paragraphs('Package: a\nPackage: b\n')


if __name__ == '__main__':
    unittest.main()
