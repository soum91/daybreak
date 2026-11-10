#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <string.h>
#import "DBPlanner.h"

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
static id DBObjectID(id alarm) { return DBGet(alarm,@"alarmID"); }
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
static BOOL DBSetNumber(id obj, NSString *name, unsigned long long value) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[obj methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=3 || signature.methodReturnType[0]!='v' ||
       !strchr("BcCsSiIlLqQ",[signature getArgumentTypeAtIndex:2][0])) return NO;
    NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:signature];
    invocation.target=obj; invocation.selector=selector;
    [invocation setArgument:&value atIndex:2]; [invocation invoke]; return YES;
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
    [self report:@"SpringBoard engine loaded. Auto-update requires explicit enable in Settings." code:@"STARTED"];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(tick)
                                              userInfo:nil repeats:YES];
    [self performSelector:@selector(tick) withObject:nil afterDelay:25];
}
- (void)tick {
    if(!DBBoolean(@"automaticEnabled") || self.busy) return;
    NSInteger hour=DBInteger(@"runHour",18,12,23);
    NSDateComponents *c=[NSCalendar.currentCalendar components:NSCalendarUnitHour fromDate:NSDate.date];
    if(c.hour<hour) return;
    [self runPreviewOnly:NO manual:NO];
}
- (void)finish:(NSString *)message code:(NSString *)code {
    self.busy=NO; [self report:message code:code];
}
- (void)runPreviewOnly:(BOOL)preview manual:(BOOL)manual {
    if(self.busy) { [self report:@"Another plan/update is in progress." code:@"BUSY"]; return; }
    NSCalendar *calendar=NSCalendar.currentCalendar;
    NSDate *now=NSDate.date;
    NSDate *tomorrow=[calendar dateByAddingUnit:NSCalendarUnitDay value:1
                                           toDate:[calendar startOfDayForDate:now] options:0];
    NSString *morningKey=DBDayKey(calendar,tomorrow);
    if(!preview && !manual && [DBString(@"lastAttemptMorning") isEqual:morningKey]) return;
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
    // Count failures as attempts too: never keep retrying an unclear Sleep write.
    if(!preview && !manual) DBStore(@"lastAttemptMorning",morningKey);
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
    [self findNextSleepForMorning:morning completion:^(id original,NSError *error) {
        if(error) {[self finish:[NSString stringWithFormat:@"Cannot target next-only Sleep override: %@",error.localizedDescription] code:@"TARGET_UNAVAILABLE"];return;}
        @try {
            id alarmID=DBGet(original,@"alarmID");
            id candidate=[original mutableCopy];
            NSDateComponents *time=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:wake];
            unsigned long long originalEnabled=0;
            if(!alarmID || !candidate || !DBNumber(original,@"isEnabled",&originalEnabled) ||
               !DBSetNumber(candidate,@"setHour:",(unsigned long long)time.hour) ||
               !DBSetNumber(candidate,@"setMinute:",(unsigned long long)time.minute) ||
               (DBBoolean(@"enableNextSleepAlarm") && !DBSetNumber(candidate,@"setEnabled:",YES))) {
                [self finish:@"Target has incompatible identifiers or setter signatures. No update sent." code:@"INCOMPATIBLE_RUNTIME"];return;
            }
            self.status[@"originalHour"]=[NSNumber numberWithUnsignedLongLong:({unsigned long long v=0;DBNumber(original,@"hour",&v);v;})];
            self.status[@"originalMinute"]=[NSNumber numberWithUnsignedLongLong:({unsigned long long v=0;DBNumber(original,@"minute",&v);v;})];
            [self report:@"Submitted updateAlarm for matching next-only Sleep override. Awaiting callback and fresh read-back." code:@"UPDATE_SENT"];
            [self observe:DBObjectCall(self.alarmManager,@"updateAlarm:",candidate) completion:^(id result,NSError *updateError) {
                (void)result;
                if(updateError) {[self finish:[NSString stringWithFormat:@"MobileTimer rejected or timed out: %@",updateError.localizedDescription] code:@"UPDATE_UNVERIFIED"];return;}
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                    [self findNextSleepForMorning:morning completion:^(id fresh,NSError *readError) {
                        unsigned long long actualH=999,actualM=999,enabled=0;
                        BOOL matches=!readError && [DBObjectID(fresh) isEqual:alarmID] &&
                            DBNumber(fresh,@"hour",&actualH) && DBNumber(fresh,@"minute",&actualM) &&
                            DBNumber(fresh,@"isEnabled",&enabled) && actualH==(unsigned long long)time.hour &&
                            actualM==(unsigned long long)time.minute &&
                            (!DBBoolean(@"enableNextSleepAlarm") || enabled);
                        if(matches) {DBStore(@"lastSuccessMorning",DBDayKey(NSCalendar.currentCalendar,morning));
                            [self finish:[NSString stringWithFormat:@"Fresh MobileTimer read-back matches the requested next-only Sleep time (enabled=%@). Verify it visually in Clock on this device.",enabled?@"yes":@"no"] code:@"READBACK_MATCH"];}
                        else [self finish:[NSString stringWithFormat:@"No matching fresh Sleep read-back (error %@, H=%llu, M=%llu). Check Clock; outcome unverified.",readError.localizedDescription?:@"none",actualH,actualM] code:@"READBACK_MISMATCH"];
                    }];
                });
            }];
        } @catch(NSException *exception) {[self finish:[NSString stringWithFormat:@"Private MobileTimer exception: %@",exception.reason] code:@"RUNTIME_EXCEPTION"];}
    }];
}
@end

static DBEngine *DBShared;
static void DBNotification(CFNotificationCenterRef center,void *observer,CFStringRef name,
                           const void *object,CFDictionaryRef userInfo) {
    (void)center;(void)observer;(void)object;(void)userInfo;
    NSString *notification=(__bridge NSString *)name;
    dispatch_async(dispatch_get_main_queue(),^{
        if([notification isEqualToString:@"com.soum91.daybreak.preview"]) [DBShared runPreviewOnly:YES manual:YES];
        else if([notification isEqualToString:@"com.soum91.daybreak.apply"]) [DBShared runPreviewOnly:NO manual:YES];
        else [DBShared tick];
    });
}

__attribute__((constructor)) static void DBLaunch(void) {
    @autoreleasepool {
        // Only SpringBoard's long-lived process; no hooks into Clock, sleepd or mobiletimerd.
        if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"])return;
        dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer",RTLD_NOW|RTLD_GLOBAL);
        dispatch_async(dispatch_get_main_queue(),^{
            DBShared=[DBEngine new];
            CFNotificationCenterRef center=CFNotificationCenterGetDarwinNotifyCenter();
            for(NSString *notification in @[@"com.soum91.daybreak.preferences",@"com.soum91.daybreak.preview",@"com.soum91.daybreak.apply"])
                CFNotificationCenterAddObserver(center,NULL,DBNotification,(__bridge CFStringRef)notification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
            [DBShared started];
        });
    }
}
