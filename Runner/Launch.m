// On-device XCTest launch technique informed by OpenMinis/iCTRL (Apache-2.0).
// This implementation exposes only a user-confirmed Sleep alarm request.
#import "Bridge.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSMutableArray *pending;
static NSMutableSet *seen;
static NSLock *requestLock;
static BOOL ready=NO;
static void Capture(NSURL *url) {
    if(![url.scheme.lowercaseString isEqual:@"daybreak-runner"] || ![url.host isEqual:@"sleep"]) return;
    NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(NSURLQueryItem *q in parts.queryItems) if(q.value) values[q.name]=q.value;
    NSString *h=values[@"hour"], *m=values[@"minute"], *identifier=values[@"request"];
    NSCharacterSet *nonDigits=NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if(!h.length || !m.length || identifier.length!=36 || h.length>2 || m.length>2 || [h rangeOfCharacterFromSet:nonDigits].location!=NSNotFound || [m rangeOfCharacterFromSet:nonDigits].location!=NSNotFound || h.integerValue>23 || m.integerValue>59 || ![[NSUUID alloc] initWithUUIDString:identifier]) return;
    [requestLock lock];
    if(![seen containsObject:identifier] && pending.count<4) { [seen addObject:identifier]; [pending addObject:@{@"hour":@(h.integerValue),@"minute":@(m.integerValue),@"request":identifier}]; }
    [requestLock unlock];
}
static void CaptureContexts(NSSet *contexts) { for(UIOpenURLContext *ctx in contexts) Capture(ctx.URL); }
static void Hook(Class cls, SEL selector, SEL saved, IMP replacement, const char *types) {
    if(class_getInstanceMethod(cls,saved)) return;
    Method original=class_getInstanceMethod(cls,selector);
    if(original) {
        if(!class_addMethod(cls,saved,method_getImplementation(original),method_getTypeEncoding(original))) return;
        class_replaceMethod(cls,selector,replacement,method_getTypeEncoding(original));
    } else class_addMethod(cls,selector,replacement,types);
}
static BOOL Launched(id self,SEL s,UIApplication *app,NSDictionary *options) {
    Capture(options[UIApplicationLaunchOptionsURLKey]);
    SEL original=NSSelectorFromString(@"db_originalLaunch:options:");
    return [self respondsToSelector:original]?((BOOL(*)(id,SEL,id,id))objc_msgSend)(self,original,app,options):YES;
}
static BOOL Opened(id self,SEL s,UIApplication *app,NSURL *url,NSDictionary *options) {
    Capture(url); SEL original=NSSelectorFromString(@"db_originalOpen:url:options:");
    return [self respondsToSelector:original]?((BOOL(*)(id,SEL,id,id,id))objc_msgSend)(self,original,app,url,options):YES;
}
static void SceneOpened(id self,SEL s,id scene,NSSet *contexts) {
    CaptureContexts(contexts); SEL original=NSSelectorFromString(@"db_originalScene:contexts:");
    if([self respondsToSelector:original]) ((void(*)(id,SEL,id,id))objc_msgSend)(self,original,scene,contexts);
}
static void SceneConnected(id self,SEL s,id scene,id session,UISceneConnectionOptions *options) {
    CaptureContexts(options.URLContexts); SEL original=NSSelectorFromString(@"db_originalScene:session:options:");
    if([self respondsToSelector:original]) ((void(*)(id,SEL,id,id,id))objc_msgSend)(self,original,scene,session,options);
}
static void (*setDelegateOriginal)(id,SEL,id);
static void SetDelegate(id self,SEL s,id delegate) {
    if(delegate) {
        Class cls=object_getClass(delegate);
        Hook(cls,@selector(application:didFinishLaunchingWithOptions:),NSSelectorFromString(@"db_originalLaunch:options:"),(IMP)Launched,"B@:@@");
        Hook(cls,@selector(application:openURL:options:),NSSelectorFromString(@"db_originalOpen:url:options:"),(IMP)Opened,"B@:@@@");
        Hook(cls,@selector(scene:openURLContexts:),NSSelectorFromString(@"db_originalScene:contexts:"),(IMP)SceneOpened,"v@:@@");
        Hook(cls,@selector(scene:willConnectToSession:options:),NSSelectorFromString(@"db_originalScene:session:options:"),(IMP)SceneConnected,"v@:@@@");
    }
    setDelegateOriginal(self,s,delegate);
}
@implementation DaybreakLaunch
+ (void)load {
    pending=[NSMutableArray new]; seen=[NSMutableSet new]; requestLock=[NSLock new];
    Method delegate=class_getInstanceMethod(UIApplication.class,@selector(setDelegate:));
    if(delegate) { setDelegateOriginal=(void(*)(id,SEL,id))method_getImplementation(delegate); method_setImplementation(delegate,(IMP)SetDelegate); }
    Class appDelegate=NSClassFromString(@"_XCTRunnerAppDelegate");
    if(appDelegate) {
        Hook(appDelegate,@selector(application:didFinishLaunchingWithOptions:),NSSelectorFromString(@"db_originalLaunch:options:"),(IMP)Launched,"B@:@@");
        Hook(appDelegate,@selector(application:openURL:options:),NSSelectorFromString(@"db_originalOpen:url:options:"),(IMP)Opened,"B@:@@@");
        Hook(appDelegate,@selector(scene:openURLContexts:),NSSelectorFromString(@"db_originalScene:contexts:"),(IMP)SceneOpened,"v@:@@");
        Hook(appDelegate,@selector(scene:willConnectToSession:options:),NSSelectorFromString(@"db_originalScene:session:options:"),(IMP)SceneConnected,"v@:@@@");
    }
    for(NSString *name in @[@"_XCTRunnerSceneDelegate",@"XCTRunnerSceneDelegate"]) {
        Class cls=NSClassFromString(name); if(!cls) continue;
        Hook(cls,@selector(scene:openURLContexts:),NSSelectorFromString(@"db_originalScene:contexts:"),(IMP)SceneOpened,"v@:@@");
        Hook(cls,@selector(scene:willConnectToSession:options:),NSSelectorFromString(@"db_originalScene:session:options:"),(IMP)SceneConnected,"v@:@@@");
    }
    // XCTest can stall while its runner remains foreground. Never re-enter
    // _XCTestMain; only background when no system authorization covers us.
    __block NSUInteger attempts=0;
    __block void (^background)(void);
    background=^{
        if(ready || ++attempts>120){background=nil;return;}
        BOOL covered=NO;
        for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) if(scene.activationState==UISceneActivationStateForegroundInactive) covered=YES;
        if(!covered && UIApplication.sharedApplication.applicationState==UIApplicationStateActive) {
            SEL suspend=NSSelectorFromString(@"suspend");
            if([UIApplication.sharedApplication respondsToSelector:suspend]) ((void(*)(id,SEL))objc_msgSend)(UIApplication.sharedApplication,suspend);
            background=nil;return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),background);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),background);
}
+ (NSArray *)takeRequests { [requestLock lock]; NSArray *result=[pending copy];[pending removeAllObjects];[requestLock unlock];return result; }
+ (void)markReady { ready=YES; }
+ (NSString *)caught:(void (^)(void))work { @try { work(); return nil; } @catch(NSException *e) { return [NSString stringWithFormat:@"%@: %@",e.name,e.reason]; } }
@end
