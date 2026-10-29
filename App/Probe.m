#import "Probe.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>

// These are observed runtime interfaces, not linked private SDK declarations.
// Every call checks availability; changed signatures fail closed.
static id Get(id o, NSString *name) {
    SEL s = NSSelectorFromString(name);
    NSMethodSignature *sig = [o methodSignatureForSelector:s];
    if (!sig || sig.numberOfArguments != 2 || sig.methodReturnType[0] != '@') return nil;
    return ((id(*)(id,SEL))objc_msgSend)(o,s);
}
static unsigned long long Number(id o, NSString *name) {
    SEL s=NSSelectorFromString(name);
    NSMethodSignature *sig=[o methodSignatureForSelector:s];
    if (!sig || sig.numberOfArguments!=2) return 0;
    char t=sig.methodReturnType[0];
    if (strchr("BcCsSiIlLqQ",t)==NULL) return 0;
    NSInvocation *call=[NSInvocation invocationWithMethodSignature:sig];
    call.target=o; call.selector=s; [call invoke];
    unsigned long long value=0;
    if (sig.methodReturnLength<=sizeof(value)) [call getReturnValue:&value];
    return value;
}
static BOOL SetNumber(id o, NSString *name, unsigned long long value) {
    SEL s=NSSelectorFromString(name);
    NSMethodSignature *sig=[o methodSignatureForSelector:s];
    if (!sig || sig.numberOfArguments!=3 || sig.methodReturnType[0]!='v' ||
        !strchr("BcCsSiIlLqQ",[sig getArgumentTypeAtIndex:2][0])) return NO;
    NSInvocation *call=[NSInvocation invocationWithMethodSignature:sig];
    call.target=o; call.selector=s; [call setArgument:&value atIndex:2]; [call invoke];
    return YES;
}
static id ObjectCall(id o, NSString *name, id arg) {
    SEL s=NSSelectorFromString(name);
    NSMethodSignature *sig=[o methodSignatureForSelector:s];
    if (!sig || sig.numberOfArguments!=3 || sig.methodReturnType[0]!='@' ||
        [sig getArgumentTypeAtIndex:2][0]!='@') return nil;
    return ((id(*)(id,SEL,id))objc_msgSend)(o,s,arg);
}
static BOOL HasInitializer(id object, SEL selector, const char *arguments) {
    NSMethodSignature *sig=[object methodSignatureForSelector:selector];
    size_t count=strlen(arguments);
    if(!sig || sig.numberOfArguments!=count+2 || sig.methodReturnType[0]!='@') return NO;
    for(size_t i=0;i<count;i++) if([sig getArgumentTypeAtIndex:i+2][0]!=arguments[i]) return NO;
    return YES;
}
static NSString *Methods(Class cls) {
    if (!cls) return @"unavailable";
    NSMutableArray *names=[NSMutableArray array];
    unsigned int count=0; Method *methods=class_copyMethodList(cls,&count);
    for(unsigned int i=0;i<count;i++) {
        NSString *name=NSStringFromSelector(method_getName(methods[i]));
        if ([name.lowercaseString containsString:@"alarm"] ||
            [name.lowercaseString containsString:@"operation"] ||
            [name.lowercaseString containsString:@"time"] ||
            [name.lowercaseString containsString:@"shortcut"])
            [names addObject:[NSString stringWithFormat:@"%@ [%s]",name,method_getTypeEncoding(methods[i])]];
    }
    free(methods); return [[names sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"\n"];
}

@interface Probe ()
@property(nonatomic) NSMutableString *lines;
@property(nonatomic, readwrite) NSString *status;
@property(nonatomic, readwrite) BOOL busy;
@property(nonatomic) id manager;
@property(nonatomic) id alarm;
@property(nonatomic) id original;
- (void)applyFreshOverrideTo:(NSDate *)date;
@end

@implementation Probe
- (NSURL *)logURL {
    return [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"Daybreak-diagnostic.txt"];
}
- (NSURL *)backupURL { return [[self logURL].URLByDeletingLastPathComponent URLByAppendingPathComponent:@"SleepOverride.archive"]; }
- (instancetype)init {
    if ((self=[super init])) {
        NSString *previous=[NSString stringWithContentsOfURL:self.logURL encoding:NSUTF8StringEncoding error:nil];
        _lines=[NSMutableString stringWithString:previous?:@""];
        _status=@"Ready to inspect";
        [self note:[NSString stringWithFormat:@"\nDaybreak %@ (%@) / %@ %@ / %@",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],UIDevice.currentDevice.model,UIDevice.currentDevice.systemVersion,NSProcessInfo.processInfo.operatingSystemVersionString]];
        @try {
            NSData *data=[NSData dataWithContentsOfURL:self.backupURL];
            // Only our own previously archived snapshot; never import untrusted archives.
            if (data) {
                dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer",RTLD_NOW);
                _original=[NSKeyedUnarchiver unarchiveTopLevelObjectWithData:data error:nil];
                [self note:_original?@"Previous restore snapshot recovered.":@"Restore snapshot could not be decoded."];
            }
        } @catch(NSException *e) { [self note:[NSString stringWithFormat:@"Snapshot exception: %@",e.reason]]; }
    } return self;
}
- (NSString *)report { return [self.lines copy]; }
- (void)note:(NSString *)message {
    if(!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{[self note:message];}); return; }
    [self.lines appendFormat:@"%@ %@\n",[NSDate.now description],message];
    if (self.lines.length>120000) [self.lines deleteCharactersInRange:NSMakeRange(0,self.lines.length-100000)];
    [self.lines writeToURL:self.logURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if(self.changed) self.changed();
}
- (void)state:(NSString *)state { self.status=state; if(self.changed) self.changed(); }
- (BOOL)hasOverride {
    // Never update a recurring/base schedule in this diagnostic.
    return self.alarm && Number(self.alarm,@"isSleepAlarm") &&
        Number(self.alarm,@"repeatSchedule")==0 &&
        (Get(self.alarm,@"overriddenForDate") || Get(self.alarm,@"getOverriddenDate"));
}
- (BOOL)canRestore { return self.original!=nil; }
- (void)observeFuture:(id)future completion:(void(^)(id,NSError *))completion {
    if(!future || ![future respondsToSelector:NSSelectorFromString(@"addSuccessBlock:")] ||
       ![future respondsToSelector:NSSelectorFromString(@"addFailureBlock:")]) {
        completion(nil,[NSError errorWithDomain:@"Daybreak" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Expected asynchronous result interface is unavailable; no success assumed."}]); return;
    }
    __block BOOL finished=NO;
    void (^finish)(id,NSError *)=^(id result,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            if(finished) return; finished=YES; completion(result,error);
        });
    };
    ObjectCall(future,@"addSuccessBlock:",^(id value){finish(value,nil);});
    ObjectCall(future,@"addFailureBlock:",^(NSError *error){finish(nil,error);});
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(!finished) finish(nil,[NSError errorWithDomain:@"Daybreak.Timeout" code:12 userInfo:@{NSLocalizedDescriptionKey:@"No reply after 12 seconds. Permission denial or unavailable service is possible. Outcome unknown."}]);
    });
}
- (void)readAlarm:(void(^)(id,NSError *))completion {
    Class cls=NSClassFromString(@"MTAlarmManager");
    if(!cls) { completion(nil,[NSError errorWithDomain:@"Daybreak" code:2 userInfo:@{NSLocalizedDescriptionKey:@"MobileTimer manager class unavailable."}]); return; }
    self.manager=[[cls alloc] init];
    id result=Get(self.manager,@"sleepAlarms");
    if(!result) { completion(nil,[NSError errorWithDomain:@"Daybreak" code:3 userInfo:@{NSLocalizedDescriptionKey:@"sleepAlarms returned no asynchronous result."}]); return; }
    [self observeFuture:result completion:^(id value,NSError *error){
        @try {
        if(error) { completion(nil,error); return; }
        if(![value isKindOfClass:NSArray.class]) {
            completion(nil,[NSError errorWithDomain:@"Daybreak" code:4 userInfo:@{NSLocalizedDescriptionKey:@"Unexpected alarm collection type."}]); return;
        }
        id chosen=nil; NSDate *earliest=nil;
        for(id item in value) {
            if(!Number(item,@"isSleepAlarm")) continue;
            NSDate *date=Get(item,@"nextFireDate");
            if(![date isKindOfClass:NSDate.class] || [date timeIntervalSinceNow]<=0) continue;
            if(!earliest || [date compare:earliest]==NSOrderedAscending ||
               ([date compare:earliest]==NSOrderedSame && Get(item,@"overriddenForDate"))) {
                chosen=item; earliest=date;
            }
        }
        [self note:[NSString stringWithFormat:@"Sleep alarm collection: %lu entries; selected next future alarm: %@",(unsigned long)[value count],chosen?@"yes":@"no"]];
        completion(chosen,nil);
        } @catch(NSException *exception) {
            completion(nil,[NSError errorWithDomain:@"Daybreak.Runtime" code:5 userInfo:@{NSLocalizedDescriptionKey:exception.reason?:@"Unexpected alarm result interface"}]);
        }
    }];
}
- (void)scan {
    if(self.busy) return; self.busy=YES; self.alarm=nil; [self state:@"Inspecting runtime…"];
    @try {
        for(NSString *name in @[@"MobileTimer",@"Sleep",@"AssistantServices"]) {
            NSString *path=[NSString stringWithFormat:@"/System/Library/PrivateFrameworks/%@.framework/%@",name,name];
            void *handle=dlopen(path.UTF8String,RTLD_NOW);
            [self note:[NSString stringWithFormat:@"Load %@: %@",name,handle?@"available":@"unavailable"]];
        }
        for(NSString *name in @[@"INUpdateAlarmIntent",@"INAlarmSearch",@"INSleepAlarmAttribute",@"MTAlarmManager"]) {
            [self note:[NSString stringWithFormat:@"%@ methods:\n%@",name,Methods(NSClassFromString(name))]];
        }
        [self readAlarm:^(id alarm,NSError *error){
            self.busy=NO; self.alarm=alarm;
            if(error) { [self note:[NSString stringWithFormat:@"Read blocked/failed: %@ (%@/%ld) %@",error.localizedDescription,error.domain,(long)error.code,error.userInfo]]; [self state:@"Alarm access failed; see report"]; }
            else if(!alarm) [self state:@"No future Sleep alarm returned"];
            else {
                [self note:[NSString stringWithFormat:@"Selected: %02llu:%02llu; enabled=%llu; repeat=%llu; override=%@; next=%@",Number(alarm,@"hour"),Number(alarm,@"minute"),Number(alarm,@"isEnabled"),Number(alarm,@"repeatSchedule"),Get(alarm,@"overriddenForDate"),Get(alarm,@"nextFireDate")]];
                [self state:self.hasOverride?@"Next-only override available for testing":@"Base schedule detected; direct edit disabled"];
            }
        }];
    } @catch(NSException *e) { self.busy=NO; [self note:[NSString stringWithFormat:@"Scan exception: %@ %@",e.name,e.reason]]; [self state:@"Runtime interface differs; see report"]; }
}
- (void)verifyHour:(NSUInteger)hour minute:(NSUInteger)minute enabled:(BOOL)enabled {
    [self readAlarm:^(id alarm,NSError *error){
        self.busy=NO; self.alarm=alarm;
        BOOL matches=!error && alarm && Number(alarm,@"hour")==hour && Number(alarm,@"minute")==minute && !!Number(alarm,@"isEnabled")==enabled;
        [self note:[NSString stringWithFormat:@"Fresh manager read-back: %@. %@",matches?@"time and enabled state match":@"NOT verified",error?:@"Check Clock → Sleep | Wake Up to confirm the visible result."]];
        [self state:matches?@"Read-back matches; confirm in Clock":@"Change not verified; see report"];
    }];
}
- (void)writeAlarm:(id)alarm expectedHour:(NSUInteger)hour minute:(NSUInteger)minute enabled:(BOOL)enabled {
    self.busy=YES; [self state:@"Requesting override update…"];
    [self note:[NSString stringWithFormat:@"Calling updateAlarm for existing next-only override → %02lu:%02lu, enabled=%d",(unsigned long)hour,(unsigned long)minute,enabled]];
    id future=ObjectCall(self.manager,@"updateAlarm:",alarm);
    [self observeFuture:future completion:^(id result,NSError *error){
        if(error) {
            self.busy=NO; [self state:@"Update failed or outcome unknown"];
            [self note:[NSString stringWithFormat:@"Update error: %@ (%@/%ld) %@",error.localizedDescription,error.domain,(long)error.code,error.userInfo]];
            return;
        }
        [self note:@"Update callback returned without error; this alone is NOT verification."];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
            @try { [self verifyHour:hour minute:minute enabled:enabled]; }
            @catch(NSException *e){self.busy=NO; [self note:e.reason]; [self state:@"Read-back exception; outcome unknown"];}
        });
    }];
}
- (void)changeOverrideTo:(NSDate *)date {
    if(self.busy) return;
    id expectedID=Get(self.alarm,@"alarmID");
    if(!self.hasOverride || !expectedID) { [self note:@"No exact next-only override selected."]; return; }
    self.busy=YES; [self state:@"Rechecking next-only override…"];
    @try {
        [self readAlarm:^(id current,NSError *error) {
            @try {
                self.alarm=current;
                if(error || !self.hasOverride || ![Get(current,@"alarmID") isEqual:expectedID]) {
                    self.busy=NO; [self note:[NSString stringWithFormat:@"Override changed or re-read failed; no write submitted. %@",error?:@""]];
                    [self state:@"Inspect again before changing the alarm"]; return;
                }
                [self applyFreshOverrideTo:date];
            } @catch(NSException *e) { self.busy=NO; [self note:e.reason]; [self state:@"Override recheck failed"]; }
        }];
    } @catch(NSException *e) { self.busy=NO; [self note:e.reason]; [self state:@"Override recheck failed"]; }
}
- (void)applyFreshOverrideTo:(NSDate *)date {
    @try {
        if(!self.hasOverride){self.busy=NO;[self note:@"Refused: no verified next-only override. Recurring schedule will not be edited."];return;}
        NSDate *fire=Get(self.alarm,@"nextFireDate");
        NSDateComponents *time=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
        NSDate *target=[NSCalendar.currentCalendar dateBySettingHour:time.hour minute:time.minute second:0 ofDate:fire options:0];
        if(!target || target.timeIntervalSinceNow<60){self.busy=NO;[self state:@"Choose a future time on the next alarm’s date"];return;}
        if(!self.original || ![Get(self.original,@"alarmID") isEqual:Get(self.alarm,@"alarmID")]) {
            self.original=[self.alarm copy];
            NSError *error=nil;
            NSData *data=[NSKeyedArchiver archivedDataWithRootObject:self.original requiringSecureCoding:NO error:&error];
            if(!data || ![data writeToURL:self.backupURL options:NSDataWritingAtomic error:&error]) {
                self.original=nil; self.busy=NO; [self note:[NSString stringWithFormat:@"Cannot save restore snapshot: %@",error]]; return;
            }
        }
        id candidate=[self.alarm mutableCopy];
        if(!SetNumber(candidate,@"setHour:",time.hour) || !SetNumber(candidate,@"setMinute:",time.minute) || !SetNumber(candidate,@"setEnabled:",YES)) {
            self.busy=NO; [self note:@"Required setter signature unavailable; no update submitted."];return;
        }
        [self writeAlarm:candidate expectedHour:time.hour minute:time.minute enabled:YES];
    } @catch(NSException *e){self.busy=NO; [self note:[NSString stringWithFormat:@"Update exception: %@ %@",e.name,e.reason]]; [self state:@"Update exception; inspect Clock"];} 
}
- (void)restore {
    if(self.busy || !self.original) return;
    @try {
        self.busy=YES; [self state:@"Checking restore target…"];
        [self readAlarm:^(id current,NSError *error){
            @try {
                self.alarm=current;
                if(error || !self.hasOverride || ![Get(current,@"alarmID") isEqual:Get(self.original,@"alarmID")] ||
                   ![Get(self.original,@"nextFireDate") isKindOfClass:NSDate.class] || [Get(self.original,@"nextFireDate") timeIntervalSinceNow]<60) {
                    self.busy=NO; [self state:@"Restore target expired or changed"];
                    [self note:@"Refused stale restore: current future override must match saved alarm ID."];return;
                }
                [self writeAlarm:[self.original mutableCopy] expectedHour:Number(self.original,@"hour") minute:Number(self.original,@"minute") enabled:Number(self.original,@"isEnabled")];
            } @catch(NSException *e){self.busy=NO;[self note:e.reason];}
        }];
    } @catch(NSException *e){self.busy=NO;[self note:e.reason];}
}
- (INShortcut *)shortcutForDate:(NSDate *)date {
    @try {
        Class cls=NSClassFromString(@"INUpdateAlarmIntent");
        if(!cls){[self note:@"INUpdateAlarmIntent unavailable on this OS."];return nil;}
        // Resolve the operation by its runtime enum string instead of guessing a numeric value.
        id pb=[[NSClassFromString(@"_INPBUpdateAlarmIntent") alloc] init];
        SEL enumSel=NSSelectorFromString(@"operationAsString:");
        NSInteger operation=-1;
        if([pb respondsToSelector:enumSel]) for(int i=0;i<24;i++) {
            NSString *name=((id(*)(id,SEL,int))objc_msgSend)(pb,enumSel,i);
            [self note:[NSString stringWithFormat:@"Alarm update operation %d = %@",i,name]];
            NSString *compact=[name.lowercaseString stringByReplacingOccurrencesOfString:@"_" withString:@""];
            if([compact isEqual:@"settime"] || [compact isEqual:@"changetime"] || [compact isEqual:@"updatetime"]) operation=i;
        }
        if(operation<0){[self note:@"No unambiguous set-time operation found. Siri shortcut not constructed."];return nil;}
        // Reuse only a real, positively identified Sleep alarm. No invented identifiers or broad searches.
        if(!self.alarm || !Number(self.alarm,@"isSleepAlarm")) {
            [self note:@"Cannot construct an exact-target Siri shortcut: access to the actual Sleep alarm was not granted. Class availability is not permission."]; return nil;
        }
        NSDate *fire=Get(self.alarm,@"nextFireDate");
        NSDateComponents *hm=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
        NSDate *target=[NSCalendar.currentCalendar dateBySettingHour:hm.hour minute:hm.minute second:0 ofDate:fire options:0];
        if(!target || target.timeIntervalSinceNow<60){[self note:@"Siri target must be a future time on the next alarm’s date."];return nil;}
        NSDateComponents *components=[NSCalendar.currentCalendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:target];
        components.calendar=NSCalendar.currentCalendar; components.timeZone=NSTimeZone.localTimeZone;
        INDateComponentsRange *range=[[INDateComponentsRange alloc] initWithStartDateComponents:components endDateComponents:nil];
        id attrClass=NSClassFromString(@"INSleepAlarmAttribute");
        SEL attrInit=NSSelectorFromString(@"initWithBedtime:override:");
        id attr=[attrClass alloc];
        if(!HasInitializer(attr,attrInit,"@@")){[self note:@"Sleep override attribute interface unavailable or changed."];return nil;}
        attr=((id(*)(id,SEL,id,id))objc_msgSend)(attr,attrInit,nil,@YES);
        id model=[NSClassFromString(@"INAlarm") alloc];
        SEL modelInit=NSSelectorFromString(@"initWithIdentifier:dateTime:label:enabled:firing:alarmRepeatScheduleOptions:sleepAlarmAttribute:");
        if(!HasInitializer(model,modelInit,"@@@@@Q@")){[self note:@"INAlarm initializer unavailable or changed."];return nil;}
        NSString *identifier=Get(self.alarm,@"alarmIDString")?:[Get(self.alarm,@"alarmID") UUIDString];
        if(!identifier.length){[self note:@"Actual Sleep alarm has no identifier; refusing broad matching."];return nil;}
        model=((id(*)(id,SEL,id,id,id,id,id,unsigned long long,id))objc_msgSend)(model,modelInit,identifier,nil,[[INSpeakableString alloc] initWithSpokenPhrase:@"Sleep | Wake Up"],@YES,@NO,0,attr);
        id intent=[cls alloc];
        SEL init=NSSelectorFromString(@"initWithAlarmSearch:alarm:operation:proposedTime:proposedLabel:");
        if(!HasInitializer(intent,init,"@@q@@")){[self note:@"Update intent initializer unavailable or changed."];return nil;}
        intent=((id(*)(id,SEL,id,id,long long,id,id))objc_msgSend)(intent,init,nil,model,(long long)operation,range,nil);
        if(![intent isKindOfClass:INIntent.class]){[self note:@"No INIntent returned."];return nil;}
        ((INIntent *)intent).suggestedInvocationPhrase=@"Adjust my next sleep alarm";
        NSError *archiveError=nil;
        NSData *archive=[NSKeyedArchiver archivedDataWithRootObject:intent requiringSecureCoding:YES error:&archiveError];
        [self note:[NSString stringWithFormat:@"Internal update intent constructed; serializes=%@; proposed time=%@",archive?@"yes":archiveError.localizedDescription,target]];
        INShortcut *shortcut=[[INShortcut alloc] initWithIntent:intent];
        [self note:shortcut?@"INShortcut accepted the intent. Saving/running it is a separate test; no alarm change is claimed.":@"INShortcut rejected the internal intent."];
        return shortcut;
    } @catch(NSException *e){[self note:[NSString stringWithFormat:@"Siri capability exception: %@ %@",e.name,e.reason]];return nil;}
}
@end
