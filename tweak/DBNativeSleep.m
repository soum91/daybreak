#import "DBNativeSleep.h"
#import <HealthKit/HealthKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import <math.h>
#import <string.h>

// Use Sleep.framework's canonical schedule model and save API. Never edit
// Health's database, never manufacture an ordinary MobileTimer alarm, and
// never silently change the user's repeating weekly occurrences.
static NSString *const DBNSPrefs = @"com.soum91.daybreak.tweak";
static BOOL DBNSInFlight = NO;

static void DBNSStatus(const char *result) {
    NSString *notification = [@"com.soum91.daybreak.healthprobe." stringByAppendingString:
                              [NSString stringWithUTF8String:result]];
    notify_post(notification.UTF8String);
}

static id DBNSPreference(NSString *key) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)DBNSPrefs);
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                      (__bridge CFStringRef)DBNSPrefs));
}

static BOOL DBNSMethod(id object, NSString *name, NSUInteger count, char returnType) {
    if (!object) return NO;
    NSMethodSignature *sig = [object methodSignatureForSelector:NSSelectorFromString(name)];
    return sig && sig.numberOfArguments == count + 2 &&
           sig.methodReturnType[0] == returnType;
}

static id DBNSGet(id object, NSString *name) {
    if (!DBNSMethod(object, name, 0, '@')) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}

static id DBNSGetOne(id object, NSString *name, id argument) {
    if (!DBNSMethod(object, name, 1, '@')) return nil;
    return ((id (*)(id, SEL, id))objc_msgSend)(object, NSSelectorFromString(name), argument);
}

static BOOL DBNSBool(id object, NSString *name, BOOL *value) {
    if (!object) return NO;
    NSMethodSignature *sig = [object methodSignatureForSelector:NSSelectorFromString(name)];
    if (!sig || sig.numberOfArguments != 2 ||
        !strchr("Bc", sig.methodReturnType[0])) return NO;
    BOOL result = ((BOOL (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
    if (value) *value = result;
    return YES;
}

static id DBNSCallWithError(id object, NSString *name, NSError **error) {
    if (!DBNSMethod(object, name, 1, '@')) return nil;
    return ((id (*)(id, SEL, NSError **))objc_msgSend)(object,
            NSSelectorFromString(name), error);
}

static BOOL DBNSLoadFramework(void) {
    if (!dlopen("/System/Library/PrivateFrameworks/Sleep.framework/Sleep",
                RTLD_LAZY | RTLD_LOCAL)) return NO;
    return NSClassFromString(@"HKSPSleepStore") &&
           NSClassFromString(@"HKSPSleepScheduleModel") &&
           NSClassFromString(@"HKSPMutableSleepScheduleOccurrence");
}

static id DBNSNewStore(void) {
    Class cls = NSClassFromString(@"HKSPSleepStore");
    id allocated = [cls alloc];
    if (!DBNSMethod(allocated, @"initWithHealthStore:", 1, '@')) return nil;
    HKHealthStore *health = [HKHealthStore new];
    return ((id (*)(id, SEL, id))objc_msgSend)(allocated,
            @selector(initWithHealthStore:), health);
}

static NSDate *DBNSTomorrowStart(NSCalendar *cal, NSDate *now) {
    return [cal dateByAddingUnit:NSCalendarUnitDay value:1
                         toDate:[cal startOfDayForDate:now] options:0];
}

static BOOL DBNSOnlyOverrideChanged(id before, id after) {
    // All seven repeating occurrences must be untouched. The only allowed
    // difference is the one-day override, never the repeating weekly schedule.
    NSArray *days = @[@"mondayOccurrence", @"tuesdayOccurrence", @"wednesdayOccurrence",
                      @"thursdayOccurrence", @"fridayOccurrence", @"saturdayOccurrence",
                      @"sundayOccurrence"];
    for (NSString *day in days) {
        if (!DBNSMethod(before, day, 0, '@') || !DBNSMethod(after, day, 0, '@')) return NO;
        id original = DBNSGet(before, day), candidate = DBNSGet(after, day);
        if (original != candidate && ![original isEqual:candidate]) return NO;
    }
    return YES;
}

void DBNativeSleepCheck(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            @try {
                if (!DBNSLoadFramework()) { DBNSStatus("native_framework_missing"); return; }
                id store = DBNSNewStore();
                if (!store || !DBNSMethod(store, @"sleepScheduleModelWithError:", 1, '@') ||
                    !DBNSMethod(store, @"saveCurrentSleepSchedule:completion:", 2, 'v')) {
                    DBNSStatus("native_api_missing"); return;
                }
                NSError *error = nil;
                id model = DBNSCallWithError(store, @"sleepScheduleModelWithError:", &error);
                if (error || !model) { DBNSStatus("native_model_unavailable"); return; }
                id schedule = DBNSGet(model, @"sleepSchedule");
                if (!schedule || !DBNSMethod(schedule, @"mutableCopyWithZone:", 1, '@')) {
                    DBNSStatus("native_schedule_unavailable"); return;
                }
                DBNSStatus("native_api_ready");
            } @catch (NSException *exception) {
                NSLog(@"[Daybreak] Native Sleep capability probe exception: %@", exception.reason);
                DBNSStatus("native_probe_exception");
            }
        }
    });
}

