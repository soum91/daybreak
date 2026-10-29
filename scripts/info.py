import os
import plistlib
from pathlib import Path

app = Path(os.environ['APP_PATH'])
info = {
    'CFBundleName': 'Daybreak', 'CFBundleDisplayName': 'Daybreak',
    'CFBundleIdentifier': 'com.soum91.daybreak', 'CFBundleExecutable': 'Daybreak',
    'CFBundlePackageType': 'APPL', 'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleShortVersionString': os.environ['APP_VERSION'],
    'CFBundleVersion': os.environ['BUILD_NUMBER'], 'MinimumOSVersion': '17.0',
    'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1, 2],
    'CFBundleSupportedPlatforms': ['iPhoneSimulator' if os.environ['SDK_NAME'] == 'iphonesimulator' else 'iPhoneOS'],
    'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'LSApplicationQueriesSchemes': ['clock-alarm', 'daybreak-runner'],
    'NSAppTransportSecurity': {'NSAllowsLocalNetworking': True},
    'NSSiriUsageDescription': 'Test whether a Sleep alarm update can be saved as a Siri shortcut.',
    'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60'], 'UIPrerenderedIcon': False}},
    'CFBundleIcons~ipad': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60', 'AppIcon76x76'], 'UIPrerenderedIcon': False}},
    'UIFileSharingEnabled': True,
}
with (app / 'Info.plist').open('wb') as file:
    plistlib.dump(info, file)
(app / 'PkgInfo').write_bytes(b'APPL????')
