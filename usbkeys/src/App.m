#import <UIKit/UIKit.h>
#import "HID.h"
#import "Journal.h"
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static NSString *UKInstalledVersion(void) {
  NSDictionary *info=NSBundle.mainBundle.infoDictionary;
  return [NSString stringWithFormat:@"USBKeys %@ (%@)",info[@"CFBundleShortVersionString"]?:@"?",info[@"CFBundleVersion"]?:@"?"];
}

@interface UKView : UIViewController <UITextFieldDelegate>
@end
@implementation UKView {
  UILabel *_status;
  UITextView *_diagnostics;
  UIStackView *_stack;
  dispatch_queue_t _queue;
  NSTimer *_heartbeat;
  BOOL _enabled, _busy;
  NSMutableArray<UIButton *> *_keyButtons;
  UITextField *_typingField;
  NSString *_report;
}
- (void)viewDidLoad {
  [super viewDidLoad]; self.title=@"USBKeys";
  _keyButtons=[NSMutableArray array];
  self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Last result" style:UIBarButtonItemStylePlain target:self action:@selector(lastResult)];
  self.view.backgroundColor=UIColor.systemBackgroundColor; _queue=dispatch_queue_create("usbkeys.control",DISPATCH_QUEUE_SERIAL);
  UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:scroll];
  _stack=[UIStackView new]; _stack.axis=UILayoutConstraintAxisVertical; _stack.spacing=14; _stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:_stack];
  [NSLayoutConstraint activateConstraints:@[
    [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [_stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20], [_stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
    [_stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20], [_stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20]
  ]];
  [self label:UKInstalledVersion() size:28];
  [self label:@"Experimental USB keyboard • Dopamine / iOS 16" size:15];
  [self label:@"Connect USB-C to the target and Lightning to this iPhone. Start, then test one key in a harmless text field. Recovery Assistant compatibility is unverified." size:15];
  _status=[self label:@"Ready to check USB support." size:17];
  [self row:@[@"Check USB",@"Start",@"Stop"] action:@selector(control:)];
  [self row:@[@"1",@"2",@"3"] action:@selector(digit:)];
  [self row:@[@"4",@"5",@"6"] action:@selector(digit:)];
  [self row:@[@"7",@"8",@"9"] action:@selector(digit:)];
  [self row:@[@"⌫",@"0",@"Return"] action:@selector(digit:)];
  [self row:@[@"Tab",@"Esc",@"Space"] action:@selector(special:)];
  [self row:@[@"←",@"↓",@"↑",@"→"] action:@selector(special:)];
  UITextField *field=[UITextField new]; field.placeholder=@"Tap here to type with the full keyboard"; field.borderStyle=UITextBorderStyleRoundedRect;
  _typingField=field; field.enabled=NO;
  field.delegate=self; field.autocorrectionType=UITextAutocorrectionTypeNo; field.autocapitalizationType=UITextAutocapitalizationTypeNone;
  field.smartQuotesType=UITextSmartQuotesTypeNo; field.smartDashesType=UITextSmartDashesTypeNo; field.secureTextEntry=YES; [_stack addArrangedSubview:field];
  [self label:@"US keyboard layout. Each key requires a tap or typed character. No automatic typing or retries. Typed input is not stored." size:13];
  _diagnostics=[UITextView new]; _diagnostics.editable=NO; _diagnostics.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]; [_diagnostics.heightAnchor constraintEqualToConstant:180].active=YES; [_stack addArrangedSubview:_diagnostics];
  [self row:@[@"Copy",@"Share",@"Save report"] action:@selector(export:)];
  _heartbeat=[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(heartbeat) userInfo:nil repeats:YES];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
  // Launch only builds the UI. Private USB API calls require Check USB / Start.
  [self display:@{@"active":@NO,@"operation":@"idle",@"phase":@"Awaiting action",@"message":@"Tap Check USB or Start. Keys stay disabled until setup succeeds.",@"diagnostics":@"No USB operation has run in this app session."}];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size { UILabel *v=[UILabel new]; v.text=text; v.numberOfLines=0; v.font=[UIFont systemFontOfSize:size]; [_stack addArrangedSubview:v]; return v; }
- (void)row:(NSArray *)titles action:(SEL)action {
  UIStackView *row=[UIStackView new]; row.spacing=10; row.distribution=UIStackViewDistributionFillEqually;
  for(NSString *title in titles) { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:title forState:UIControlStateNormal]; b.titleLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightMedium]; b.backgroundColor=UIColor.secondarySystemBackgroundColor; b.layer.cornerRadius=12; [b.heightAnchor constraintGreaterThanOrEqualToConstant:50].active=YES; [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; if(action==@selector(digit:)||action==@selector(special:)) { [_keyButtons addObject:b]; b.enabled=NO; } [row addArrangedSubview:b]; }
  [_stack addArrangedSubview:row];
}
- (void)display:(NSDictionary *)r {
  _enabled=[r[@"active"] boolValue]&&![r[@"pending"] boolValue];
  _status.text=r[@"message"]?:@"No service result.";
  _report=[NSString stringWithFormat:@"%@\niOS %@\nService: %@ (PID %@)\nSaved at: %@\nOperation: %@\nLast step: %@\nLocal keyboard setup: %@\n%@\n\n%@",UKInstalledVersion(),UIDevice.currentDevice.systemVersion,r[@"version"]?:@"unknown",r[@"pid"]?:@"?",r[@"time"]?[NSDate dateWithTimeIntervalSince1970:[r[@"time"] doubleValue]]:@"not saved",r[@"operation"]?:@"unknown",r[@"phase"]?:@"unknown",_enabled?@"YES":@"NO",_status.text,r[@"diagnostics"]?:@"No step records available."];
  _diagnostics.text=_report;
  for(UIButton *button in _keyButtons) button.enabled=_enabled;
  _typingField.enabled=_enabled;
  UIApplication.sharedApplication.idleTimerDisabled=_enabled;
}
- (void)lastResult {
  NSMutableDictionary *r=[UKReadJournal() mutableCopy];
  // A saved report is evidence only; never authorize key sending from stale state.
  r[@"active"]=@NO;
  [self display:r?:@{@"active":@NO,@"message":@"No saved service result is readable yet.",@"phase":@"Read saved result",@"operation":@"status"}];
}
- (NSDictionary *)transportFailure:(NSString *)step error:(int)error operation:(NSString *)op {
  NSDictionary *saved=UKReadJournal();
  NSMutableDictionary *r=[saved mutableCopy]?:[NSMutableDictionary dictionary];
  r[@"active"]=@NO;
  r[@"message"]=[NSString stringWithFormat:@"Service request %@ failed at %@ (%d: %s). Last saved step: %@.",op,step,error,strerror(error),saved[@"phase"]?:@"unavailable"];
  r[@"operation"]=op; r[@"phase"]=saved[@"phase"]?:step;
  return r;
}
- (NSDictionary *)exchange:(NSDictionary *)request {
  NSString *op=request[@"op"]?:@"unknown";
  int s=socket(AF_UNIX,SOCK_STREAM,0); if(s<0) return [self transportFailure:@"create control socket" error:errno operation:op];
  struct timeval timeout={10,0}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout)); setsockopt(s,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
  int one=1; setsockopt(s,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));
  struct sockaddr_un addr={0}; addr.sun_family=AF_UNIX; strlcpy(addr.sun_path,"/var/jb/var/run/usbkeys/control.sock",sizeof(addr.sun_path));
  if(connect(s,(struct sockaddr *)&addr,sizeof(addr))) { int error=errno; close(s); return [self transportFailure:@"connect to service" error:error operation:op]; }
  NSMutableData *send=[[NSJSONSerialization dataWithJSONObject:request options:0 error:NULL] mutableCopy]; [send appendBytes:"\n" length:1];
  size_t offset=0; while(offset<send.length) { ssize_t n=write(s,(const uint8_t *)send.bytes+offset,send.length-offset); if(n<=0) { int error=errno; close(s); return [self transportFailure:@"send request" error:error operation:op]; } offset+=n; }
  NSMutableData *reply=[NSMutableData data]; char chunk[1024];
  BOOL complete=NO; int readError=0;
  while(reply.length<32768) { ssize_t n=read(s,chunk,sizeof(chunk)); if(n<=0) { readError=n<0?errno:ECONNRESET; break; } [reply appendBytes:chunk length:n]; if(memchr(chunk,'\n',n)) {complete=YES;break;} }
  close(s);
  if(!complete) return [self transportFailure:@"wait for service reply" error:readError?:EMSGSIZE operation:op];
  id result=[NSJSONSerialization JSONObjectWithData:reply options:0 error:NULL];
  return [result isKindOfClass:NSDictionary.class]?result:[self transportFailure:@"decode service reply" error:EPROTO operation:op];
}
- (void)request:(NSDictionary *)request show:(BOOL)show {
  dispatch_async(_queue,^{ NSDictionary *r=[self exchange:request]; dispatch_async(dispatch_get_main_queue(),^{
    if(show) self->_busy=NO;
    if(show||![r[@"ok"] boolValue]||[request[@"op"] isEqual:@"ping"]) [self display:r];
  }); });
}
- (void)control:(UIButton *)button {
  if(_busy) return; _busy=YES; NSString *t=button.currentTitle;
  _status.text=@"Working…"; _report=[NSString stringWithFormat:@"%@\n%@ requested. Waiting for service. Use Last result if it stalls.",UKInstalledVersion(),t]; _diagnostics.text=_report; [self.view endEditing:YES];
  [self request:@{@"op":[t isEqual:@"Start"]?@"start":[t isEqual:@"Stop"]?@"stop":@"probe"} show:YES];
}
- (void)sendKey:(uint8_t)key mod:(uint8_t)mod {
  if(!_enabled) { _status.text=@"Press Start before sending keys."; return; }
  // Only one report pair in flight. Failed input is never queued or retried.
  if(_busy) { _status.text=@"Wait for the previous key to finish."; return; }
  _busy=YES; [self request:@{@"op":@"key",@"key":@(key),@"modifier":@(mod)} show:YES];
}
- (void)digit:(UIButton *)b { NSString *t=b.currentTitle; if([t isEqual:@"⌫"]) [self sendKey:0x2a mod:0]; else if([t isEqual:@"Return"]) [self sendKey:0x28 mod:0]; else { uint8_t k,m; if(UKASCII([t characterAtIndex:0],&k,&m)) [self sendKey:k mod:m]; } }
- (void)special:(UIButton *)b { NSDictionary *codes=@{@"Tab":@0x2b,@"Esc":@0x29,@"Space":@0x2c,@"←":@0x50,@"↓":@0x51,@"↑":@0x52,@"→":@0x4f}; [self sendKey:[codes[b.currentTitle] unsignedCharValue] mod:0]; }
- (BOOL)textField:(UITextField *)f shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)s {
  if(s.length==0) [self sendKey:0x2a mod:0];
  else if(s.length==1) { uint8_t k,m; if(UKASCII([s characterAtIndex:0],&k,&m)) [self sendKey:k mod:m]; else _status.text=@"This character is not supported by the US HID layout."; }
  else _status.text=@"Type one character at a time. Bulk paste is disabled.";
  return NO;
}
- (BOOL)textFieldShouldReturn:(UITextField *)f { [self sendKey:0x28 mod:0]; return NO; }
- (void)heartbeat { if(_enabled&&!_busy&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive) [self request:@{@"op":@"ping"} show:NO]; }
- (void)background { _enabled=NO; UIApplication.sharedApplication.idleTimerDisabled=NO; [self request:@{@"op":@"stop"} show:YES]; }
- (void)export:(UIButton *)b {
  NSString *text=_report?:_diagnostics.text;
  if([b.currentTitle hasPrefix:@"Copy"]) { UIPasteboard.generalPasteboard.string=text; _status.text=[UIPasteboard.generalPasteboard.string isEqualToString:text]?@"Diagnostics copied and verified.":@"Clipboard verification failed. Use Share or Save report."; }
  else if([b.currentTitle hasPrefix:@"Save"]) {
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"USBKeys-diagnostics.txt"]];
    NSError *error=nil;
    if(![text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) { _status.text=@"Could not prepare report. Use Share."; return; }
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
    [self presentViewController:picker animated:YES completion:nil];
  }
  else { UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil]; share.popoverPresentationController.sourceView=b; [self presentViewController:share animated:YES completion:nil]; }
}
@end
@interface UKApp : UIResponder <UIApplicationDelegate>
@property(strong,nonatomic) UIWindow *window;
@end
@implementation UKApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options { self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[UKView new]]; [self.window makeKeyAndVisible]; return YES; }
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(UKApp.class)); } }
