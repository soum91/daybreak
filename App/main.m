#import <UIKit/UIKit.h>
#import <IntentsUI/IntentsUI.h>
#import "Probe.h"
#import <EventKit/EventKit.h>

static NSDictionary *WakePlan(NSCalendar *calendar, NSDate *now, NSArray<NSDictionary *> *events, NSInteger lead, NSInteger fallbackHour, NSInteger fallbackMinute) {
    NSDate *tomorrow=[calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[calendar startOfDayForDate:now] options:0];
    NSDate *noon=[calendar dateBySettingHour:12 minute:0 second:0 ofDate:tomorrow options:0];
    NSDictionary *first=nil;
    for(NSDictionary *event in events) {
        NSDate *start=event[@"start"];
        if([event[@"skip"] boolValue] || !start || [start compare:tomorrow]==NSOrderedAscending || [start compare:noon]!=NSOrderedAscending) continue;
        if(!first || [start compare:first[@"start"]]==NSOrderedAscending) first=event;
    }
    NSDate *wake=first?[first[@"start"] dateByAddingTimeInterval:-lead*60]:[calendar dateBySettingHour:fallbackHour minute:fallbackMinute second:0 ofDate:tomorrow options:0];
    return @{@"wake":wake,@"morning":tomorrow,@"event":first?:@{}};
}
static void CheckWakePlanner(void) {
    NSCalendar *c=[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; c.timeZone=[NSTimeZone timeZoneWithName:@"America/Toronto"];
    NSDate *now=[NSDate dateWithTimeIntervalSince1970:1793289600];
    NSDate *day=[c dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[c startOfDayForDate:now] options:0];
    NSDate *(^at)(NSInteger)=^NSDate *(NSInteger h){return [c dateBySettingHour:h minute:0 second:0 ofDate:day options:0];};
    NSDictionary *plan=WakePlan(c,now,@[@{@"start":at(7),@"skip":@YES},@{@"start":at(10)},@{@"start":at(9)},@{@"start":at(12)}],60,8,30);
    NSCAssert([plan[@"wake"] isEqual:at(8)],@"Earliest eligible morning event must determine wake time");
    plan=WakePlan(c,now,@[],60,8,30); NSDateComponents *parts=[c components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:plan[@"wake"]];
    NSCAssert(parts.hour==8 && parts.minute==30,@"No-event fallback must remain exact");
    plan=WakePlan(c,now,@[@{@"start":at(0)}],120,8,30);
    NSCAssert([plan[@"wake"] compare:day]==NSOrderedAscending,@"Early events can require a wake time on the previous evening");
    NSLog(@"DAYBREAK_PLANNER_PASS");
}

@interface DaybreakController : UIViewController <INUIAddVoiceShortcutViewControllerDelegate>
@property(nonatomic) Probe *probe;
@property(nonatomic) EKEventStore *events;
@property(nonatomic) UILabel *planLabel;
@property(nonatomic) UITextField *leadField;
@property(nonatomic) UISwitch *automationSwitch;
@property(nonatomic) NSDictionary *plan;
@property(nonatomic) BOOL sending;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) UIDatePicker *picker;
@property(nonatomic) UITextView *log;
@property(nonatomic) UIButton *scanButton;
@property(nonatomic) UIButton *writeButton;
@property(nonatomic) UIButton *siriButton;
@property(nonatomic) UIButton *restoreButton;
@end

