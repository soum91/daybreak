#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>
#import <objc/message.h>
#import <notify.h>

// Do not access the Health SQLite database, mutate any samples, or request
// authorization. This code only runs in Apple's own Health app, once on launch.
// The Darwin notifications contain fixed non-personal result codes, not data.
static void DBHPResult(const char *result) {
    NSString *name=[@"com.soum91.daybreak.healthprobe." stringByAppendingString:[NSString stringWithUTF8String:result]];
    notify_post(name.UTF8String);
}

static void DBHPRun(void) {
    @autoreleasepool {
        @try {
            Class objectType=NSClassFromString(@"HKObjectType");
            Class scheduleClass=NSClassFromString(@"HKSleepSchedule");
            SEL selector=NSSelectorFromString(@"sleepScheduleType");
            if(!scheduleClass) { DBHPResult("class_missing"); return; }
            if(![objectType respondsToSelector:selector]) { DBHPResult("type_missing"); return; }
            id type=((id(*)(id,SEL))objc_msgSend)(objectType,selector);
            if(![type isKindOfClass:HKSampleType.class]) { DBHPResult("type_invalid"); return; }
            DBHPResult("type_available");

            // Read at most one private schedule sample. Only existence and
            // runtime object type are transmitted, never sleep times or dates.
            HKHealthStore *store=[HKHealthStore new];
            HKSampleQuery *query=[[HKSampleQuery alloc]
                initWithSampleType:(HKSampleType *)type
                         predicate:nil
                             limit:1
                   sortDescriptors:nil
                    resultsHandler:^(HKSampleQuery *finished, NSArray<HKSample *> *samples, NSError *error) {
                (void)finished;
                if(error) DBHPResult("query_error");
                else if(samples.count==0) DBHPResult("query_empty");
                else if([samples.firstObject isKindOfClass:scheduleClass]) DBHPResult("schedule_found");
                else DBHPResult("unexpected_sample");
            }];
            if(!query) { DBHPResult("query_unavailable"); return; }
            [store executeQuery:query];
        } @catch(NSException *exception) {
            (void)exception;
            DBHPResult("probe_exception");
        }
    }
}

__attribute__((constructor)) static void DBHPStart(void) {
    @autoreleasepool {
        if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Health"]) return;
        // Let the host finish launch and initialize its HealthKit session.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),
                       dispatch_get_main_queue(),^{ DBHPRun(); });
    }
}
