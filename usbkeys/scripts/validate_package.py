import plistlib,struct,subprocess
from pathlib import Path
from check_macho_signing import inspect
stage=Path(__file__).resolve().parents[1]/'build/stage'
for binary in ['var/jb/Applications/USBKeys.app/USBKeys','var/jb/usr/libexec/usbkeysd']:
 data=(stage/binary).read_bytes()
 inspect(stage/binary)
 magic,cpu,_,kind,ncmds,_,_,_=struct.unpack_from('<8I',data)
 assert magic==0xfeedfacf and cpu==0x100000c and kind==2
 offset=32; platform=False; signed=False
 for _ in range(ncmds):
  cmd,size=struct.unpack_from('<II',data,offset); assert size>=8
  if cmd==0x32:
   p,minos=struct.unpack_from('<II',data,offset+8)
   assert p==2 and minos==0x100100, (p,hex(minos))
   platform=True
  if cmd==0x1d: signed=True
  if cmd in [0xc,0x80000018,0x8000001f]:
   nameoff=struct.unpack_from('<I',data,offset+8)[0]
   name=data[offset+nameoff:offset+size].split(b'\0')[0].decode()
   assert name.startswith(('/usr/lib/','/System/Library/')), name
  offset+=size
 assert platform and signed
 print(binary+': signed arm64, iOS 16.1, system-only dylib paths')
for f in stage.rglob('*.plist'):
 with f.open('rb') as h: plistlib.load(h)
control=Path(__file__).resolve().parents[1]/'packaging/control'
version=next(line.split(': ',1)[1] for line in control.read_text().splitlines() if line.startswith('Version: '))
result=subprocess.check_output(['dpkg-deb','--contents',str(stage.parents[1]/f'dist/dev.usbkeys.keyboard_{version}_iphoneos-arm64.deb')],text=True)
assert './var/jb/' in result
print('Package metadata and plists passed.')
