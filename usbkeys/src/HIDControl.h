#pragma once
#include "HID.h"
typedef struct { uint8_t protocol, idle; } UKHIDState;
// Only interface 0 exists. No report IDs. Never retain host payloads or keys.
static inline bool UKHIDRequest(UKHIDState *state, uint8_t type, uint8_t request,
 uint16_t value, uint16_t index, uint16_t length, uint8_t *data, size_t *size) {
  *size=0;
  if(index!=0) return false;
  if(type==0x81 && request==6 && (value&255)==0) {
    if(value==0x2200) { memcpy(data,UKReportDescriptor,sizeof(UKReportDescriptor)); *size=sizeof(UKReportDescriptor); }
    else if(value==0x2100) {
      const uint8_t hid[]={9,0x21,0x11,1,0,1,0x22,sizeof(UKReportDescriptor),0};
      memcpy(data,hid,sizeof(hid)); *size=sizeof(hid);
    } else return false;
  } else if(type==0xa1) {
    switch(request) {
      case 1: // GET_REPORT: no key remains held between explicit taps.
        if(value==0x100) { memset(data,0,8); *size=8; }
        else if(value==0x200) { data[0]=0; *size=1; }
        else return false;
        break;
      case 2: if(value) return false; data[0]=state->idle; *size=1; break;
      case 3: if(value) return false; data[0]=state->protocol; *size=1; break;
      default: return false;
    }
  } else if(type==0x21) {
    switch(request) {
      case 9: // SET_REPORT: receive and discard the one-byte LED report.
        if(value!=0x200 || length!=1) return false;
        data[0]=0; *size=1; break;
      case 10:
        if((value&255)||length) return false;
        state->idle=value>>8; break;
      case 11:
        if(value>1||length) return false;
        state->protocol=value; break;
      default: return false;
    }
  } else return false;
  if(*size>length) *size=length;
  return true;
}
