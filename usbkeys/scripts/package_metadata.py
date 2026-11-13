import plistlib,sys
from pathlib import Path
root=Path(sys.argv[1]); app=root/'var/jb/Applications/USBKeys.app'
info=dict(CFBundleIdentifier='dev.usbkeys.app',CFBundleExecutable='USBKeys',CFBundleName='USBKeys',CFBundleDisplayName='USBKeys',CFBundlePackageType='APPL',CFBundleInfoDictionaryVersion='6.0',CFBundleSupportedPlatforms=['iPhoneOS'],CFBundleShortVersionString='0.1.6',CFBundleVersion='7',MinimumOSVersion='16.1',LSRequiresIPhoneOS=True,UIDeviceFamily=[1],UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'])
plistlib.dump(info,(app/'Info.plist').open('wb'))
service=dict(Label='dev.usbkeys.service',ProgramArguments=['/var/jb/usr/libexec/usbkeysd'],UserName='root',RunAtLoad=True,KeepAlive=True,ThrottleInterval=5,ProcessType='Interactive',ExitTimeOut=10)
plistlib.dump(service,(root/'var/jb/Library/LaunchDaemons/dev.usbkeys.service.plist').open('wb'))
# Draw a deterministic icon with Pillow; no personal identifiers.
from PIL import Image,ImageDraw
im=Image.new('RGB',(180,180),'#0c1728'); d=ImageDraw.Draw(im)
d.rounded_rectangle((22,49,158,132),radius=15,fill='#5de0cc')
for y in (65,84,103):
 for x in range(37,144,22): d.rounded_rectangle((x,y,x+13,y+10),radius=2,fill='#0c1728')
d.rounded_rectangle((58,120,122,125),radius=2,fill='#0c1728')
for size,name in ((120,'Icon60@2x.png'),(180,'Icon60@3x.png')): im.resize((size,size)).save(app/name)
info['CFBundleIcons']={'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon60'],'UIPrerenderedIcon':True}}
plistlib.dump(info,(app/'Info.plist').open('wb'))
