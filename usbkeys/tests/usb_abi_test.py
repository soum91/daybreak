"""Validate the used selectors against the actual 20B101 USB kext dispatcher.

Usage: python3 tests/usb_abi_test.py /path/to/com.apple.iokit.IOUSBDeviceFamily
The proprietary kernel/kext is deliberately not distributed with this project.
"""
import struct,sys
from pathlib import Path
b=Path(sys.argv[1]).read_bytes()
assert struct.unpack_from('<I',b)[0]==0xfeedfacf
segs=[];offset=32
for _ in range(struct.unpack_from('<I',b,16)[0]):
 command,size=struct.unpack_from('<II',b,offset)
 if command==0x19:segs.append(struct.unpack_from('<QQQQ',b,offset+24))
 offset+=size
address=0xfffffff007c138d8 # IOUSBDeviceInterfaceUserClient::sMethods, 20B101
for vm,vmsize,fileoff,filesize in segs:
 if vm<=address<vm+filesize:
  table=fileoff+address-vm;break
else:raise AssertionError('20B101 sMethods address absent; this test requires the stated build')
expected={0:(1,0,0,0),1:(0,0,0,0),3:(2,0,0,0),4:(2,0,0,0),5:(2,0,0,0),6:(2,0xffffffff,0,0),7:(2,0xffffffff,0,0),8:(3,0,0,0),9:(0xffffffff,0,0,0),24:(0,0,2,0),10:(6,0,1,0),11:(0,0,0,0),14:(4,0,1,0),18:(1,0,3,0),19:(1,0,0,0)}
for index,counts in expected.items():
 pointer,*actual=struct.unpack_from('<Q4I',b,table+24*index)
 assert pointer and tuple(actual)==counts,(index,actual,counts)
print(f'PASS: {len(expected)} used selectors match the native iOS 16.1.1 20B101 argument counts')
