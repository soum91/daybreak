// Native callback packing verified against iPhone14,3 20B101 USBDeviceFamily.
// Selector discovery: shinyquagsire23/libusbd, MIT; see third-party license.
#import <Foundation/Foundation.h>
#include "USBControl.h"
#include "HIDControl.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <dispatch/dispatch.h>
struct UKUSBControl {
  io_connect_t port;
  IONotificationPortRef notification;
  uint8_t *buffer;
  uint64_t token;
  pthread_t thread;
  pthread_mutex_t lock;
  bool started;
  atomic_bool stopping;
  dispatch_semaphore_t ready;
  UKHIDState hid;
  UKControlStats stats;
};
static void UKControlCallback(void *refcon, IOReturn result, uint64_t *args, uint32_t count) {
  UKUSBControl *c=refcon;
  if(result || count<5) {
    pthread_mutex_lock(&c->lock); c->stats.failures++; c->stats.lastError=result?:kIOReturnBadArgument; pthread_mutex_unlock(&c->lock); return;
  }
  // Native stage 0 is setup, 1 is IN completion, 2 is OUT data completion.
  // Stage 1 must not be completed a second time. Stage 2 needs status + token.
  if(args[0]==1) {
    pthread_mutex_lock(&c->lock);
    if(count<6||args[5]) { c->stats.failures++; c->stats.lastError=count<6?kIOReturnBadArgument:(IOReturn)args[5]; }
    else c->stats.completed++;
    pthread_mutex_unlock(&c->lock); return;
  }
  if(args[0]==2) {
    if(count<6) {
      pthread_mutex_lock(&c->lock); c->stats.failures++; c->stats.lastError=kIOReturnBadArgument; pthread_mutex_unlock(&c->lock); return;
    }
    uint64_t done[]={args[5],args[4]};
    IOReturn r=IOConnectCallScalarMethod(c->port,9,done,2,NULL,NULL);
    memset(c->buffer,0,4096); // discard received LED data
    pthread_mutex_lock(&c->lock);
    if(r||args[5]) { c->stats.failures++; c->stats.lastError=r?:(IOReturn)args[5]; }
    else c->stats.completed++;
    pthread_mutex_unlock(&c->lock); return;
  }
  if(args[0]!=0) return;
  uint8_t type=args[1]>>24, request=args[1]>>16;
  uint16_t value=args[1], index=args[2]>>16, length=args[2]; size_t size=0;
  memset(c->buffer,0,4096);
  pthread_mutex_lock(&c->lock);
  c->stats.requests++;
  if(type==0xa1&&request==1) c->stats.getReport++;
  if(type==0x21&&request==9) c->stats.setReport++;
  if(type==0xa1&&request==2) c->stats.getIdle++;
  if(type==0x21&&request==10) c->stats.setIdle++;
  if(type==0xa1&&request==3) c->stats.getProtocol++;
  if(type==0x21&&request==11) c->stats.setProtocol++;
  if(type==0x81&&request==6) c->stats.descriptor++;
  bool handled=UKHIDRequest(&c->hid,type,request,value,index,length,c->buffer,&size);
  if(!handled) c->stats.rejected++;
  c->stats.protocol=c->hid.protocol; c->stats.idle=c->hid.idle;
  pthread_mutex_unlock(&c->lock);
  // Native: handled, buffer length, mapped address, status, transaction token.
  uint64_t done[]={handled,size,(uint64_t)c->buffer,0,args[4]};
  IOReturn r=IOConnectCallScalarMethod(c->port,9,done,5,NULL,NULL);
  pthread_mutex_lock(&c->lock);
  if(r) { c->stats.failures++; c->stats.lastError=r; }
  else if(handled) c->stats.replies++;
  pthread_mutex_unlock(&c->lock);
}
static void *UKControlThread(void *refcon) { @autoreleasepool {
  UKUSBControl *c=refcon;
  CFRunLoopSourceRef source=IONotificationPortGetRunLoopSource(c->notification);
  CFRunLoopAddSource(CFRunLoopGetCurrent(),source,kCFRunLoopDefaultMode);
  dispatch_semaphore_signal(c->ready);
  while(!atomic_load(&c->stopping)) CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.05,false);
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(),source,kCFRunLoopDefaultMode);
  return NULL;
}}
UKControlStats UKControlRead(UKUSBControl *c) {
  UKControlStats s={0}; if(!c) return s;
  pthread_mutex_lock(&c->lock); s=c->stats; pthread_mutex_unlock(&c->lock); return s;
}
void UKControlStop(UKUSBControl *c) {
  if(!c) return;
  atomic_store(&c->stopping,true);
  if(c->started) pthread_join(c->thread,NULL); // no callbacks can outlive the buffer
  if(c->notification) IONotificationPortDestroy(c->notification);
  if(c->token) { uint64_t a[]={c->token}; IOConnectCallScalarMethod(c->port,19,a,1,NULL,NULL); }
  c->ready=NULL;
  pthread_mutex_destroy(&c->lock); free(c);
}
IOReturn UKControlStart(io_connect_t port, UKUSBControl **out) {
  *out=NULL;
  UKUSBControl *c=calloc(1,sizeof(*c)); if(!c) return kIOReturnNoMemory;
  c->port=port; c->hid.protocol=1; c->stats.protocol=1;
  atomic_init(&c->stopping,false); pthread_mutex_init(&c->lock,NULL);
  uint64_t size[]={4096}, mapped[3]={0}; uint32_t n=3;
  IOReturn r=IOConnectCallScalarMethod(port,18,size,1,mapped,&n);
  if(r||n!=3||!mapped[0]||mapped[1]<4096||!mapped[2]) { UKControlStop(c); return r?:kIOReturnNoMemory; }
  c->buffer=(uint8_t *)mapped[0]; c->token=mapped[2];
  c->notification=IONotificationPortCreate(0);
  if(!c->notification||!IONotificationPortGetRunLoopSource(c->notification)) { UKControlStop(c); return kIOReturnNoResources; }
  mach_port_t wake=IONotificationPortGetMachPort(c->notification);
  if(!wake) { UKControlStop(c); return kIOReturnNoResources; }
  c->ready=dispatch_semaphore_create(0);
  if(pthread_create(&c->thread,NULL,UKControlThread,c)) { UKControlStop(c); return kIOReturnNoResources; }
  c->started=true;
  dispatch_semaphore_wait(c->ready,DISPATCH_TIME_FOREVER);
  uint64_t args[]={1,0,0}, reference[8]={0};
  reference[kIOAsyncReservedIndex]=wake;
  reference[kIOAsyncCalloutFuncIndex]=(uint64_t)UKControlCallback;
  reference[kIOAsyncCalloutRefconIndex]=(uint64_t)c;
  r=IOConnectCallAsyncScalarMethod(port,8,wake,reference,8,args,3,NULL,NULL);
  if(r) { UKControlStop(c); return r; }
  *out=c; return KERN_SUCCESS;
}
