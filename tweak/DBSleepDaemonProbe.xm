#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <notify.h>
#import <string.h>

// Observes the *existing* sleepd environment after Apple has started it.
// Do not instantiate a second HDSPEnvironment, write Sleep preferences, force
// iCloud traffic, or change the working next-only native Sleep writer.
@interface HDSPSleepDaemon : NSObject
- (void)start;
@end

static void DBSDStatus(const char *result) {
    NSString *notification = [@"com.soum91.daybreak.healthprobe."
                              stringByAppendingString:[NSString stringWithUTF8String:result]];
    notify_post(notification.UTF8String);
}

static id DBSDObject(id object, NSString *name) {
    if (!object) return nil;
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static BOOL DBSDBool(id object, NSString *name, BOOL *value) {
    if (!object) return NO;
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 ||
        !strchr("Bc", signature.methodReturnType[0])) return NO;
    BOOL result = ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    if (value) *value = result;
    return YES;
}

static void DBSDInspect(HDSPSleepDaemon *daemon) {
    DBSDStatus("daemon_seen");
    @try {
        id environment = DBSDObject(daemon, @"environment");
        if (!environment) {
            DBSDStatus("daemon_feature_unknown");
            DBSDStatus("daemon_cloud_unknown");
            DBSDStatus("daemon_initial_unknown");
            DBSDStatus("daemon_pull_unknown");
            return;
        }

        // Use the behavior of the running Sleep daemon, not the Health app's
        // behavior. A difference between these processes is diagnostically useful.
        id features = DBSDObject(DBSDObject(environment, @"behavior"), @"features");
        BOOL feature = NO;
        if (DBSDBool(features, @"sleepCloudKitSync", &feature))
            DBSDStatus(feature ? "daemon_feature_on" : "daemon_feature_off");
        else
            DBSDStatus("daemon_feature_unknown");

        // Access only the existing environment's synced defaults. In
        // HDSPSyncedDefaults, syncDisabled is the negation of the separate
        // cloudSyncEnabledKey preference. This is not iCloud Health's switch.
        id storage = DBSDObject(environment, @"sleepStorage");
        id synced = DBSDObject(storage, @"syncedDefaults");
        BOOL disabled = NO;
        if (DBSDBool(synced, @"syncDisabled", &disabled))
            DBSDStatus(disabled ? "daemon_cloud_off" : "daemon_cloud_on");
        else
            DBSDStatus("daemon_cloud_unknown");

        BOOL pending = NO;
        if (DBSDBool(synced, @"needsInitialSync", &pending))
            DBSDStatus(pending ? "daemon_initial_pending" : "daemon_initial_clear");
        else
            DBSDStatus("daemon_initial_unknown");

        if (DBSDBool(synced, @"needsSyncFromCloud", &pending))
            DBSDStatus(pending ? "daemon_pull_pending" : "daemon_pull_clear");
        else
            DBSDStatus("daemon_pull_unknown");
    } @catch (NSException *exception) {
        NSLog(@"[Daybreak] Read-only sleepd probe exception: %@", exception.reason);
        DBSDStatus("daemon_feature_unknown");
        DBSDStatus("daemon_cloud_unknown");
        DBSDStatus("daemon_initial_unknown");
        DBSDStatus("daemon_pull_unknown");
    }
}

%hook HDSPSleepDaemon
- (void)start {
    %orig;
    // Apple is allowed to finish preparing its environment first. This is an
    // observational callback and does not alter or delay daemon startup.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool { DBSDInspect(self); }
    });
}
%end

%ctor {
    @autoreleasepool {
        if (![NSProcessInfo.processInfo.processName isEqualToString:@"sleepd"]) return;
        %init;
    }
}