// YES means the native asynchronous completion will release the in-flight
// flag; NO means the caller must release it immediately.
static BOOL DBNSProcessOneRequest(void) {
    @try {
        NSDictionary *request = DBNSPreference(@"nativeSleepRequest");
        if (![request isKindOfClass:NSDictionary.class]) {
            DBNSStatus("native_request_missing");
            return NO;
        }
        NSDate *wake = request[@"wake"];
        NSDate *morning = request[@"morning"];
        NSDate *created = request[@"created"];
        NSString *identifier = request[@"identifier"];
        NSDate *now = NSDate.date;
        NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        cal.timeZone = NSTimeZone.localTimeZone;
        NSDate *tomorrow = DBNSTomorrowStart(cal, now);
        if (![wake isKindOfClass:NSDate.class] ||
            ![morning isKindOfClass:NSDate.class] ||
            ![created isKindOfClass:NSDate.class] ||
            ![identifier isKindOfClass:NSString.class] || identifier.length < 8 ||
            [now timeIntervalSinceDate:created] < 0 ||
            [now timeIntervalSinceDate:created] > 600 ||
            ![cal isDate:morning inSameDayAsDate:tomorrow] ||
            ![cal isDate:wake inSameDayAsDate:tomorrow] ||
            [wake timeIntervalSinceDate:now] < 300 ||
            [cal component:NSCalendarUnitHour fromDate:now] < 12) {
            DBNSStatus("native_request_invalid"); return NO;
        }
        if (!DBNSLoadFramework()) { DBNSStatus("native_framework_missing"); return NO; }
        id store = DBNSNewStore();
        if (!store || !DBNSMethod(store, @"sleepScheduleModelWithError:", 1, '@') ||
            !DBNSMethod(store, @"saveCurrentSleepSchedule:completion:", 2, 'v') ||
            !DBNSMethod(store, @"currentSleepScheduleWithError:", 1, '@')) {
            DBNSStatus("native_api_missing"); return NO;
        }
        NSError *error = nil;
        id model = DBNSCallWithError(store, @"sleepScheduleModelWithError:", &error);
        id schedule = DBNSGet(model, @"sleepSchedule");
        BOOL enabled = NO;
        if (error || !schedule || !DBNSBool(schedule, @"isEnabledAndHasOccurrences", &enabled) || !enabled) {
            DBNSStatus("native_schedule_unavailable"); return NO;
        }
        id resolved = DBNSGetOne(model, @"upcomingResolvedOccurrenceAfterDate:", now);
        id alarmEvent = DBNSGet(resolved, @"wakeUpEvent");
        NSDate *originalWake = DBNSGet(alarmEvent, @"dueDate");
        if (![originalWake isKindOfClass:NSDate.class] ||
            ![cal isDate:originalWake inSameDayAsDate:tomorrow]) {
            DBNSStatus("native_next_day_mismatch"); return NO;
        }
        if (fabs([originalWake timeIntervalSinceDate:wake]) < 30) {
            DBNSStatus("native_request_consumed");
            DBNSStatus("native_already_matched");
            return NO;
        }
        NSString *overrideName = @"generateOverrideOccurrenceForCurrentDate:gregorianCalendar:";
        if (!DBNSMethod(resolved, overrideName, 2, '@')) {
            DBNSStatus("native_override_api_missing"); return NO;
        }
        id override = ((id (*)(id, SEL, id, id))objc_msgSend)(resolved,
                    NSSelectorFromString(overrideName), now, cal);
        BOOL single = NO;
        if (!override || !DBNSBool(override, @"isSingleDayOverride", &single) || !single) {
            DBNSStatus("native_override_unavailable"); return NO;
        }
        id mutable = [override mutableCopy];
        id config = DBNSGet(mutable, @"alarmConfiguration");
        BOOL alarmOn = NO;
        if (!DBNSBool(config, @"isEnabled", &alarmOn) || !alarmOn) {
            DBNSStatus("native_alarm_off"); return NO;
        }
        NSDateComponents *components = [DBNSGet(mutable, @"wakeUpComponents") copy];
        if (![components isKindOfClass:NSDateComponents.class] ||
            !DBNSMethod(mutable, @"setWakeUpComponents:", 1, 'v')) {
            DBNSStatus("native_components_missing"); return NO;
        }
        NSDateComponents *wanted = [cal components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:wake];
        components.hour = wanted.hour;
        components.minute = wanted.minute;
        components.second = 0;
        NSDate *targetDate = [cal dateFromComponents:components];
        if (!targetDate || fabs([targetDate timeIntervalSinceDate:wake]) > 60 ||
            ![cal isDate:targetDate inSameDayAsDate:tomorrow]) {
            DBNSStatus("native_components_invalid"); return NO;
        }
        ((void (*)(id, SEL, id))objc_msgSend)(mutable,
                    NSSelectorFromString(@"setWakeUpComponents:"), components);
        BOOL occurrenceValid = NO;
        if (!DBNSBool(mutable, @"isValidOccurrence", &occurrenceValid) || !occurrenceValid) {
            DBNSStatus("native_occurrence_invalid"); return NO;
        }
        id newModel = DBNSGetOne(model, @"modelByApplyingChangesFromOccurrence:", mutable);
        id newSchedule = DBNSGet(newModel, @"sleepSchedule");
        id newOverride = DBNSGet(newSchedule, @"overrideOccurrence");
        BOOL stillSingle = NO;
        if (!newSchedule || !DBNSOnlyOverrideChanged(schedule, newSchedule) ||
            !DBNSBool(newOverride, @"isSingleDayOverride", &stillSingle) || !stillSingle) {
            DBNSStatus("native_repeating_guard"); return NO;
        }
        NSDateComponents *check = DBNSGet(newOverride, @"wakeUpComponents");
        if (![check isKindOfClass:NSDateComponents.class] ||
            check.hour != wanted.hour || check.minute != wanted.minute) {
            DBNSStatus("native_preview_mismatch"); return NO;
        }
        // Clear the request via SpringBoard before sending a one-time save.
        DBNSStatus("native_request_consumed");
        DBNSStatus("native_write_submitted");
        ((void (*)(id, SEL, id, id))objc_msgSend)(store,
            NSSelectorFromString(@"saveCurrentSleepSchedule:completion:"), newSchedule,
            ^(BOOL success) {
                // Keep synchronous XPC read-back away from Sleep's completion
                // callback queue to avoid re-entrancy or serial-queue deadlock.
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    @autoreleasepool {
                        @try {
                            if (!success) {
                                DBNSStatus("native_save_rejected");
                            } else {
                                NSError *readError = nil;
                                id fresh = DBNSCallWithError(store, @"currentSleepScheduleWithError:", &readError);
                                id freshOverride = DBNSGet(fresh, @"overrideOccurrence");
                                NSDateComponents *readBack = DBNSGet(freshOverride, @"wakeUpComponents");
                                if (!readError && [readBack isKindOfClass:NSDateComponents.class] &&
                                    readBack.hour == wanted.hour && readBack.minute == wanted.minute) {
                                    DBNSStatus("native_readback_match");
                                } else {
                                    DBNSStatus("native_readback_unverified");
                                }
                            }
                        } @catch (NSException *exception) {
                            NSLog(@"[Daybreak] Native Sleep read-back exception: %@", exception.reason);
                            DBNSStatus("native_readback_exception");
                        } @finally {
                            @synchronized (DBNSPrefs) { DBNSInFlight = NO; }
                        }
                    }
                });
            });
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[Daybreak] Native Sleep save exception: %@", exception.reason);
        DBNSStatus("native_write_exception");
        return NO;
    }
}

void DBNativeSleepApplyIfRequested(void) {
    @synchronized (DBNSPrefs) {
        if (DBNSInFlight) return;
        DBNSInFlight = YES;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            if (!DBNSProcessOneRequest()) {
                @synchronized (DBNSPrefs) { DBNSInFlight = NO; }
            }
        }
    });
}
