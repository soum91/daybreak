"""Check the deliverable, rather than assuming a successful zip is installable."""
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None, 'Corrupt archive'
    root = 'Payload/Daybreak.app/'
    info = plistlib.loads(z.read(root + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'com.soum91.daybreak'
    assert int(info['CFBundleVersion']) > 0
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
    binary = z.read(root + info['CFBundleExecutable'])
    assert binary[:4] == b'\xcf\xfa\xed\xfe', 'Not a 64-bit Mach-O'
    assert len(binary) > 10000, 'Missing or truncated application binary'
    assert root + 'AppIcon60x60@3x.png' in z.namelist()
    print('IPA structure, version, executable, device platform and icon verified.')