@implementation DaybreakController
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *v=[UILabel new]; v.text=text; v.numberOfLines=0; v.font=[UIFont systemFontOfSize:size weight:weight]; return v;
}
- (UIButton *)button:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    UIButtonConfiguration *config=primary?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;
    config.title=title; config.cornerStyle=UIButtonConfigurationCornerStyleLarge;
    config.baseBackgroundColor=UIColor.systemOrangeColor;
    config.baseForegroundColor=primary?UIColor.blackColor:UIColor.systemOrangeColor;
    config.contentInsets=NSDirectionalEdgeInsetsMake(13,14,13,14);
    UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.title=@"Daybreak";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(share)];
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:scroll];
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=14;
    stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    UIImageView *sun=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sunrise.fill"]];
    sun.contentMode=UIViewContentModeScaleAspectFit; sun.tintColor=UIColor.systemOrangeColor; [sun.heightAnchor constraintEqualToConstant:48].active=YES;
    [stack addArrangedSubview:sun];
    [stack addArrangedSubview:[self label:@"A better morning starts here." size:28 weight:UIFontWeightBold]];
    UILabel *intro=[self label:[NSString stringWithFormat:@"Sleep alarm diagnostic · %@\nPlan tomorrow’s wake time from your calendar and apply it through the on-device Siri runner.", NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"unknown"] size:15 weight:UIFontWeightRegular];
    intro.textColor=UIColor.secondaryLabelColor; [stack addArrangedSubview:intro];
    self.statusLabel=[self label:@"Ready to inspect" size:17 weight:UIFontWeightSemibold];
    self.statusLabel.accessibilityIdentifier=@"probeStatus"; [stack addArrangedSubview:self.statusLabel];
    self.events=[EKEventStore new];
    [stack addArrangedSubview:[self label:@"Tomorrow’s calendar" size:20 weight:UIFontWeightBold]];
    [stack addArrangedSubview:[self button:@"Choose calendars" action:@selector(chooseCalendars) primary:NO]];
    [stack addArrangedSubview:[self label:@"Minutes before your first morning event" size:14 weight:UIFontWeightRegular]];
    self.leadField=[UITextField new]; self.leadField.borderStyle=UITextBorderStyleRoundedRect; self.leadField.keyboardType=UIKeyboardTypeNumberPad;
    self.leadField.text=[NSString stringWithFormat:@"%ld",(long)([NSUserDefaults.standardUserDefaults objectForKey:@"lead"]?[NSUserDefaults.standardUserDefaults integerForKey:@"lead"]:60)];
    [self.leadField addTarget:self action:@selector(savePlanSettings) forControlEvents:UIControlEventEditingDidEnd]; [stack addArrangedSubview:self.leadField];
    [stack addArrangedSubview:[self button:@"Calculate tomorrow’s wake time" action:@selector(previewCalendar) primary:YES]];
    self.planLabel=[self label:@"Uses timed events starting before noon. All-day, cancelled and declined events are ignored. With no morning events, uses the fallback time below." size:14 weight:UIFontWeightRegular]; [stack addArrangedSubview:self.planLabel];
    [stack addArrangedSubview:[self button:@"Apply calendar wake time with Siri" action:@selector(applyCalendar) primary:YES]];
    [stack addArrangedSubview:[self button:@"Save selected time as no-event fallback" action:@selector(saveFallback) primary:NO]];
    [stack addArrangedSubview:[self label:@"Allow daily calendar URL to apply without asking" size:14 weight:UIFontWeightSemibold]];
    self.automationSwitch=[UISwitch new]; self.automationSwitch.on=[NSUserDefaults.standardUserDefaults boolForKey:@"calendarAuto"];
    [self.automationSwitch addTarget:self action:@selector(savePlanSettings) forControlEvents:UIControlEventValueChanged]; [stack addArrangedSubview:self.automationSwitch];
    [stack addArrangedSubview:[self button:@"Daily automation setup" action:@selector(automationHelp) primary:NO]];
    [stack addArrangedSubview:[self label:@"Test wake-up time" size:16 weight:UIFontWeightSemibold]];
    self.picker=[UIDatePicker new]; self.picker.datePickerMode=UIDatePickerModeTime; self.picker.preferredDatePickerStyle=UIDatePickerStyleWheels;
    self.picker.date=[NSCalendar.currentCalendar dateBySettingHour:8 minute:30 second:0 ofDate:NSDate.now options:0];
    [self.picker.heightAnchor constraintEqualToConstant:130].active=YES; [stack addArrangedSubview:self.picker];
    [stack addArrangedSubview:[self button:@"Start on-device Siri runner test" action:@selector(runOnDevice) primary:YES]];
    [stack addArrangedSubview:[self button:@"Enable next Sleep alarm with Siri" action:@selector(enableSleep) primary:NO]];
    [stack addArrangedSubview:[self button:@"Read runner status / report" action:@selector(readRunner) primary:NO]];
    UILabel *runnerHelp=[self label:@"Start Daybreak Runner first. Once its status is ready, choose a time here, tap Start and confirm Apply with Siri. No notification approval is needed for this button. Runner requires development signing and a mounted developer image. Verify the actual Sleep alarm in Clock." size:13 weight:UIFontWeightRegular];
    runnerHelp.textColor=UIColor.secondaryLabelColor; [stack addArrangedSubview:runnerHelp];
    [stack addArrangedSubview:[self button:@"I checked Clock / clear previous request" action:@selector(clearRunner) primary:NO]];
    UILabel *details=[self label:@"After each request, check the exact Sleep | Wake Up time in Clock and clear the request here. If Siri asks which alarm, dismiss it and verify Clock; Daybreak never chooses a regular alarm for you. Bedtime is not changed. Daily execution while locked is not verified." size:13 weight:UIFontWeightRegular];
    details.textColor=UIColor.secondaryLabelColor; [stack addArrangedSubview:details];
    [stack addArrangedSubview:[self label:@"Diagnostic report" size:18 weight:UIFontWeightBold]];
    self.log=[UITextView new]; self.log.editable=NO; self.log.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.log.backgroundColor=UIColor.secondarySystemBackgroundColor; self.log.layer.cornerRadius=14;
    self.log.textContainerInset=UIEdgeInsetsMake(12,8,12,8); [self.log.heightAnchor constraintEqualToConstant:290].active=YES;
    [stack addArrangedSubview:self.log];
    self.probe=[Probe new]; __weak typeof(self) weak=self;
    self.probe.changed=^{[weak refresh];}; [self refresh];
    [self.probe note:@"App ready. No alarm changes occur on launch."];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"]){ CheckWakePlanner(); [self.probe note:@"DAYBREAK_PLANNER_PASS"]; [self scan]; }
}
- (void)refresh {
    self.statusLabel.text=self.probe.status; self.log.text=self.probe.report;
    self.scanButton.enabled=!self.probe.busy;
    self.siriButton.enabled=!self.probe.busy;
    self.writeButton.enabled=!self.probe.busy && self.probe.hasOverride;
    self.restoreButton.enabled=!self.probe.busy && self.probe.canRestore;
    self.picker.enabled=!self.probe.busy;
    if(self.log.text.length) [self.log scrollRangeToVisible:NSMakeRange(self.log.text.length-1,1)];
}
- (void)savePlanSettings {
    NSInteger lead=MAX(0,MIN(720,self.leadField.text.integerValue)); self.leadField.text=[NSString stringWithFormat:@"%ld",(long)lead];
    [NSUserDefaults.standardUserDefaults setInteger:lead forKey:@"lead"];
    [NSUserDefaults.standardUserDefaults setBool:self.automationSwitch.on forKey:@"calendarAuto"];
}
- (void)saveFallback {
    NSDateComponents *t=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:self.picker.date];
    [NSUserDefaults.standardUserDefaults setInteger:t.hour forKey:@"fallbackHour"]; [NSUserDefaults.standardUserDefaults setInteger:t.minute forKey:@"fallbackMinute"];
    [self.probe note:@"Saved the selected time as the no-event fallback."];
}
- (void)withCalendar:(void (^)(void))work {
    if([EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent]==EKAuthorizationStatusFullAccess){work();return;}
    [self.events requestFullAccessToEventsWithCompletion:^(BOOL granted,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(granted)work();else [self.probe note:@"Calendar reading denied. Allow full Calendar access in Settings to calculate wake times."];});}];
}
- (void)chooseCalendars {
    [self withCalendar:^{
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Choose one calendar or all" message:@"Only the chosen calendar will affect your wake time." preferredStyle:UIAlertControllerStyleActionSheet];
        [a addAction:[UIAlertAction actionWithTitle:@"All calendars" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[NSUserDefaults.standardUserDefaults removeObjectForKey:@"calendarID"];}]];
        for(EKCalendar *c in [self.events calendarsForEntityType:EKEntityTypeEvent]) [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)",c.title,c.source.title] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[NSUserDefaults.standardUserDefaults setObject:c.calendarIdentifier forKey:@"calendarID"];}]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        a.popoverPresentationController.sourceView=self.view; a.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,150,1,1); [self presentViewController:a animated:YES completion:nil];
    }];
}
- (BOOL)calculatePlan {
    [self savePlanSettings]; [self.view endEditing:YES];
    NSCalendar *c=NSCalendar.currentCalendar; NSDate *now=NSDate.now;
    NSDate *day=[c dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[c startOfDayForDate:now] options:0];
    NSDate *noon=[c dateBySettingHour:12 minute:0 second:0 ofDate:day options:0];
    NSString *cid=[NSUserDefaults.standardUserDefaults stringForKey:@"calendarID"]; EKCalendar *chosen=cid?[self.events calendarWithIdentifier:cid]:nil;
    if(cid && !chosen){[self.probe note:@"Selected calendar is unavailable. Choose a calendar again; no alarm request sent."];return NO;}
    NSArray *found=[self.events eventsMatchingPredicate:[self.events predicateForEventsWithStartDate:day endDate:noon calendars:chosen?@[chosen]:nil]];
    NSMutableArray *items=[NSMutableArray new];
    for(EKEvent *e in found){ BOOL skip=e.allDay || e.status==EKEventStatusCanceled;
        for(EKParticipant *p in e.attendees) if(p.isCurrentUser && p.participantStatus==EKParticipantStatusDeclined) skip=YES;
        if(e.startDate) [items addObject:@{@"start":e.startDate,@"skip":@(skip),@"title":e.title?:@"Untitled event"}];
    }
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    self.plan=WakePlan(c,now,items,[d integerForKey:@"lead"],[d objectForKey:@"fallbackHour"]?[d integerForKey:@"fallbackHour"]:8,[d objectForKey:@"fallbackMinute"]?[d integerForKey:@"fallbackMinute"]:30);
    NSDateFormatter *f=[NSDateFormatter new]; f.dateStyle=NSDateFormatterMediumStyle; f.timeStyle=NSDateFormatterShortStyle;
    NSDictionary *event=self.plan[@"event"];
    self.planLabel.text=[NSString stringWithFormat:@"Wake: %@\n%@",[f stringFromDate:self.plan[@"wake"]],[event count]?[NSString stringWithFormat:@"%@ at %@, minus %@ minutes.",event[@"title"],[f stringFromDate:event[@"start"]],self.leadField.text]:@"No eligible morning events. Using your fallback."];
    return YES;
}
- (void)previewCalendar {[self withCalendar:^{[self calculatePlan];}];}
- (void)applyCalendar {[self withCalendar:^{if([self calculatePlan]){
    NSDate *cutoff=[NSCalendar.currentCalendar dateBySettingHour:12 minute:0 second:0 ofDate:NSDate.now options:0];
    if([NSDate.now compare:cutoff]==NSOrderedAscending){[self.probe note:@"Tomorrow’s plan is ready. Apply it after noon so Siri’s next Sleep alarm targets tomorrow. Manual time testing remains available below."];return;}
    if([self.plan[@"wake"] compare:self.plan[@"morning"]]==NSOrderedAscending){[self.probe note:@"This plan crosses into the previous date. Review the full date and use manual time testing if intended. No calendar request sent."];return;}
    self.picker.date=self.plan[@"wake"];[self runOnDevice];
}}];}
- (void)runCalendarURL {
    [self withCalendar:^{if(![self calculatePlan])return;
        if(!self.automationSwitch.on){[self.probe note:@"Calendar URL preview only. Enable daily URL application to send automatically."];return;}
        NSDate *wake=self.plan[@"wake"]; NSDate *morning=self.plan[@"morning"];
        if([wake compare:morning]==NSOrderedAscending){[self.probe note:@"Wake time crosses into the previous date. Review and apply this plan manually; automatic request skipped."];return;}
        if([wake compare:NSDate.now]!=NSOrderedDescending){[self.probe note:@"Calculated wake time is already past. No request sent."];return;}
        // Siri's 'next' Sleep alarm must refer to the target morning. Avoid applying tomorrow's plan before today's wake alarm.
        NSDate *todayCutoff=[NSCalendar.currentCalendar dateBySettingHour:12 minute:0 second:0 ofDate:NSDate.now options:0];
        if([NSDate.now compare:todayCutoff]==NSOrderedAscending){[self.probe note:@"Run the daily calendar URL after noon so the next Sleep alarm targets tomorrow."];return;}
        NSString *key=[NSString stringWithFormat:@"calendarRun-%@",morning];
        if([NSUserDefaults.standardUserDefaults boolForKey:key]){[self.probe note:@"Already attempted the daily calendar request for this morning. Use manual Apply to retry after checking Clock."];return;}
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:key];
        NSDateComponents *t=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:wake]; [self sendRunnerHour:t.hour minute:t.minute operation:@"set"];
    }];
}
- (void)automationHelp {
    UIPasteboard.generalPasteboard.string=@"daybreak://calendar-run";
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Daily calendar automation" message:@"URL copied: daybreak://calendar-run\n\nIn Shortcuts: Automation → Time of Day → choose an evening time → Run Immediately → add Open URLs with that URL. Enable daily URL application here first.\n\nRunner must already be active. Opening Daybreak or using Siri may require unlocking; locked-screen execution is unverified. The automation makes at most one attempt per target morning. A missed run is not retried automatically. Bedtime is unchanged." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
- (void)clearRunner {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Check Clock first" message:@"Dismiss Siri, open Clock and inspect Sleep | Wake Up. Clear only when you are ready to allow another request. This does not undo an alarm change." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Checked Clock, allow another request" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        NSURLSession *session=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
        [[session dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:8275/status"] completionHandler:^(NSData *data,NSURLResponse *r,NSError *e){
            NSDictionary *info=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
            NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8275/reset"]]; req.HTTPMethod=@"POST";
            [req setValue:info[@"session"]?:@"" forHTTPHeaderField:@"X-Daybreak-Session"];
            [[session dataTaskWithRequest:req completionHandler:^(NSData *d,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{[self.probe note:(!error && [(NSHTTPURLResponse *)response statusCode]==200)?@"Previous request cleared. Runner can accept another test.":@"Could not clear request. If Siri is still active, dismiss it first, then retry."];[self readRunner];});[session finishTasksAndInvalidate];}] resume];
        }] resume];
    }]];[self presentViewController:a animated:YES completion:nil];
}
- (void)scan { [self.probe scan]; }
- (void)enableSleep {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Enable next Sleep alarm?" message:@"Ask Siri to turn on your next Sleep alarm. This command still needs phone verification. Check the Sleep | Wake Up entry afterward." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Enable with Siri" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self sendRunnerHour:0 minute:0 operation:@"enable"];}]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)runOnDevice {
    NSDateComponents *time=[NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:self.picker.date];
    NSString *message=[NSString stringWithFormat:@"Ask Siri to change your next Sleep alarm to %ld:%02ld %@? Check Clock afterward to verify the result.",(long)(time.hour%12?:12),(long)time.minute,time.hour<12?@"AM":@"PM"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Test next Sleep alarm" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Apply with Siri" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self sendRunnerHour:time.hour minute:time.minute operation:@"set"];}]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)sendRunnerHour:(NSInteger)hour minute:(NSInteger)minute operation:(NSString *)operation {
    if(self.sending){[self.probe note:@"A runner handoff is already in progress."]; return;} self.sending=YES;
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration; config.timeoutIntervalForRequest=5;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config];
    self.statusLabel.text=@"Connecting to runner…";
    [[session dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:8275/status"] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSDictionary *info=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSString *token=[info isKindOfClass:NSDictionary.class]?info[@"session"]:nil;
        if(!token.length){
            dispatch_async(dispatch_get_main_queue(),^{self.sending=NO;});
            dispatch_async(dispatch_get_main_queue(),^{
                [self.probe note:@"Runner not reachable or needs updating. Opening Runner. Once it starts, return here and tap Start again. Install both apps from the same release."];
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"daybreak-runner://start"] options:@{} completionHandler:nil];
            }); [session finishTasksAndInvalidate]; return;
        }
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8275/sleep-test"]];
        request.HTTPMethod=@"POST"; [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; [request setValue:token forHTTPHeaderField:@"X-Daybreak-Session"];
        request.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"hour":@(hour),@"minute":@(minute),@"request":NSUUID.UUID.UUIDString,@"operation":operation} options:0 error:nil];
        [[session dataTaskWithRequest:request completionHandler:^(NSData *reply,NSURLResponse *r,NSError *failure){
            dispatch_async(dispatch_get_main_queue(),^{
                self.sending=NO;
                BOOL ok=!failure && [(NSHTTPURLResponse *)r statusCode]==200;
                [self.probe note:ok?@"Runner accepted the confirmed test. Siri should open shortly. Alarm change is not yet verified.":[NSString stringWithFormat:@"Runner handoff failed: %@",failure.localizedDescription?:([[NSString alloc] initWithData:reply encoding:NSUTF8StringEncoding]?:@"request rejected")]];
                self.statusLabel.text=ok?@"Runner: test queued":@"Runner: handoff failed";
                if(ok) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self readRunner];});
            }); [session finishTasksAndInvalidate];
        }] resume];
    }] resume];
}
- (void)readRunner {
    NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest=5;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:8275/status"] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            if(error || !data){[self.probe note:[NSString stringWithFormat:@"Runner status unavailable: %@. If the runner exited immediately, check development signing, nested test signature, mounted developer image, and UI Automation approval.",error.localizedDescription?:@"no data"]];}
            else {
                NSDictionary *result=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if([result isKindOfClass:NSDictionary.class]) {
                    [self.probe note:[NSString stringWithFormat:@"On-device runner report:\n%@",result]];
                    self.statusLabel.text=[NSString stringWithFormat:@"Runner: %@",result[@"phase"]?:@"unknown"];
                } else [self.probe note:@"Runner returned an unexpected status response."];
            }
            [session finishTasksAndInvalidate];
        });
    }] resume];
}
- (void)siri {
    INShortcut *shortcut=[self.probe shortcutForDate:self.picker.date];
    if(!shortcut) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Siri route unavailable" message:@"The diagnostic report explains the missing class, operation, permission, or alarm target. No alarm was changed." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; return;
    }
    @try {
        INUIAddVoiceShortcutViewController *controller=[[INUIAddVoiceShortcutViewController alloc] initWithShortcut:shortcut];
        controller.delegate=self; [self presentViewController:controller animated:YES completion:nil];
    } @catch(NSException *e){[self.probe note:[NSString stringWithFormat:@"Siri shortcut presentation failed: %@",e.reason]];}
}
- (void)confirmWrite {
    NSDateFormatter *f=[NSDateFormatter new]; f.timeStyle=NSDateFormatterShortStyle;
    NSString *message=[NSString stringWithFormat:@"Attempt to set the existing next-only Sleep override to %@ and enable it? A restore snapshot will be saved first. Its current alarm date is preserved. Confirm the result in Clock.",[f stringFromDate:self.picker.date]];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Test next Sleep alarm" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Apply test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self.probe changeOverrideTo:self.picker.date];}]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)confirmRestore {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Restore original override?" message:@"Restore the saved alarm only if it still matches the current future next-only override." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self.probe restore];}]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)openClock {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"clock-alarm://"] options:@{} completionHandler:^(BOOL success){
        [self.probe note:success?@"Clock URL opened. Verify Sleep | Wake Up manually.":@"Clock deep link unavailable. Open Clock manually."];
    }];
}
- (void)share {
    UIActivityViewController *activity=[[UIActivityViewController alloc] initWithActivityItems:@[self.probe.report] applicationActivities:nil];
    activity.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItem;
    [self presentViewController:activity animated:YES completion:nil];
}
- (void)addVoiceShortcutViewController:(INUIAddVoiceShortcutViewController *)controller didFinishWithVoiceShortcut:(INVoiceShortcut *)voiceShortcut error:(NSError *)error {
    [self.probe note:error?[NSString stringWithFormat:@"Save Siri shortcut failed: %@ %@",error,error.userInfo]:voiceShortcut?@"Voice shortcut saved. It has NOT been executed by Daybreak. Run it yourself and check the exact Sleep entry in Clock.":@"No saved voice shortcut returned."];
    [controller dismissViewControllerAnimated:YES completion:nil];
}
- (void)addVoiceShortcutViewControllerDidCancel:(INUIAddVoiceShortcutViewController *)controller {
    [self.probe note:@"Siri shortcut setup cancelled; no execution claimed."]; [controller dismissViewControllerAnimated:YES completion:nil];
}
@end

@interface DaybreakApp : UIResponder <UIApplicationDelegate>
@property(nonatomic) UIWindow *window;
@end
@implementation DaybreakApp
- (BOOL)handleURL:(NSURL *)url {
    if(![url.scheme isEqualToString:@"daybreak"] || ![url.host isEqualToString:@"calendar-run"])return NO;
    UINavigationController *nav=(id)self.window.rootViewController; DaybreakController *controller=(id)nav.topViewController;
    [controller loadViewIfNeeded]; [controller runCalendarURL]; return YES;
}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary *)options {return [self handleURL:url];}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[DaybreakController new]];
    self.window.tintColor=UIColor.systemOrangeColor; [self.window makeKeyAndVisible];
    NSURL *url=options[UIApplicationLaunchOptionsURLKey]; if(url) dispatch_async(dispatch_get_main_queue(),^{[self handleURL:url];}); return YES;
}
@end
int main(int argc,char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(DaybreakApp.class)); }
}
