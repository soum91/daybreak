#!/usr/bin/env python3
"""Regenerate the isolated USBKeys flat APT source without changing Daybreak."""
from pathlib import Path
import bz2,gzip,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'sileo/usbkeys'
BASE='https://raw.githubusercontent.com/soum91/daybreak/main/sileo/usbkeys/'
debs=sorted((OUT/'debs').glob('*.deb'))
assert debs, 'No package to publish'
paragraphs=[]
for deb in debs:
 raw=deb.read_bytes()
 control=subprocess.check_output(['dpkg-deb','-f',str(deb)],text=True).strip()
 assert 'Package: dev.usbkeys.keyboard\n' in control+'\n'
 assert 'Architecture: iphoneos-arm64\n' in control+'\n'
 control+='\nFilename: debs/'+deb.name+'\nSize: '+str(len(raw))
 control+='\nMD5sum: '+hashlib.md5(raw).hexdigest()
 control+='\nSHA256: '+hashlib.sha256(raw).hexdigest()
 control+='\nIcon: '+BASE+'CydiaIcon.png'
 paragraphs.append(control)
packages=('\n\n'.join(paragraphs)+'\n\n').encode()
(OUT/'Packages').write_bytes(packages)
(OUT/'Packages.gz').write_bytes(gzip.compress(packages,mtime=0))
(OUT/'Packages.bz2').write_bytes(bz2.compress(packages))
items=['Packages','Packages.gz','Packages.bz2']
release=['Origin: USBKeys','Label: USBKeys Experimental','Suite: stable','Codename: usbkeys','Version: 1.0','Architectures: iphoneos-arm64','Components: main','Description: Experimental USB HID keyboard for Dopamine on iOS 16']
for label,algorithm in [('MD5Sum','md5'),('SHA256','sha256')]:
 release.append(label+':')
 for name in items:
  data=(OUT/name).read_bytes()
  release.append(f' {hashlib.new(algorithm,data).hexdigest()} {len(data)} {name}')
(OUT/'Release').write_text('\n'.join(release)+'\n')
(OUT/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(OUT))+'\n' for p in debs))
print('USBKeys APT source generated:',len(debs),'package(s)')
from build_tweaks_repo import build
build(ROOT)
