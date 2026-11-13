#include <assert.h>
#include <stdio.h>
#include "../src/HIDControl.h"
int main(void) {
  UKHIDState s={1,0}; uint8_t data[4096]; size_t n;
  assert(UKHIDRequest(&s,0xa1,3,0,0,1,data,&n)&&n==1&&data[0]==1);
  assert(UKHIDRequest(&s,0x21,11,0,0,0,data,&n)&&n==0&&s.protocol==0);
  assert(UKHIDRequest(&s,0xa1,3,0,0,1,data,&n)&&data[0]==0);
  assert(UKHIDRequest(&s,0x21,11,1,0,0,data,&n)&&s.protocol==1);
  assert(!UKHIDRequest(&s,0x21,11,2,0,0,data,&n)&&s.protocol==1);
  assert(UKHIDRequest(&s,0x21,10,0x1e00,0,0,data,&n)&&s.idle==30);
  assert(UKHIDRequest(&s,0xa1,2,0,0,1,data,&n)&&n==1&&data[0]==30);
  assert(UKHIDRequest(&s,0x21,10,0,0,0,data,&n)&&s.idle==0);
  assert(!UKHIDRequest(&s,0x21,10,1,0,0,data,&n));
  memset(data,0xff,sizeof(data));
  assert(UKHIDRequest(&s,0xa1,1,0x100,0,8,data,&n)&&n==8);
  for(unsigned i=0;i<8;i++) assert(data[i]==0);
  assert(UKHIDRequest(&s,0xa1,1,0x100,0,4,data,&n)&&n==4);
  assert(!UKHIDRequest(&s,0xa1,1,0x101,0,8,data,&n));
  assert(!UKHIDRequest(&s,0xa1,1,0x300,0,8,data,&n));
  assert(UKHIDRequest(&s,0x21,9,0x200,0,1,data,&n)&&n==1);
  assert(!UKHIDRequest(&s,0x21,9,0x200,0,4096,data,&n));
  assert(!UKHIDRequest(&s,0x21,9,0x100,0,8,data,&n));
  assert(UKHIDRequest(&s,0x81,6,0x2200,0,4096,data,&n)&&n==sizeof(UKReportDescriptor));
  assert(!memcmp(data,UKReportDescriptor,n));
  assert(UKHIDRequest(&s,0x81,6,0x2200,0,10,data,&n)&&n==10);
  assert(UKHIDRequest(&s,0x81,6,0x2100,0,9,data,&n)&&n==9&&data[6]==0x22&&data[7]==sizeof(UKReportDescriptor));
  assert(!UKHIDRequest(&s,0xa1,3,0,1,1,data,&n));
  assert(!UKHIDRequest(&s,0x80,3,0,0,1,data,&n));
  assert(!UKHIDRequest(&s,0x21,3,0,0,1,data,&n));
  assert(!UKHIDRequest(&s,0xa1,255,0,0,1,data,&n));
  puts("PASS: HID control requests, boot/report switching, idle state, short descriptors and malformed requests");
}
