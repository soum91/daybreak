#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <string.h>
#import "DBPlanner.h"
#import "DBNativeSleep.h"

// All private MobileTimer calls are selected and signature-checked at runtime.
// A missing interface, denied service or ambiguous Sleep target fails closed.
static NSString *const DBPrefs=@"com.soum91.daybreak.tweak";
static NSString *const DBLogPath=@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log";
static NSString *const DBStatusPath=@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.status.plist";

static id DBGet(id obj, NSString *name) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[obj methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@') return nil;
    return ((id(*)(id,SEL))objc_msgSend)(obj,selector);
}
static BOOL DBNumber(id obj, NSString *name, unsigned long long *out) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[obj methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=2 ||
       !strchr("BcCsSiIlLqQ",signature.methodReturnType[0]) ||
       signature.methodReturnLength>sizeof(unsigned long long)) return NO;
    NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:signature];
    invocation.target=obj; invocation.selector=selector; [invocation invoke];
    unsigned long long value=0; [invocation getReturnValue:&value];
    if(out) *out=value;
    return YES;
}
static id DBObjectCall(id obj, NSString *name, id argument) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[obj methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=3 || signature.methodReturnType[0]!='@' ||
       [signature getArgumentTypeAtIndex:2][0]!='@') return nil;
    return ((id(*)(id,SEL,id))objc_msgSend)(obj,selector,argument);
}
static NSInteger DBInteger(NSString *key, NSInteger fallback, NSInteger lo, NSInteger hi) {
    id stored=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)DBPrefs));
    if(![stored respondsToSelector:@selector(integerValue)]) return fallback;
    return MAX(lo,MIN(hi,[stored integerValue]));
}
static BOOL DBBoolean(NSString *key) {
    id stored=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)DBPrefs));
    return [stored respondsToSelector:@selector(boolValue)] && [stored boolValue];
}
static BOOL DBBooleanDefaultOn(NSString *key) {
    id stored=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)DBPrefs));
    return ![stored respondsToSelector:@selector(boolValue)] || [stored boolValue];
}
static NSString *DBString(NSString *key) {
    id stored=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)DBPrefs));
    return [stored isKindOfClass:NSString.class]?stored:nil;
}
static void DBStore(NSString *key,id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)DBPrefs);
    CFPreferencesAppSynchronize((__bridge CFStringRef)DBPrefs);
}
static NSString *DBDayKey(NSCalendar *calendar,NSDate *date) {
    NSDateComponents *c=[calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld",(long)c.year,(long)c.month,(long)c.day];
}
static void DBPostStatusNotification(NSString *key,NSString *title,NSString *message) {
    if(!DBBooleanDefaultOn(@"notificationsEnabled")) return;
    // The hourly timer is owned by SpringBoard. A public local notification
    // is requested only for a changed wake time or an actionable failure,
    // never for each no-change hourly check.
    @try {
        UNMutableNotificationContent *content=[UNMutableNotificationContent new];
        content.title=title;
        content.body=message;
        content.sound=UNNotificationSound.defaultSound;
        NSString *identifier=[@"daybreak." stringByAppendingString:key?:NSUUID.UUID.UUIDString];
        UNNotificationRequest *request=[UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError *error){
            if(error) NSLog(@"[Daybreak] Notification delivery unavailable in SpringBoard: %@",error);
        }];
    } @catch(NSException *exception) {
        NSLog(@"[Daybreak] Notification runtime error: %@",exception.reason);
    }
}

