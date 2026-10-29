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
        'versionDescription': 'Experimental Sleep alarm access and Siri shortcut diagnostic. Calendar automation is not implemented yet.',
        'downloadURL': base + 'Daybreak.ipa', 'iconURL': base + 'Daybreak.png',
        'localizedDescription': 'Inspect actual Sleep alarm access and test a next-only update. Private repository downloads require GitHub authentication.',
        'size': ipa.stat().st_size if ipa.exists() else 0, 'minOSVersion': '17.0',
        'versions': [{
            'version': version, 'buildVersion': str(number),
            'date': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'downloadURL': base + 'Daybreak.ipa', 'size': ipa.stat().st_size if ipa.exists() else 0,
            'minOSVersion': '17.0',
        }],
    }], 'news': [],
}
Path('dist').mkdir(exist_ok=True)
Path('dist/repo.json').write_text(json.dumps(feed, indent=2)+'\n')
