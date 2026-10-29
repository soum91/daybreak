import json
import pathlib
import subprocess

devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json'],text=True))['devices']
phone=next(d for ds in devices.values() for d in ds if 'iPhone' in d['name'])
udid=phone['udid']
if phone['state']!='Booted':
    subprocess.run(['xcrun','simctl','boot',udid],check=True,timeout=60)
subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True,timeout=240)
result=subprocess.run(['xcrun','simctl','spawn',udid,str(pathlib.Path('dist/IntentProbe-iOS').resolve())],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
pathlib.Path('dist/ios-intent-interfaces.txt').write_text(result.stdout)
print(result.stdout)
result.check_returncode()