@interface DBEngine : NSObject
@property(nonatomic) BOOL busy;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) NSMutableDictionary *status;
@property(nonatomic) id alarmManager;
- (void)runPreviewOnly:(BOOL)preview manual:(BOOL)manual;
@end
@implementation DBEngine
- (instancetype)init {
    if((self=[super init])) {
        _status=[NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:DBStatusPath]?:@{}];
    }
    return self;
}
- (void)report:(NSString *)message code:(NSString *)code {
    NSString *line=[NSString stringWithFormat:@"%@ [%@] %@\n",NSDate.date,code,message];
    NSMutableString *log=[[NSString stringWithContentsOfFile:DBLogPath encoding:NSUTF8StringEncoding error:nil] mutableCopy]?:[NSMutableString new];
    [log appendString:line];
    if(log.length>120000) [log deleteCharactersInRange:NSMakeRange(0,log.length-100000)];
    [log writeToFile:DBLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.status[@"code"]=code; self.status[@"message"]=message; self.status[@"updated"]=NSDate.date;
    self.status[@"process"]=NSProcessInfo.processInfo.processName;
    [self.status writeToFile:DBStatusPath atomically:YES];
    NSLog(@"[Daybreak] %@: %@",code,message);
}
- (void)started {
    // Migrate only once: the previous diagnostic release forcibly disabled
    // automaticEnabled on each respring. Respect subsequent manual changes.
    if(!DBBoolean(@"nativeAutomationMigrated")) {
        DBStore(@"automaticEnabled",@YES);
        DBStore(@"nativeAutomationMigrated",@YES);
    }
    [self report:DBBoolean(@"automaticEnabled")?
        @"Hourly native Sleep automation enabled. The iPhone 13 checks tomorrow's calendar wake once per hour during the configured daytime window and attempts a one-day Sleep override when necessary.":
        @"Native Sleep automation paused by user. Calendar preview and one-time Apply are available."
          code:@"STARTED"];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(tick)
                                              userInfo:nil repeats:YES];
    [self performSelector:@selector(tick) withObject:nil afterDelay:25];
}
- (void)tick {
    if(!DBBoolean(@"automaticEnabled") || self.busy) return;
    NSInteger start=DBInteger(@"hourlyStartHour",12,12,23);
    NSInteger end=DBInteger(@"hourlyEndHour",23,12,23);
    NSDateComponents *c=[NSCalendar.currentCalendar components:NSCalendarUnitHour fromDate:NSDate.date];
    if(c.hour<start || c.hour>end || start>end) return;
    NSString *slot=[NSString stringWithFormat:@"%@-%02ld",DBDayKey(NSCalendar.currentCalendar,NSDate.date),(long)c.hour];
    if([DBString(@"lastHourlySlot") isEqualToString:slot]) return;
    // Each hour gets one fresh calendar calculation. A failed native attempt
    // can be retried next hour, but never loops every five minutes.
    DBStore(@"lastHourlySlot",slot);
    [self runPreviewOnly:NO manual:NO];
}
- (void)finish:(NSString *)message code:(NSString *)code {
    self.busy=NO; [self report:message code:code];
    if([@[@"CALENDAR_DENIED",@"CALENDAR_MISSING",@"CALENDAR_EXCEPTION",@"INVALID_DATE"] containsObject:code]) {
        NSString *key=[NSString stringWithFormat:@"%@:%@",DBDayKey(NSCalendar.currentCalendar,NSDate.date),code];
        if(![DBString(@"lastNotifiedPlanningFailure") isEqualToString:key]) {
            DBStore(@"lastNotifiedPlanningFailure",key);
            DBPostStatusNotification(@"planning-needs-attention",@"Daybreak calendar issue",message);
        }
    }
}
- (void)runPreviewOnly:(BOOL)preview manual:(BOOL)manual {
    if(self.busy) { [self report:@"Another plan/update is in progress." code:@"BUSY"]; return; }
    NSCalendar *calendar=NSCalendar.currentCalendar;
    NSDate *now=NSDate.date;
    NSDate *tomorrow=[calendar dateByAddingUnit:NSCalendarUnitDay value:1
                                           toDate:[calendar startOfDayForDate:now] options:0];
    NSString *morningKey=DBDayKey(calendar,tomorrow);
    if(!preview && [calendar component:NSCalendarUnitHour fromDate:now]<12) {
        [self report:@"Updates only run after noon, so the next Sleep alarm belongs to tomorrow." code:@"TOO_EARLY"]; return;
    }
    if(manual && !preview) {
        id fromApp=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("appPlannedWake"),(__bridge CFStringRef)DBPrefs));
        id timestamp=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("appPlanTimestamp"),(__bridge CFStringRef)DBPrefs));
        id plannedMorning=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("appPlanMorning"),(__bridge CFStringRef)DBPrefs));
        BOOL fresh=[fromApp isKindOfClass:NSDate.class] && [timestamp isKindOfClass:NSDate.class] &&
            [plannedMorning isKindOfClass:NSDate.class] &&
            [now timeIntervalSinceDate:timestamp]>=0 && [now timeIntervalSinceDate:timestamp]<60 &&
            DBIsSameDay(calendar,plannedMorning,tomorrow) && DBIsSameDay(calendar,fromApp,tomorrow) &&
            [fromApp timeIntervalSinceDate:now]>60;
        if(fresh) {
            DBStore(@"appPlanTimestamp",nil); // One-time handoff, never replay a cached app plan.
            self.busy=YES;
            [self report:@"Using the companion app's freshly authorized calendar plan (valid for 60 seconds)." code:@"APP_PLAN_READY"];
            [self applyWake:fromApp morning:tomorrow manual:YES];return;
        }
    }
    self.busy=YES;
    [self report:preview?@"Calculating tomorrow's wake preview.":@"Calculating tomorrow's wake update." code:@"PLANNING"];
    NSInteger lead=DBInteger(@"leadMinutes",60,0,720);
    NSInteger fallbackH=DBInteger(@"fallbackHour",8,0,23);
    NSInteger fallbackM=DBInteger(@"fallbackMinute",30,0,59);
    NSString *calendarID=DBString(@"calendarID");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        @autoreleasepool {
            @try {
                EKAuthorizationStatus access=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
                if(access!=EKAuthorizationStatusAuthorized) {
                    dispatch_async(dispatch_get_main_queue(),^{[self finish:[NSString stringWithFormat:@"Calendar access is %@ in SpringBoard (status %ld). No alarm changed. Check settings/diagnostics.",access==EKAuthorizationStatusDenied?@"denied":access==EKAuthorizationStatusRestricted?@"restricted":@"not granted",(long)access] code:@"CALENDAR_DENIED"];});
                    return;
                }
                EKEventStore *store=[EKEventStore new];
                NSArray<EKCalendar *> *selected=nil;
                if(calendarID.length) {
                    EKCalendar *found=[store calendarWithIdentifier:calendarID];
                    if(!found) {dispatch_async(dispatch_get_main_queue(),^{[self finish:@"Selected calendar no longer exists. Choose All calendars or update its identifier." code:@"CALENDAR_MISSING"];});return;}
                    selected=@[found];
                }
                NSDate *noon=[calendar dateBySettingHour:12 minute:0 second:0 ofDate:tomorrow options:0];
                NSPredicate *predicate=[store predicateForEventsWithStartDate:tomorrow endDate:noon calendars:selected];
                NSMutableArray<NSDate *> *starts=[NSMutableArray new];
                for(EKEvent *event in [store eventsMatchingPredicate:predicate]) {
                    if(event.isAllDay || event.status==EKEventStatusCanceled || !event.startDate) continue;
                    BOOL declined=NO;
                    for(EKParticipant *participant in event.attendees) {
                        if(participant.isCurrentUser && participant.participantStatus==EKParticipantStatusDeclined) {declined=YES;break;}
                    }
                    if(!declined) [starts addObject:event.startDate];
                }
                NSDictionary *plan=DBWakePlan(calendar,now,starts,lead,fallbackH,fallbackM);
                NSDate *wake=plan[@"wake"];
                BOOL valid=DBIsSameDay(calendar,wake,tomorrow) && [wake timeIntervalSinceDate:NSDate.date]>60;
                dispatch_async(dispatch_get_main_queue(),^{
                    self.status[@"plannedWake"]=wake;
                    self.status[@"morning"]=morningKey;
                    self.status[@"eventUsed"]=plan[@"usedEvent"];
                    [self report:[NSString stringWithFormat:@"Tomorrow %@: %@ at %@ (eligible events %lu, lead %ld min).",
                                  morningKey,[plan[@"usedEvent"] boolValue]?@"calendar event":@"fallback",wake,(unsigned long)starts.count,(long)lead]
                            code:preview?@"PREVIEW":@"PLAN_READY"];
                    if(preview) {self.busy=NO;return;}
                    if(!valid) {[self finish:@"Calculated wake time crossed into today or has passed. Refusing update." code:@"INVALID_DATE"];return;}
                    [self applyWake:wake morning:tomorrow manual:manual];
                });
            } @catch(NSException *exception) {
                dispatch_async(dispatch_get_main_queue(),^{[self finish:[NSString stringWithFormat:@"Calendar runtime exception: %@",exception.reason] code:@"CALENDAR_EXCEPTION"];});
            }
        }
    });
}
- (void)observe:(id)future completion:(void(^)(id,NSError *))completion {
    if(!future || ![future respondsToSelector:@selector(addSuccessBlock:)] ||
       ![future respondsToSelector:@selector(addFailureBlock:)]) {
        completion(nil,[NSError errorWithDomain:@"Daybreak" code:10 userInfo:@{NSLocalizedDescriptionKey:@"MobileTimer returned no supported asynchronous future"}]);return;
    }
    __block BOOL finished=NO;
    void (^finish)(id,NSError *)=^(id obj,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{if(finished)return;finished=YES;completion(obj,error);});
    };
    DBObjectCall(future,@"addSuccessBlock:",^(id value){finish(value,nil);});
    DBObjectCall(future,@"addFailureBlock:",^(NSError *error){finish(nil,error);});
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(!finished) finish(nil,[NSError errorWithDomain:@"Daybreak" code:12 userInfo:@{NSLocalizedDescriptionKey:@"MobileTimer timed out; outcome is unknown"}]);
    });
}
- (void)findNextSleepForMorning:(NSDate *)morning completion:(void(^)(id,NSError *))completion {
    if(!NSClassFromString(@"MTAlarmManager")) {
        completion(nil,[NSError errorWithDomain:@"Daybreak" code:20 userInfo:@{NSLocalizedDescriptionKey:@"MTAlarmManager unavailable"}]);return;
    }
    self.alarmManager=[[NSClassFromString(@"MTAlarmManager") alloc] init];
    [self observe:DBGet(self.alarmManager,@"sleepAlarms") completion:^(id alarms,NSError *error) {
        if(error) {completion(nil,error);return;}
        if(![alarms isKindOfClass:NSArray.class]) {
            completion(nil,[NSError errorWithDomain:@"Daybreak" code:21 userInfo:@{NSLocalizedDescriptionKey:@"Unexpected Sleep alarm collection"}]);return;
        }
        id selected=nil; NSUInteger candidates=0;
        for(id alarm in alarms) {
            unsigned long long isSleep=0,repeat=999;
            if(!DBNumber(alarm,@"isSleepAlarm",&isSleep) || !isSleep ||
               !DBNumber(alarm,@"repeatSchedule",&repeat) || repeat!=0) continue;
            NSDate *fire=DBGet(alarm,@"nextFireDate");
            if(![fire isKindOfClass:NSDate.class] || !DBIsSameDay(NSCalendar.currentCalendar,fire,morning)) continue;
            // Sleep schedules are Health-owned. Modify only an existing next-only override.
            if(!DBGet(alarm,@"overriddenForDate") && !DBGet(alarm,@"getOverriddenDate")) continue;
            selected=alarm; candidates++;
        }
        if(candidates!=1) {
            completion(nil,[NSError errorWithDomain:@"Daybreak" code:22 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Expected one exact next-only Sleep override, found %lu; recurring/base schedule untouched",(unsigned long)candidates]}]);return;
        }
        completion(selected,nil);
    }];
}
- (void)applyWake:(NSDate *)wake morning:(NSDate *)morning manual:(BOOL)manual {
    // The entire automated and manual path now calls Apple's native Sleep
    // framework. Never write a device-only MobileTimer alarm.
    DBStore(@"nativeSleepRequest",@{
        @"wake":wake, @"morning":morning, @"created":NSDate.date,
        @"identifier":NSUUID.UUID.UUIDString,
        @"origin":manual?@"manual":@"automatic"
    });
    self.status[@"requestedWake"]=wake;
    [self report:[NSString stringWithFormat:@"%@ native Sleep request queued for %@. SpringBoard is submitting it directly; Apple Health can retry the pending request when opened if this process lacks Sleep service access.",
                  manual?@"Manual":@"Automatic",wake] code:@"NATIVE_AUTO_SUBMITTED"];
    DBNativeSleepApplyIfRequested();
    self.busy=NO;
}
@end

static DBEngine *DBShared;
static void DBNotification(CFNotificationCenterRef center,void *observer,CFStringRef name,
                           const void *object,CFDictionaryRef userInfo) {
    (void)center;(void)observer;(void)object;(void)userInfo;
    NSString *notification=(__bridge NSString *)name;
    dispatch_async(dispatch_get_main_queue(),^{
        NSString *healthPrefix=@"com.soum91.daybreak.healthprobe.";
        if([notification hasPrefix:healthPrefix]) {
            NSString *result=[notification substringFromIndex:healthPrefix.length];
            // Sleep iCloud eligibility is diagnostic-only. Preserve the native
            // writer status and never notify or change alarms for these codes.
            if([result hasPrefix:@"sync_feature_"]) {
                DBShared.status[@"sleepCloudFeature"]=[result substringFromIndex:[@"sync_feature_" length]];
                DBShared.status[@"sleepCloudChecked"]=NSDate.date;
                [DBShared.status writeToFile:DBStatusPath atomically:YES];
                return;
            }
            if([result hasPrefix:@"sync_override_key_"]) {
                DBShared.status[@"sleepOverrideSyncKey"]=[result substringFromIndex:[@"sync_override_key_" length]];
                DBShared.status[@"sleepCloudChecked"]=NSDate.date;
                [DBShared.status writeToFile:DBStatusPath atomically:YES];
                return;
            }
            if([result hasPrefix:@"daemon_"]) {
                if([result isEqualToString:@"daemon_seen"])
                    DBShared.status[@"sleepDaemonSeen"]=@YES;
                else if([result hasPrefix:@"daemon_feature_"])
                    DBShared.status[@"sleepDaemonFeature"]=[result substringFromIndex:[@"daemon_feature_" length]];
                else if([result hasPrefix:@"daemon_original_"])
                    DBShared.status[@"sleepDaemonOriginalFeature"]=[result substringFromIndex:[@"daemon_original_" length]];
                else if([result hasPrefix:@"daemon_override_"])
                    DBShared.status[@"sleepDaemonOverride"]=[result substringFromIndex:[@"daemon_override_" length]];
                else if([result hasPrefix:@"daemon_cloud_"])
                    DBShared.status[@"sleepDaemonCloud"]=[result substringFromIndex:[@"daemon_cloud_" length]];
                else if([result hasPrefix:@"daemon_initial_"])
                    DBShared.status[@"sleepDaemonInitial"]=[result substringFromIndex:[@"daemon_initial_" length]];
                else if([result hasPrefix:@"daemon_pull_"])
                    DBShared.status[@"sleepDaemonPull"]=[result substringFromIndex:[@"daemon_pull_" length]];
                DBShared.status[@"sleepDaemonChecked"]=NSDate.date;
                [DBShared.status writeToFile:DBStatusPath atomically:YES];
                return;
            }
            if([result isEqualToString:@"native_request_consumed"]) {
                NSDictionary *request=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("nativeSleepRequest"),(__bridge CFStringRef)DBPrefs));
                if([request isKindOfClass:NSDictionary.class] && [request[@"wake"] isKindOfClass:NSDate.class])
                    DBShared.status[@"requestedWake"]=request[@"wake"];
                // A one-shot request must not replay on subsequent Health opens.
                DBStore(@"nativeSleepRequest",nil);
            }
            DBShared.status[@"healthProbe"]=result;
            DBShared.status[@"healthProbeUpdated"]=NSDate.date;
            if([result isEqualToString:@"native_readback_match"]) {
                NSString *morning=DBShared.status[@"morning"];
                if([morning isKindOfClass:NSString.class]) DBStore(@"lastSuccessMorning",morning);
                NSDate *wake=DBShared.status[@"requestedWake"];
                NSString *key=[NSString stringWithFormat:@"%@:%@",morning?:@"unknown",wake?:@"unknown"];
                if(![DBString(@"lastNotifiedSuccess") isEqualToString:key]) {
                    DBStore(@"lastNotifiedSuccess",key);
                    NSDateFormatter *formatter=[NSDateFormatter new];formatter.timeStyle=NSDateFormatterShortStyle;
                    NSString *time=[wake isKindOfClass:NSDate.class]?[formatter stringFromDate:wake]:@"requested time";
                    DBPostStatusNotification(@"sleep-updated",@"Daybreak: Sleep updated",
                        [NSString stringWithFormat:@"Tomorrow's native Sleep wake time is %@ on this iPhone. iPhone 17 / Watch delivery is not confirmed.",time]);
                }
            } else if([result hasPrefix:@"native_"] && ![@[@"native_request_consumed",@"native_write_submitted",@"native_api_ready",@"native_request_missing",@"native_already_matched"] containsObject:result]) {
                NSString *today=DBDayKey(NSCalendar.currentCalendar,NSDate.date);
                NSString *key=[NSString stringWithFormat:@"%@:%@",today,result];
                if(![DBString(@"lastNotifiedFailure") isEqualToString:key]) {
                    DBStore(@"lastNotifiedFailure",key);
                    DBPostStatusNotification(@"sleep-needs-attention",@"Daybreak needs attention",
                        [NSString stringWithFormat:@"Native Sleep update status: %@. Open Daybreak diagnostics.",result]);
                }
            }
            if([result hasPrefix:@"native_"]) {
                [DBShared report:[NSString stringWithFormat:@"Health native schedule operation: %@. iPhone 17 and Watch sync remain unverified until inspected.",result] code:@"NATIVE_HEALTH"];
            } else {
                [DBShared report:[NSString stringWithFormat:@"Health app read-only schedule probe: %@. No Sleep data or alarm was modified by this probe.",result] code:@"HEALTH_PROBE"];
            }
        }
        else if([notification isEqualToString:@"com.soum91.daybreak.forceautomation"]) [DBShared runPreviewOnly:NO manual:YES];
        else if([notification isEqualToString:@"com.soum91.daybreak.preview"]) [DBShared runPreviewOnly:YES manual:YES];
        else if([notification isEqualToString:@"com.soum91.daybreak.apply"]) [DBShared runPreviewOnly:NO manual:YES];
        else [DBShared tick];
    });
}

