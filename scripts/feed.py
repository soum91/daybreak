import datetime
import json
import os
from pathlib import Path

number = int(os.environ.get('BUILD_NUMBER', '1'))
version = f'0.1.{number}'
base = 'https://github.com/soum91/daybreak/releases/latest/download/'
ipa = Path('dist/Daybreak.ipa')
feed = {
    'name': 'Daybreak', 'identifier': 'com.soum91.daybreak.source',
    'subtitle': 'Calendar-aware mornings, starting with a Sleep alarm diagnostic',
    'website': 'https://github.com/soum91/daybreak',
    'apps': [{
        'name': 'Daybreak', 'bundleIdentifier': 'com.soum91.daybreak',
        'developerName': 'soum91', 'version': version, 'buildVersion': str(number),
        'versionDate': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'versionDescription': 'Experimental Sleep alarm access and Siri shortcut diagnostic. Calendar-based planning and evening URL trigger included. Locked-screen execution remains unverified.',
        'downloadURL': base + 'Daybreak.ipa', 'iconURL': base + 'Daybreak.png',
        'localizedDescription': 'Inspect actual Sleep alarm access and test a next-only update. Calendar data stays on the phone.',
        'size': ipa.stat().st_size if ipa.exists() else 0, 'minOSVersion': '17.0',
        'versions': [{
            'version': version, 'buildVersion': str(number),
            'date': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'downloadURL': base + 'Daybreak.ipa', 'size': ipa.stat().st_size if ipa.exists() else 0,
            'minOSVersion': '17.0',
        }],
    }], 'news': [],
}
runner=Path('dist/DaybreakRunner.ipa')
if runner.exists():
    feed['apps'].append({
        'name':'Daybreak Runner', 'bundleIdentifier':'com.soum91.daybreak.runner',
        'developerName':'soum91', 'version':version, 'buildVersion':str(number),
        'versionDate':feed['apps'][0]['versionDate'], 'downloadURL':base+'DaybreakRunner.ipa',
        'iconURL':base+'Daybreak.png','size':runner.stat().st_size,'minOSVersion':'17.0',
        'localizedDescription':'Experimental on-device Siri runner. Requires DEVELOPMENT signing with get-task-allow, a signed nested .xctest bundle, a mounted developer image and UI Automation approval. Distribution signing is insufficient. Calendar planning is configured in Daybreak.',
        'versionDescription':'On-device-only Sleep alarm test; real-device execution remains unverified.',
    })
Path('dist').mkdir(exist_ok=True)
Path('dist/repo.json').write_text(json.dumps(feed, indent=2)+'\n')
