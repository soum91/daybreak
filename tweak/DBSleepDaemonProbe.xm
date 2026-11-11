#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <notify.h>
#import <stdatomic.h>
#import <string.h>

// Experimental, opt-in override is confined to the _HKFeatureFlags getter
// inside sleepd. The default is OFF. Never instantiate a second environment,
// change Sleep schedules, or invoke a force-sync method. Switching it OFF and
// rebooting userspace restores the original getter and provider lifecycle.
@interface HDSPSleepDaemon : NSObject
- (void)start;
@end
@interface _HKFeatureFlags : NSObject
- (BOOL)sleepCloudKitSync;
@end

static BOOL DBSDOverrideEnabled = NO;
static atomic_bool DBSDOriginalSeen;
static atomic_bool DBSDOriginalValue;

static BOOL DBSDReadOverrideSetting(void) {
    CFStringRef domain = CFSTR("com.soum91.daybreak.tweak");
    CFPreferencesAppSynchronize(domain);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("experimentalSleepCloudSync"), domain));
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

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
    DBSDStatus(DBSDOverrideEnabled ? "daemon_override_enabled" : "daemon_override_disabled");
    @try {
        id environment = DBSDObject(daemon, @"environment");
        if (!environment) {
            DBSDStatus("daemon_feature_unknown");
            DBSDStatus("daemon_original_unknown");
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
        if (atomic_load(&DBSDOriginalSeen))
            DBSDStatus(atomic_load(&DBSDOriginalValue) ? "daemon_original_on" : "daemon_original_off");
        else
            DBSDStatus("daemon_original_unknown");

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
        DBSDStatus("daemon_original_unknown");
        DBSDStatus("daemon_cloud_unknown");
        DBSDStatus("daemon_initial_unknown");
        DBSDStatus("daemon_pull_unknown");
    }
}

%hook _HKFeatureFlags
- (BOOL)sleepCloudKitSync {
    BOOL systemValue = %orig;
    atomic_store(&DBSDOriginalValue, systemValue);
    atomic_store(&DBSDOriginalSeen, true);
    // Changing this one feature gate can cause Apple's existing CloudKit
    // implementation to initialize. It does not prove cloud sync succeeded.
    return DBSDOverrideEnabled ? YES : systemValue;
}
%end

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
        DBSDOverrideEnabled = DBSDReadOverrideSetting();
        atomic_init(&DBSDOriginalSeen, false);
        atomic_init(&DBSDOriginalValue, false);
        %init;
    }
}
