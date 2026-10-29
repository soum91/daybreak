"""Launch the built app in Simulator; do not test writes or claim device permission."""
import json
import subprocess
import time
from pathlib import Path

def run(*args):
    return subprocess.check_output(args, text=True, timeout=60).strip()

devices = json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
phone = next(d for ds in devices.values() for d in ds if 'iPhone' in d['name'])
udid = phone['udid']
if phone['state'] != 'Booted':
    subprocess.run(['xcrun','simctl','boot',udid],check=True,timeout=60)
subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True,timeout=180)
subprocess.run(['xcrun','simctl','install',udid,'build/simulator/Daybreak.app'],check=True,timeout=60)
subprocess.run(['xcrun','simctl','launch',udid,'com.soum91.daybreak','--smoke-test'],check=True,timeout=60)
time.sleep(18)
container = Path(run('xcrun','simctl','get_app_container',udid,'com.soum91.daybreak','data'))
report = (container/'Documents'/'Daybreak-diagnostic.txt').read_text()
assert 'App ready.' in report, report
assert 'INUpdateAlarmIntent methods:' in report, report
# Checking a running process catches crashes during private-framework inspection.
processes = run('xcrun','simctl','spawn',udid,'launchctl','list')
assert 'com.soum91.daybreak' in processes, 'App exited during inspection'
Path('dist/simulator-report.txt').write_text(report)
subprocess.run(['xcrun','simctl','io',udid,'screenshot','dist/simulator.png'],check=True,timeout=30)
print('Launch + read-only runtime inspection passed. Real iOS permissions remain untested.')