__attribute__((constructor)) static void DBLaunch(void) {
    @autoreleasepool {
        // The alarm writer remains confined to SpringBoard and Health.
        // A separate observational dylib inspects sleepd's cloud state.
        if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"])return;
        dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer",RTLD_NOW|RTLD_GLOBAL);
        dispatch_async(dispatch_get_main_queue(),^{
            DBShared=[DBEngine new];
            CFNotificationCenterRef center=CFNotificationCenterGetDarwinNotifyCenter();
            for(NSString *notification in @[@"com.soum91.daybreak.preferences",@"com.soum91.daybreak.preview",@"com.soum91.daybreak.apply",@"com.soum91.daybreak.forceautomation"])
                CFNotificationCenterAddObserver(center,NULL,DBNotification,(__bridge CFStringRef)notification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
            for(NSString *result in @[@"class_missing",@"type_missing",@"type_invalid",@"type_available",@"query_error",@"query_empty",@"schedule_found",@"unexpected_sample",@"query_unavailable",@"probe_exception",
                @"native_framework_missing",@"native_api_missing",@"native_model_unavailable",@"native_schedule_unavailable",
                @"native_api_ready",@"native_probe_exception",@"native_request_missing",@"native_request_invalid",@"native_next_day_mismatch",
                @"native_override_api_missing",@"native_override_unavailable",@"native_alarm_off",
                @"native_components_missing",@"native_components_invalid",@"native_occurrence_invalid",
                @"native_repeating_guard",@"native_preview_mismatch",@"native_request_consumed",
                @"native_write_submitted",@"native_save_rejected",@"native_already_matched",@"native_readback_match",
                @"native_readback_unverified",@"native_readback_exception",@"native_write_exception",
                @"sync_feature_on",@"sync_feature_off",@"sync_feature_unknown",
                @"sync_override_key_yes",@"sync_override_key_no",@"sync_override_key_unknown",
                @"daemon_seen",@"daemon_feature_on",@"daemon_feature_off",@"daemon_feature_unknown",
                @"daemon_original_on",@"daemon_original_off",@"daemon_original_unknown",
                @"daemon_override_enabled",@"daemon_override_disabled",
                @"daemon_cloud_on",@"daemon_cloud_off",@"daemon_cloud_unknown",
                @"daemon_initial_pending",@"daemon_initial_clear",@"daemon_initial_unknown",
                @"daemon_pull_pending",@"daemon_pull_clear",@"daemon_pull_unknown"]) {
                NSString *name=[@"com.soum91.daybreak.healthprobe." stringByAppendingString:result];
                CFNotificationCenterAddObserver(center,NULL,DBNotification,(__bridge CFStringRef)name,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
            }
            [DBShared started];
        });
    }
}
