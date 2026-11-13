#import "Backend.h"
#import "HID.h"
#import "Journal.h"
#import "USBControl.h"
#include <time.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <unistd.h>
#include <dispatch/dispatch.h>

// Selectors originate in shinyquagsire23/libusbd (MIT). The dispatcher argument
// counts were also checked against iPhone14,3 iOS 16.1.1 (20B101)'s native
// IOUSBDeviceInterfaceUserClient::sMethods. Physical USB operation is unverified.
typedef CFTypeRef Desc;
typedef CFTypeRef Controller;
static IOReturn (*Create)(CFAllocatorRef,Controller *);
static Desc (*Snapshot)(CFAllocatorRef,Controller);
static void (*Clear)(Desc);
static int (*AddConfig)(Desc,CFStringRef,uint8_t,uint8_t);
static int (*AddInterface)(Desc,int,CFStringRef);
static IOReturn (*Publish)(Controller,Desc);
static IOReturn (*Reenumerate)(Controller,uint32_t);
static void (*SetPID)(Desc,uint16_t);
static void (*SetClass)(Desc,uint8_t);
static io_service_t (*GetService)(Controller);

@implementation UKBackend {
  UKUSBControl *_control;
  double _lastReportTime;
  Controller _controller;
  Desc _saved;
  io_connect_t _port;
  uint64_t _pipe, _token;
  void *_buffer;
  BOOL _changed, _active;
  NSMutableArray<NSString *> *_events;
  NSString *_controlSummary;
  NSString *_phase, *_message, *_operation, *_previous;
  BOOL _pending, _previousChanged, _createHung, _exitRequested;
}
- (instancetype)init {
  if((self=[super init])) {
    _events=[NSMutableArray array]; _phase=@"Service ready"; _message=@"Service ready. Tap Check USB or Start."; _operation=@"idle";
    NSDictionary *old=UKReadJournal();
    if([old[@"pending"] boolValue]||[old[@"changed"] boolValue]||[old[@"hung"] boolValue]) {
      _previous=[NSString stringWithFormat:@"Previous service ended at: %@\n%@",old[@"phase"]?:@"unknown",old[@"diagnostics"]?:@""];
      if(_previous.length>8000) _previous=[_previous substringFromIndex:_previous.length-8000];
      _previousChanged=[old[@"changed"] boolValue]&&[old[@"boot"] longLongValue]>0&&[old[@"boot"] isEqual:UKBootSession()];
    }
    [self persist];
  }
  return self;
}
- (BOOL)active { return _active; }
- (NSDictionary *)state {
  NSString *diagnostics=[_events componentsJoinedByString:@"\n"];
  if(_port && _control) {
    UKControlStats stats=UKControlRead(_control);
    uint64_t driver[2]={0}; uint32_t count=2;
    IOReturn r=IOConnectCallScalarMethod(_port,24,NULL,0,driver,&count);
    _controlSummary=[NSString stringWithFormat:@"Host control requests: %llu; setup replies submitted: %llu; data completions: %llu; rejected: %llu; errors: %llu (last 0x%08x)\nGET_REPORT %llu; SET_REPORT %llu; GET_IDLE %llu; SET_IDLE %llu; GET_PROTOCOL %llu; SET_PROTOCOL %llu; descriptor callbacks %llu\nHID protocol: %@; idle: %u ms\nNative interface active: %@; driver state: %lld; query: 0x%08x\nLocal setup and USB transport do not prove target text input.",stats.requests,stats.replies,stats.completed,stats.rejected,stats.failures,stats.lastError,stats.getReport,stats.setReport,stats.getIdle,stats.setIdle,stats.getProtocol,stats.setProtocol,stats.descriptor,stats.protocol?@"report":@"boot",stats.idle*4,(!r&&count==2)?(driver[0]?@"YES":@"NO"):@"unknown",(long long)driver[1],r];
  }
  if(_controlSummary.length) diagnostics=[diagnostics stringByAppendingFormat:@"\n%@",_controlSummary];
  if(_previous.length) diagnostics=[NSString stringWithFormat:@"%@\n\n%@",_previous,diagnostics];
  return @{@"active":@(_active),@"changed":@(_changed||_previousChanged),@"pending":@(_pending),@"phase":_phase?:@"unknown",@"operation":_operation?:@"unknown",@"message":_message?:@"No result",@"diagnostics":diagnostics,@"hung":@(_createHung),@"version":@"0.1.5 (6)",@"pid":@(getpid()),@"boot":UKBootSession(),@"time":@([[NSDate date] timeIntervalSince1970])};
}
- (void)persist { UKWriteJournal([self state]); }
- (void)note:(NSString *)text {
  if(_events.count>=80) [_events removeObjectAtIndex:0];
  [_events addObject:text]; [self persist];
}
- (void)mark:(NSString *)step {
  _phase=step; _pending=YES; _message=[NSString stringWithFormat:@"Running: %@",step];
  [self note:[@"BEGIN: " stringByAppendingString:step]];
}
- (void)begin:(NSString *)operation {
  [_events removeAllObjects]; _operation=operation;
  if([operation isEqual:@"Start"]) _controlSummary=nil;
  [self mark:[@"Operation " stringByAppendingString:operation]];
}
- (void)log:(NSString *)step code:(IOReturn)code {
  _phase=step; _pending=NO;
  [self note:[NSString stringWithFormat:@"%@: 0x%08x",step,code]];
}
- (NSDictionary *)result:(BOOL)ok message:(NSString *)message {
  _pending=NO; _message=message; [self persist];
  NSMutableDictionary *r=[[self state] mutableCopy]; r[@"ok"]=@(ok); return r;
}
- (NSDictionary *)status { return [self state]; }
- (NSDictionary *)exception:(NSString *)name { _active=NO; return [self result:NO message:[NSString stringWithFormat:@"Service exception %@ during %@. Keys disabled; use Stop. No input retried.",name,_phase]]; }
- (void)registry:(Controller)c {
  // Only controller class and property NAMES/types, never values or identifiers.
  if(!GetService) return;
  io_service_t service=GetService(c); if(!service) return;
  io_name_t cls={0}; if(IOObjectGetClass(service,cls)==KERN_SUCCESS) [self note:[NSString stringWithFormat:@"Controller class: %s",cls]];
  CFMutableDictionaryRef props=NULL;
  if(IORegistryEntryCreateCFProperties(service,&props,NULL,0)==KERN_SUCCESS&&props) {
    NSDictionary *dictionary=(__bridge NSDictionary *)props;
    for(id key in [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
      if(![key isKindOfClass:NSString.class]) continue;
      NSString *lower=[key lowercaseString];
      if([lower containsString:@"config"]||[lower containsString:@"function"]||[lower containsString:@"mode"]||[lower containsString:@"state"]||[lower containsString:@"description"])
        [self note:[NSString stringWithFormat:@"Registry property present: %@ (%@)",key,NSStringFromClass([dictionary[key] class])]];
    }
    CFRelease(props);
  }
}
- (Desc)snapshot:(Controller)c stage:(NSString *)stage {
  [self mark:stage]; Desc d=Snapshot(NULL,c); _pending=NO;
  [self note:[NSString stringWithFormat:@"%@: %@",stage,d?@"returned a description":@"returned NULL; API provides no error code"]];
  return d;
}
- (void)permissions {
  [self note:[NSString stringWithFormat:@"Service UID/EUID: %u/%u",getuid(),geteuid()]];
  dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_NOW|RTLD_GLOBAL);
  CFTypeRef (*taskCreate)(CFAllocatorRef)=dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf");
  CFTypeRef (*copyEntitlement)(CFTypeRef,CFStringRef,CFErrorRef *)=dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
  if(!taskCreate||!copyEntitlement) { [self note:@"Runtime entitlement query unavailable"]; return; }
  CFTypeRef task=taskCreate(NULL); if(!task) { [self note:@"Runtime entitlement task unavailable"]; return; }
  for(NSString *key in @[@"com.apple.private.usbdevice.setdescription",@"com.apple.security.device.usb",@"com.apple.security.exception.iokit-user-client-class"]) {
    CFTypeRef value=copyEntitlement(task,(__bridge CFStringRef)key,NULL);
    BOOL granted=NO;
    if(value&&CFGetTypeID(value)==CFBooleanGetTypeID()) granted=CFBooleanGetValue(value);
    else if(value&&CFGetTypeID(value)==CFArrayGetTypeID()) granted=[(__bridge NSArray *)value containsObject:@"IOUSBDeviceInterfaceUserClient"];
    [self note:[NSString stringWithFormat:@"Runtime permission %@: %@",key,granted?@"granted":@"missing or not granted"]];
    if(value) CFRelease(value);
  }
  CFRelease(task);
}
- (BOOL)loadAPI {
  const char *paths[]={"/System/Library/Frameworks/IOKit.framework/IOKit","/usr/lib/libIOUSBDevice.dylib","/System/Library/PrivateFrameworks/IOUSBDeviceFamily.framework/IOUSBDeviceFamily"};
  for(unsigned i=0;i<3;i++) dlopen(paths[i],RTLD_NOW|RTLD_GLOBAL);
#define LOAD(var,name) do { *(void **)(&var)=dlsym(RTLD_DEFAULT,name); if(!var) { [_events addObject:@"Missing symbol: " @name]; return NO; } } while(0)
  LOAD(Create,"IOUSBDeviceControllerCreate");
  LOAD(Snapshot,"IOUSBDeviceDescriptionCreateFromController");
  LOAD(Clear,"IOUSBDeviceDescriptionRemoveAllConfigurations");
  LOAD(AddConfig,"IOUSBDeviceDescriptionAppendConfiguration");
  LOAD(AddInterface,"IOUSBDeviceDescriptionAppendInterfaceToConfiguration");
  LOAD(Publish,"IOUSBDeviceControllerSetDescription");
  LOAD(Reenumerate,"IOUSBDeviceControllerGoOffAndOnBus");
  LOAD(SetPID,"IOUSBDeviceDescriptionSetProductID");
  LOAD(SetClass,"IOUSBDeviceDescriptionSetClass");
  *(void **)(&GetService)=dlsym(RTLD_DEFAULT,"IOUSBDeviceControllerGetService");
  [self permissions];
#undef LOAD
  return YES;
}
- (BOOL)exitRequested { return _exitRequested; }
// Read-only: list IOService class NAMES related to USB device mode. No values.
- (void)scanServices {
  [self mark:@"Scan USB device-mode services (read-only)"];
  io_service_t ctl=IOServiceGetMatchingService(0,IOServiceMatching("IOUSBDeviceController"));
  [self note:[NSString stringWithFormat:@"IOUSBDeviceController service: %@",ctl?@"present":@"NOT FOUND"]];
  if(ctl) IOObjectRelease(ctl);
  io_iterator_t it=0;
  if(IORegistryCreateIterator(0,kIOServicePlane,kIORegistryIterateRecursively,&it)!=KERN_SUCCESS) { [self note:@"Registry scan unavailable"]; return; }
  NSCountedSet *found=[NSCountedSet set]; io_object_t o; unsigned total=0;
  while((o=IOIteratorNext(it))) {
    total++; io_name_t cls={0};
    if(IOObjectGetClass(o,cls)==KERN_SUCCESS) {
      NSString *c=[[NSString stringWithUTF8String:cls] lowercaseString];
      if([c containsString:@"usbdevice"]||[c containsString:@"otg"]||[c containsString:@"synopsys"]||[c containsString:@"dwc"]||[c containsString:@"usbmux"]||[c containsString:@"usbxhci"]||[c containsString:@"tristar"]||[c containsString:@"hydra"]||[c containsString:@"usbport"])
        [found addObject:[NSString stringWithUTF8String:cls]];
    }
    IOObjectRelease(o);
  }
  IOObjectRelease(it);
  [self note:[NSString stringWithFormat:@"Registry entries scanned: %u",total]];
  unsigned listed=0;
  for(NSString *c in [[found allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
    if(listed++>=40) { [self note:@"(more classes omitted)"]; break; }
    [self note:[NSString stringWithFormat:@"Class %@ x%lu",c,(unsigned long)[found countForObject:c]]];
  }
  if(!found.count) [self note:@"No USB device-mode classes matched"];
  _phase=@"Scan USB device-mode services (read-only)"; _pending=NO;
}
// Create can block forever on iOS. Run it with a deadline; a late return is leaked.
- (IOReturn)createController:(Controller *)out {
  *out=NULL;
  if(_createHung) return kIOReturnBusy;
  [self mark:@"Create controller (4 s deadline)"];
  __block Controller c=NULL; __block IOReturn r=kIOReturnTimeout;
  dispatch_semaphore_t done=dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{ Controller tmp=NULL; IOReturn rr=Create(NULL,&tmp); c=tmp; r=rr; dispatch_semaphore_signal(done); });
  if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC))) {
    _createHung=YES; _exitRequested=YES;
    [self note:@"Create controller: DID NOT RETURN within 4 s (hung inside IOUSBDeviceControllerCreate). Service will restart after this reply."];
    _phase=@"Create controller hung"; _pending=NO;
    return kIOReturnTimeout;
  }
  [self log:@"Create controller" code:r];
  *out=c; return r;
}
- (NSDictionary *)probe {
  if(_active) return [self result:YES message:@"USB keyboard configured. Use a harmless text field to test."];
  [self begin:@"Check USB"];
  if(![self loadAPI]) return [self result:NO message:@"USB device API unavailable. No USB settings changed."];
  [self scanServices];
  Controller c=NULL; IOReturn r=[self createController:&c];
  if(r==kIOReturnTimeout) return [self result:NO message:@"BLOCKED: IOUSBDeviceControllerCreate hung for 4 s. No USB settings changed. Copy diagnostics (service list) and send them."];
  if(r||!c) return [self result:NO message:@"Cannot access device-mode controller. No USB settings changed."];
  [self registry:c];
  Desc d=[self snapshot:c stage:@"Capture current USB description (read-only)"];
  [self mark:@"Release read-only controller objects"];
  if(d) CFRelease(d); CFRelease(c);
  return [self result:d!=NULL message:d?@"CHECK ONLY: controller and snapshot available. Tap Start to attempt keyboard setup.":@"BLOCKED: current USB description is unavailable. Keyboard setup cannot preserve the original configuration. No USB settings changed."];
}
- (IOReturn)scalar:(uint32_t)selector args:(const uint64_t *)args count:(uint32_t)count {
  return IOConnectCallScalarMethod(_port,selector,args,count,NULL,NULL);
}
- (void)closePort {
  if(_control) { [self state]; UKControlStop(_control); _control=NULL; }
  if(_port) {
    if(_token) { uint64_t a[]={_token}; [self scalar:19 args:a count:1]; }
    [self scalar:1 args:NULL count:0]; IOServiceClose(_port);
  }
  _port=0; _token=0; _buffer=NULL; _pipe=0; _active=NO;
}
- (NSDictionary *)stop {
  _operation=@"Stop"; [self mark:@"Close keyboard interface"];
  [self closePort];
  if(_changed&&_saved&&_controller) {
    IOReturn r=Publish(_controller,_saved); [self log:@"Restore original USB description" code:r];
    if(r) return [self result:NO message:@"Restore failed. Unplug cable and reboot the 13 Pro Max to restore its stock USB stack."];
    r=Reenumerate(_controller,250); [self log:@"Restore re-enumeration" code:r];
    if(r) return [self result:NO message:@"Original description restored, but reconnect failed. Unplug and reconnect the cable."];
    _changed=NO;
  }
  if(_saved) { CFRelease(_saved); _saved=NULL; }
  if(_controller) { CFRelease(_controller); _controller=NULL; }
  return [self result:YES message:@"Stopped. Original USB description restored when needed."];
}
- (NSDictionary *)failed:(NSString *)why {
  NSString *operation=_operation, *phase=_phase;
  [self note:[@"FAILURE: " stringByAppendingString:why]];
  NSDictionary *cleanup=[self stop];
  _operation=operation; _phase=[@"Failed at: " stringByAppendingString:phase?:@"unknown"];
  return [self result:NO message:[NSString stringWithFormat:@"%@ %@",why,cleanup[@"message"]]];
}
- (NSDictionary *)start {
  if(_active) return [self result:YES message:@"Already configured."];
  if(_changed) return [self result:NO message:@"Restore the previous session using Stop first."];
  [self begin:@"Start"];
  if(_previousChanged) return [self result:NO message:@"Previous service ended after USB publication. Its restoration snapshot was lost. Disconnect and restart the source iPhone before another attempt."];
  if(![self loadAPI]) return [self result:NO message:@"Required USB symbols missing. No changes made."];
  [self scanServices];
  IOReturn r=[self createController:&_controller];
  if(r==kIOReturnTimeout) return [self result:NO message:@"BLOCKED: IOUSBDeviceControllerCreate hung for 4 s. No USB settings changed, no keyboard published. Copy diagnostics (service list) and send them."];
  if(r||!_controller) return [self failed:@"Controller access failed."];
  [self registry:_controller];
  _saved=[self snapshot:_controller stage:@"Capture original USB configuration for restoration"];
  if(!_saved) return [self failed:@"BLOCKED: original USB configuration capture returned NULL. No keyboard was published."];
  Desc edited=[self snapshot:_controller stage:@"Capture independent working USB description"];
  if(!_saved||!edited) { if(edited) CFRelease(edited); return [self failed:@"USB snapshot failed. No configuration published."]; }
  if(_saved==edited) { CFRelease(edited); return [self failed:@"Snapshot API returned the same object twice. Cannot preserve an independent restoration snapshot."]; }
  [self mark:@"Prepare keyboard description"];
  Clear(edited); SetClass(edited,0); SetPID(edited,0x1337);
  int cfg=AddConfig(edited,CFSTR("USBKeys experimental keyboard"),0x80,50);
  if(cfg<0||AddInterface(edited,cfg,CFSTR("USBKeysKeyboard"))<0) { CFRelease(edited); return [self failed:@"Cannot describe keyboard interface."]; }
  // Mark before call: even a failing private call could have changed state.
  _changed=YES; [self mark:@"Publish keyboard description"];
  r=Publish(_controller,edited); CFRelease(edited);
  [self log:@"Publish keyboard description" code:r];
  if(r) return [self failed:@"USB publication rejected. An entitlement or driver restriction may block this port."];
  io_service_t service=0;
  [self mark:@"Wait for USBKeysKeyboard interface"];
  for(int attempt=0;attempt<30&&!service;attempt++) {
    NSMutableDictionary *m=[@{@"IOProviderClass":@"IOUSBDeviceInterface",@"IOPropertyMatch":@{@"USBDeviceFunction":@"USBKeysKeyboard"}} mutableCopy];
    service=IOServiceGetMatchingService(0,(__bridge_retained CFDictionaryRef)m);
    if(!service) usleep(100000);
  }
  if(!service) return [self failed:@"Kernel did not create a userspace USB interface."];
  CFTypeRef clientClass=IORegistryEntryCreateCFProperty(service,CFSTR("IOUserClientClass"),NULL,0);
  if(clientClass&&CFGetTypeID(clientClass)==CFStringGetTypeID()) [self note:[@"Kernel interface user-client class: " stringByAppendingString:(__bridge NSString *)clientClass]];
  else [self note:@"Kernel interface does not advertise a string IOUserClientClass"];
  if(clientClass) CFRelease(clientClass);
  [self mark:@"Open interface user client type 123"];
  r=IOServiceOpen(service,mach_task_self(),123,&_port); IOObjectRelease(service);
  [self log:@"Open interface user client type 123" code:r];
  if(r) {
    NSString *reason=@"kernel open failure";
    if(r==kIOReturnNotPrivileged||r==kIOReturnNotPermitted) reason=@"permission denied";
    else if(r==kIOReturnUnsupported) reason=@"request rejected as unsupported";
    else if(r==kIOReturnExclusiveAccess) reason=@"interface already held exclusively";
    else if(r==kIOReturnNoDevice||r==kIOReturnNotFound) reason=@"interface disappeared or was not found";
    return [self failed:[NSString stringWithFormat:@"USB user-client open failed: 0x%08x (%@).",r,reason]];
  }
  uint64_t open[]={0};
  [self mark:@"Open interface"];
  r=[self scalar:0 args:open count:1]; [self log:@"Open interface" code:r];
  if(r) return [self failed:@"Interface open rejected."];
  for(unsigned sel=3;sel<=5;sel++) {
    uint64_t a[]={sel==3?3:1,(uint64_t)cfg};
    [self mark:[NSString stringWithFormat:@"Set interface field %u",sel]];
    r=[self scalar:sel args:a count:2]; [self log:[NSString stringWithFormat:@"Set interface field %u",sel] code:r];
    if(r) return [self failed:@"HID interface setup rejected."];
  }
  const uint16_t length=sizeof(UKReportDescriptor);
  const uint8_t hid[]={9,0x21,0x11,0x01,0,1,0x22,length&255,length>>8};
  uint64_t descriptorArgs[]={0x21,0xf};
  [self mark:@"Install HID descriptor"];
  r=IOConnectCallMethod(_port,6,descriptorArgs,2,hid,sizeof(hid),NULL,NULL,NULL,NULL);
  [self log:@"Install HID descriptor" code:r]; if(r) return [self failed:@"HID descriptor rejected."];
  descriptorArgs[0]=0x22;
  [self mark:@"Install report descriptor"];
  r=IOConnectCallMethod(_port,7,descriptorArgs,2,UKReportDescriptor,sizeof(UKReportDescriptor),NULL,NULL,NULL,NULL);
  [self log:@"Install report descriptor" code:r]; if(r) return [self failed:@"Report descriptor rejected."];
  uint64_t pipeArgs[]={3,1,8,10,0,(uint64_t)cfg}; uint32_t n=1;
  [self mark:@"Create interrupt IN endpoint"];
  r=IOConnectCallScalarMethod(_port,10,pipeArgs,6,&_pipe,&n);
  [self log:@"Create interrupt IN endpoint" code:r]; if(r||n!=1) return [self failed:@"Endpoint creation failed."];
  uint64_t size[]={4096}, out[3]={0}; n=3;
  [self mark:@"Map report buffer"];
  r=IOConnectCallScalarMethod(_port,18,size,1,out,&n);
  [self log:@"Map report buffer" code:r];
  if(r||n!=3||!out[0]||out[1]<8||!out[2]) return [self failed:@"Report buffer mapping failed."];
  _buffer=(void *)(uintptr_t)out[0]; _token=out[2];
  [self mark:@"Commit interface"];
  r=[self scalar:11 args:NULL count:0]; [self log:@"Commit interface" code:r];
  if(r) return [self failed:@"Interface commit rejected."];
  [self mark:@"Register host HID control handler"];
  r=UKControlStart(_port,&_control); [self log:@"Register host HID control handler" code:r];
  if(r) return [self failed:@"Cannot handle host keyboard control requests."];
  [self mark:@"Re-enumerate as keyboard"];
  r=Reenumerate(_controller,250); [self log:@"Re-enumerate as keyboard" code:r];
  if(r) return [self failed:@"Re-enumeration failed."];
  _lastReportTime=clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9;
  _active=YES;
  return [self result:YES message:@"Keyboard configured locally. Host recognition is unverified. Test one key in a harmless text field."];
}
- (IOReturn)report:(const uint8_t *)bytes {
  memcpy(_buffer,bytes,8); uint64_t a[]={_pipe,_token,8,250}, written=0; uint32_t n=1;
  IOReturn r=IOConnectCallScalarMethod(_port,14,a,4,&written,&n);
  if(!r&&(n!=1||written!=8)) return kIOReturnUnderrun;
  if(!r) _lastReportTime=clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9;
  return r;
}
// HID SET_IDLE requests schedule only the released state between explicit taps.
- (int)pollMilliseconds {
  uint8_t idle=UKControlRead(_control).idle;
  return _active?(idle?MIN(50,idle*4):50):500;
}
- (void)maintain {
  if(!_active) return;
  UKControlStats stats=UKControlRead(_control);
  if(stats.failures) { [self log:@"HID host control failure" code:stats.lastError]; [self failed:@"Host control request failed. Session stopped; no retry."]; return; }
  if(stats.idle && clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9-_lastReportTime>=stats.idle*0.004) {
    uint8_t release[8]={0}; IOReturn r=[self report:release];
    if(r) { [self log:@"HID idle release report" code:r]; [self failed:@"Idle report transfer failed. Session stopped; no retry."]; }
  }
}
- (NSDictionary *)key:(uint8_t)key modifier:(uint8_t)modifier {
  if(!_active) return [self result:NO message:@"Press Start before sending keys."];
  if(key<4||key>0x65) return [self result:NO message:@"Unsupported HID usage."];
  uint64_t driver[2]={0}; uint32_t count=2;
  IOReturn query=IOConnectCallScalarMethod(_port,24,NULL,0,driver,&count);
  if(query||count!=2) { [self log:@"Query interface activation" code:query?:kIOReturnBadArgument]; return [self failed:@"Cannot verify the interface is active. No key sent."]; }
  if(!driver[0]) return [self result:NO message:@"The USB driver reports this keyboard interface is inactive. No key sent. Check the target connection and the live host diagnostics."];
  uint8_t press[8]={modifier,0,key,0,0,0,0,0}, release[8]={0};
  IOReturn r=[self report:press]; usleep(20000); IOReturn up=[self report:release];
  // Never log key values, typed text, or passcodes.
  if(r||up) { [self log:@"Key transport" code:r?r:up]; return [self failed:@"Key press/release transfer failed. Session stopped; no automatic retry."]; }
  return [self result:YES message:@"Key reports transferred. This does not prove the host accepted the input."];
}
@end
