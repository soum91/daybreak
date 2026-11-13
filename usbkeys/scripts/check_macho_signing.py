"""Reject signature commands overwriting executable sections; compare code bytes."""
import struct,sys
from pathlib import Path

def inspect(path):
 data=Path(path).read_bytes()
 magic,_,_,_,count,commands_size,_,_=struct.unpack_from('<8I',data)
 assert magic==0xfeedfacf, 'Expected thin arm64 Mach-O'
 header_end=32+commands_size; offset=32; code={}; signature=False
 for _ in range(count):
  cmd,size=struct.unpack_from('<II',data,offset)
  assert size>=8 and offset+size<=header_end, 'Invalid load command'
  signature|=cmd==0x1d
  if cmd==0x19:
   for i in range(struct.unpack_from('<I',data,offset+64)[0]):
    section=offset+72+i*80
    name=data[section:section+16].split(b'\0')[0].decode()
    segment=data[section+16:section+32].split(b'\0')[0].decode()
    length,start=struct.unpack_from('<QI',data,section+40)
    if segment=='__TEXT' and start and length:
     assert start>=header_end, f'{path}: load commands overlap {name}: {header_end:#x} > {start:#x}'
     assert start+length<=len(data), 'Truncated text section'
     code[name]=data[start:start+length]
  offset+=size
 assert offset==header_end and '__text' in code
 return code,signature

if __name__=='__main__':
 if len(sys.argv)==2:
  inspect(sys.argv[1]); print('Mach-O section boundaries passed')
 else:
  before,_=inspect(sys.argv[1]); after,signed=inspect(sys.argv[2])
  assert signed, 'Signature load command missing'
  assert before==after, 'Signing changed __TEXT section contents'
  print('PASS: signing preserved all __TEXT sections; load commands do not overlap code')
