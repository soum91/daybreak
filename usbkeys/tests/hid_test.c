#include "../src/HID.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
  uint8_t k,m;
  assert(UKASCII('0',&k,&m)&&k==0x27&&m==0);
  for(int c='1';c<='9';c++) assert(UKASCII(c,&k,&m)&&k==c-'1'+0x1e&&m==0);
  assert(UKASCII('a',&k,&m)&&k==4&&m==0);
  assert(UKASCII('Z',&k,&m)&&k==29&&m==2);
  assert(UKASCII('!',&k,&m)&&k==0x1e&&m==2);
  assert(UKASCII('?',&k,&m)&&k==0x38&&m==2);
  assert(UKASCII('\n',&k,&m)&&k==0x28);
  assert(UKASCII('\b',&k,&m)&&k==0x2a);
  assert(!UKASCII(0,&k,&m)); assert(!UKASCII(0x09ac,&k,&m));
  for(unsigned c=32;c<127;c++) assert(UKASCII(c,&k,&m)&&k>=4&&k<=0x65);
  // Every descriptor item must be completely present.
  for(size_t i=0;i<sizeof(UKReportDescriptor);) {
    unsigned prefix=UKReportDescriptor[i++]; assert(prefix!=0xfe);
    unsigned n=prefix&3; if(n==3)n=4; assert(i+n<=sizeof(UKReportDescriptor)); i+=n;
  }
  puts("US ASCII mappings and descriptor item boundaries passed.");
}
