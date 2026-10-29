import pathlib
import plistlib
import shutil
import subprocess
import zipfile

products=pathlib.Path('build/runner-device/Build/Products/Debug-iphoneos')
source=products/'DaybreakUITests-Runner.app'
assert source.is_dir(), 'Missing XCTest runner app'
payload=pathlib.Path('build/runner-package/Payload')
payload.mkdir(parents=True,exist_ok=True)
app=payload/'DaybreakRunner.app'
if app.exists(): shutil.rmtree(app)
shutil.copytree(source,app,symlinks=True)
for p in sorted((app/'Frameworks').glob('XC*.framework')):
    shutil.rmtree(p)
for p in (app/'Frameworks').glob('Testing.framework'): shutil.rmtree(p)
for p in (app/'Frameworks').glob('libXCTestSwiftSupport.dylib'): p.unlink()
for p in app.rglob('*.dSYM'): shutil.rmtree(p)
for p in app.rglob('embedded.mobileprovision'): p.unlink()
info=plistlib.loads((app/'Info.plist').read_bytes())
info['CFBundleDisplayName']='Daybreak Runner'
info['CFBundleIdentifier']='com.soum91.daybreak.runner'
info['CFBundleURLTypes']=[{'CFBundleURLName':'com.soum91.daybreak.runner','CFBundleURLSchemes':['daybreak-runner']}]
info['UIFileSharingEnabled']=True
info['LSSupportsOpeningDocumentsInPlace']=True
info['NSLocalNetworkUsageDescription']='Read Daybreak Runner status from this iPhone only.'
info['CFBundleIcons']={'CFBundlePrimaryIcon':{'CFBundleIconFiles':['AppIcon60x60']}}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
for p in pathlib.Path('build/device/Payload/Daybreak.app').glob('AppIcon*.png'): shutil.copy2(p,app/p.name)
plugins=list((app/'PlugIns').glob('*.xctest'))
assert len(plugins)==1
plugin_info=plistlib.loads((plugins[0]/'Info.plist').read_bytes())
plugin_info['CFBundleIdentifier']=info['CFBundleIdentifier']
(plugins[0]/'Info.plist').write_bytes(plistlib.dumps(plugin_info))
for p in app.rglob('*.dylib'):
    if '.framework/' not in str(p): subprocess.run(['codesign','-f','-s','-',str(p)],check=True)
for p in sorted(app.rglob('*.framework'),key=lambda x:len(x.parts),reverse=True): subprocess.run(['codesign','-f','-s','-',str(p)],check=True)
for p in plugins: subprocess.run(['codesign','-f','-s','-',str(p)],check=True)
subprocess.run(['codesign','-f','-s','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
with zipfile.ZipFile('dist/DaybreakRunner.ipa','w',zipfile.ZIP_DEFLATED) as z:
    for p in app.rglob('*'):
        if p.is_file(): z.write(p,p.relative_to(payload.parent))
print('Runner packaged; requires development re-signing of app and nested .xctest.')
