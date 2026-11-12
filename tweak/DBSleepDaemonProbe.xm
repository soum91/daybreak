#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <notify.h>
#import <stdatomic.h>
#import <string.h>
#import <objc/runtime.h>

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
static BOOL DBSDOverrideReadable = YES;
static HDSPSleepDaemon *DBSDDaemon = nil;
static atomic_bool DBSDOriginalSeen;
static atomic_bool DBSDOriginalValue;

// sleepd is sandboxed. cfprefsd may refuse another domain, so fall back to
// the plist file directly and report when neither source is readable instead
// of silently treating the switch as OFF.
static BOOL DBSDReadOverrideSetting(void) {
    CFStringRef domain = CFSTR("com.soum91.daybreak.tweak");
    CFPreferencesAppSynchronize(domain);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("experimentalSleepCloudSync"), domain));
    if (![value respondsToSelector:@selector(boolValue)]) {
        NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:
            @"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.plist"];
        value = file[@"experimentalSleepCloudSync"];
        DBSDOverrideReadable = (file != nil);
    }
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


// One-shot, read-only structure dump to the system log so the sync path can
// be identified on iOS 16. Logs class and property NAMES plus the runtime
// class of each matching property value. No schedule data, no mutation.
static BOOL DBSDMatches(NSString *name) {
    NSString *l = name.lowercaseString;
    return [l containsString:@"cloud"] || [l containsString:@"sync"] || [l containsString:@"ckzone"];
}
static void DBSDDumpObject(NSString *label, id object) {
    if (!object) { NSLog(@"[DaybreakDump] %@ = nil", label); return; }
    NSLog(@"[DaybreakDump] %@ class=%@", label, NSStringFromClass([object class]));
    for (Class c = [object class]; c && c != NSObject.class; c = class_getSuperclass(c)) {
        unsigned int count = 0;
        objc_property_t *props = class_copyPropertyList(c, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = [NSString stringWithUTF8String:property_getName(props[i])];
            if (!DBSDMatches(name)) continue;
            const char *attrs = property_getAttributes(props[i]);
            NSString *value = @"?";
            if (attrs && attrs[1] == '@') {
                id v = DBSDObject(object, name);
                value = v ? NSStringFromClass([v class]) : @"nil";
            } else {
                BOOL b = NO;
                if (DBSDBool(object, name, &b)) value = b ? @"YES" : @"NO";
            }
            NSLog(@"[DaybreakDump] %@.%@ -> %@", label, name, value);
        }
        free(props);
    }
}
static void DBSDDumpOnce(HDSPSleepDaemon *daemon) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            const char *image = class_getImageName([daemon class]);
            NSLog(@"[DaybreakDump] sleepd image=%s", image ?: "?");
            NSMutableSet *images = [NSMutableSet set];
            if (image) [images addObject:@(image)];
            for (NSString *cn in @[@"HDSPSleepStorage", @"HKSPSleepStore", @"_HKFeatureFlags"]) {
                Class k = NSClassFromString(cn);
                const char *im = k ? class_getImageName(k) : NULL;
                if (im) [images addObject:@(im)];
            }
            for (NSString *path in images) {
                unsigned int count = 0;
                const char **names = objc_copyClassNamesForImage(path.UTF8String, &count);
                for (unsigned int i = 0; i < count; i++) {
                    NSString *n = @(names[i]);
                    if (DBSDMatches(n)) NSLog(@"[DaybreakDump] class %@ (%@)", n, path.lastPathComponent);
                }
                free(names);
            }
            id environment = DBSDObject(daemon, @"environment");
            DBSDDumpObject(@"daemon", daemon);
            DBSDDumpObject(@"environment", environment);
            DBSDDumpObject(@"sleepStorage", DBSDObject(environment, @"sleepStorage"));
            DBSDDumpObject(@"syncedDefaults", DBSDObject(DBSDObject(environment, @"sleepStorage"), @"syncedDefaults"));
            DBSDDumpObject(@"behavior", DBSDObject(environment, @"behavior"));
            NSLog(@"[DaybreakDump] done");
        } @catch (NSException *e) {
            NSLog(@"[DaybreakDump] exception %@", e.reason);
        }
    });
}

static void DBSDInspect(HDSPSleepDaemon *daemon) {
    DBSDStatus("daemon_seen");
    DBSDDumpOnce(daemon);
    DBSDStatus(DBSDOverrideEnabled ? "daemon_override_enabled" :
               (DBSDOverrideReadable ? "daemon_override_disabled" : "daemon_override_unreadable"));
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
    DBSDDaemon = self;
    // Darwin notifications are not queued. After a userspace reboot sleepd
    // can start before SpringBoard subscribes, so one early report is lost.
    // Repeat a few times and also answer explicit refresh requests below.
    for (NSNumber *delay in @[@8, @45, @180]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay.longLongValue * NSEC_PER_SEC),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            @autoreleasepool { DBSDInspect(self); }
        });
    }
}
%end

%ctor {
    @autoreleasepool {
        if (![NSProcessInfo.processInfo.processName isEqualToString:@"sleepd"]) return;
        DBSDOverrideEnabled = DBSDReadOverrideSetting();
        atomic_init(&DBSDOriginalSeen, false);
        atomic_init(&DBSDOriginalValue, false);
        %init;
        int token = 0;
        notify_register_dispatch("com.soum91.daybreak.daemonprobe.request", &token,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t) {
            (void)t;
            @autoreleasepool { if (DBSDDaemon) DBSDInspect(DBSDDaemon); }
        });
    }
}
