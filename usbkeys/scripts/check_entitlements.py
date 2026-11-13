"""Check the actual signed helper, not just the input entitlement plist."""
import os,plistlib,subprocess,sys
ent=plistlib.loads(subprocess.check_output([os.environ['LDID'],'-e',sys.argv[1]]))
assert 'com.apple.private.iokit-user-client-class' not in ent, 'Obsolete/wrong user-client entitlement key'
assert ent.get('com.apple.security.exception.iokit-user-client-class')==['IOUSBDeviceInterfaceUserClient']
assert ent.get('com.apple.security.device.usb') is True
assert ent.get('com.apple.private.usbdevice.setdescription') is True
print('PASS: signed USB helper contains the intended scoped entitlements')
