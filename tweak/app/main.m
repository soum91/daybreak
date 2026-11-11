#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <notify.h>
#import "../DBPlanner.h"
#import "../DBDiagnosticExport.h"

static NSString *const DBAppPrefs=@"com.soum91.daybreak.tweak";
static UIColor *DBBackground(void){return [UIColor colorWithRed:.055 green:.075 blue:.13 alpha:1];}
static UIColor *DBCard(void){return [UIColor colorWithRed:.10 green:.15 blue:.25 alpha:1];}
static UIColor *DBOrange(void){return [UIColor colorWithRed:1 green:.64 blue:.23 alpha:1];}
static id DBValue(NSString *key){return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)DBAppPrefs));}
static void DBWrite(NSString *key,id value){CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)DBAppPrefs);CFPreferencesAppSynchronize((__bridge CFStringRef)DBAppPrefs);}
static NSInteger DBInt(NSString *key,NSInteger fallback,NSInteger min,NSInteger max){id obj=DBValue(key);return [obj respondsToSelector:@selector(integerValue)]?MAX(min,MIN(max,[obj integerValue])):fallback;}

@interface DBHomeController : UIViewController <UITextFieldDelegate>
@property(nonatomic) UIScrollView *scroll;
@property(nonatomic) UIStackView *stack;
@property(nonatomic) UILabel *preview;
@property(nonatomic) UILabel *status;
@property(nonatomic) UITextView *details;
@property(nonatomic) UITextField *leadField;
@property(nonatomic) UITextField *fallbackHourField;
@property(nonatomic) UITextField *fallbackMinuteField;
@property(nonatomic) UITextField *hourlyStartField;
@property(nonatomic) UITextField *hourlyEndField;
@property(nonatomic) UISwitch *autoSwitch;
@property(nonatomic) UISwitch *notificationsSwitch;
@property(nonatomic) UISwitch *cloudOverrideSwitch;
@property(nonatomic) UISwitch *enableSwitch;
@property(nonatomic) EKEventStore *events;
@property(nonatomic) BOOL busy;
@end

@implementation DBHomeController
- (UILabel *)label:(NSString *)value size:(CGFloat)size bold:(BOOL)bold {
    UILabel *label=[UILabel new]; label.text=value; label.numberOfLines=0;
    label.textColor=UIColor.whiteColor;
    label.font=bold?[UIFont boldSystemFontOfSize:size]:[UIFont systemFontOfSize:size];
    return label;
}
- (UIView *)card:(NSArray<UIView *> *)children {
    UIView *container=[UIView new];container.backgroundColor=DBCard();container.layer.cornerRadius=18;
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:children];
    stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:18],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-18],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18]
    ]];return container;
}
- (UIButton *)button:(NSString *)title action:(SEL)selector emphasized:(BOOL)emphasized {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor=emphasized?DBOrange():[UIColor colorWithWhite:1 alpha:.12];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:emphasized?DBBackground():UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont boldSystemFontOfSize:16];
    button.layer.cornerRadius=12;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];return button;
}
- (UITextField *)field:(NSString *)key fallback:(NSInteger)fallback {
    UITextField *field=[UITextField new];field.text=[NSString stringWithFormat:@"%ld",(long)DBInt(key,fallback,0,720)];
    field.keyboardType=UIKeyboardTypeNumberPad;field.textColor=UIColor.whiteColor;
    field.backgroundColor=[UIColor colorWithWhite:1 alpha:.10];field.layer.cornerRadius=9;
    field.font=[UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightMedium];
    field.textAlignment=NSTextAlignmentCenter;field.delegate=self;
    [field.widthAnchor constraintEqualToConstant:84].active=YES;
    [field.heightAnchor constraintEqualToConstant:41].active=YES;
    [field addTarget:self action:@selector(saveFields) forControlEvents:UIControlEventEditingDidEnd];
    return field;
}
- (UIView *)fieldRow:(NSString *)name field:(UITextField *)field {
    UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[[self label:name size:15 bold:NO],field]];
    row.axis=UILayoutConstraintAxisHorizontal;row.alignment=UIStackViewAlignmentCenter;row.spacing=8;
    return row;
}
- (UIView *)switchRow:(NSString *)name control:(UISwitch *)toggle {
    toggle.onTintColor=DBOrange();[toggle addTarget:self action:@selector(saveSwitches) forControlEvents:UIControlEventValueChanged];
    UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[[self label:name size:15 bold:NO],toggle]];
    row.axis=UILayoutConstraintAxisHorizontal;row.alignment=UIStackViewAlignmentCenter;
    row.distribution=UIStackViewDistributionEqualSpacing;
    return row;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=DBBackground();
    self.events=[EKEventStore new];
    self.scroll=[UIScrollView new];self.scroll.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:self.scroll];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    self.stack=[UIStackView new];self.stack.axis=UILayoutConstraintAxisVertical;self.stack.spacing=18;
    self.stack.translatesAutoresizingMaskIntoConstraints=NO;[self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:24],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:20],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-20]
    ]];
    UILabel *name=[self label:@"☀ Daybreak" size:33 bold:YES];name.textColor=DBOrange();[self.stack addArrangedSubview:name];
    NSString *version=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"unknown";
    NSString *build=NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"unknown";
    UILabel *intro=[self label:[NSString stringWithFormat:@"Installed %@ (%@) · iOS 16 Dopamine\nTomorrow's calendar. Your next Sleep alarm.",version,build] size:14 bold:NO];
    intro.textColor=[UIColor colorWithWhite:1 alpha:.72];[self.stack addArrangedSubview:intro];
    self.preview=[self label:@"Tap Preview to calculate tomorrow's wake time." size:17 bold:NO];
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Tomorrow's wake" size:21 bold:YES],self.preview,
        [self button:@"Preview tomorrow" action:@selector(previewTapped) emphasized:YES],
        [self button:@"Apply once to native Sleep" action:@selector(applyTapped) emphasized:NO],
        [self label:@"Automatic updates are enabled below. The separate Apply button is optional for a one-time update. If the background Sleep service rejects an automatic write, opening Apple Health can process the pending request. The Watch must still be checked separately." size:13 bold:NO]
    ]]];
    self.leadField=[self field:@"leadMinutes" fallback:60];
    self.fallbackHourField=[self field:@"fallbackHour" fallback:8];
    self.fallbackMinuteField=[self field:@"fallbackMinute" fallback:30];
    self.hourlyStartField=[self field:@"hourlyStartHour" fallback:12];
    self.hourlyEndField=[self field:@"hourlyEndHour" fallback:23];
    self.autoSwitch=[UISwitch new];
    id storedAuto=DBValue(@"automaticEnabled");
    self.autoSwitch.on=[storedAuto respondsToSelector:@selector(boolValue)]?[storedAuto boolValue]:YES;
    self.autoSwitch.enabled=YES;
    self.notificationsSwitch=[UISwitch new];
    id notifications=DBValue(@"notificationsEnabled");
    self.notificationsSwitch.on=[notifications respondsToSelector:@selector(boolValue)]?[notifications boolValue]:YES;
    self.cloudOverrideSwitch=[UISwitch new];
    self.cloudOverrideSwitch.on=[DBValue(@"experimentalSleepCloudSync") boolValue];
    self.enableSwitch=[UISwitch new];self.enableSwitch.on=[DBValue(@"enableNextSleepAlarm") boolValue];
    self.enableSwitch.enabled=NO;
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Wake planner settings" size:21 bold:YES],
        [self fieldRow:@"Preparation minutes (0–720)" field:self.leadField],
        [self fieldRow:@"Fallback hour (0–23)" field:self.fallbackHourField],
        [self fieldRow:@"Fallback minute (0–59)" field:self.fallbackMinuteField],
        [self fieldRow:@"Hourly checks start (12–23)" field:self.hourlyStartField],
        [self fieldRow:@"Hourly checks end (12–23)" field:self.hourlyEndField],
        [self button:@"Choose calendar" action:@selector(chooseCalendar) emphasized:NO],
        [self switchRow:@"Automatic native Sleep schedule" control:self.autoSwitch],
        [self switchRow:@"Notifications for updates and errors" control:self.notificationsSwitch],
        [self button:@"Run automation now" action:@selector(runAutomationNow) emphasized:NO],
        [self label:@"Daybreak rechecks tomorrow's calendar once every hour between the selected hours, including changes to existing appointments. Only native one-day Sleep overrides are requested, never ordinary alarms. A successful local Sleep change is not proof of iPhone 17 sync." size:13 bold:NO]
    ]]];
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Experimental Sleep cloud sync" size:21 bold:YES],
        [self switchRow:@"Override sleepd cloud feature" control:self.cloudOverrideSwitch],
        [self label:@"OFF by default. Enabling overrides Apple's private sleepCloudKitSync flag only inside the iPhone 13's Sleep daemon. It can change how Sleep schedules synchronize and may cause conflicts. Turn the switch ON or OFF, then use Dopamine → Reboot Userspace once. Reversing the switch and rebooting userspace restores Apple's behavior. No guarantee of iPhone 17 or Apple Watch delivery; keep a backup alarm." size:13 bold:NO]
    ]]];
    self.status=[self label:@"No diagnostic yet." size:13 bold:NO];
    self.status.textColor=[UIColor colorWithWhite:1 alpha:.78];
    self.details=[UITextView new];self.details.editable=NO;self.details.selectable=YES;
    self.details.textColor=UIColor.whiteColor;self.details.backgroundColor=[UIColor colorWithWhite:0 alpha:.18];
    self.details.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.details.layer.cornerRadius=10;
    [self.details.heightAnchor constraintEqualToConstant:180].active=YES;
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Tweak status" size:21 bold:YES],self.status,
        [self button:@"Refresh status" action:@selector(refreshStatus) emphasized:NO],
        [self button:@"Copy diagnostic" action:@selector(copyReport) emphasized:NO],
        [self button:@"Share diagnostic" action:@selector(shareReport) emphasized:NO],
        [self button:@"Save diagnostic to Files" action:@selector(saveReport) emphasized:NO],
        [self label:@"Full selectable report" size:15 bold:YES],self.details
    ]]];
    UILabel *note=[self label:@"Local notifications from the SpringBoard tweak are experimental and can be blocked by iOS permissions. The iPhone 13's native Sleep change has been observed, but automatic execution and synchronization to a second iPhone and its Watch remain unverified. Keep a backup alarm." size:13 bold:NO];
    note.textColor=[UIColor colorWithWhite:1 alpha:.65];[self.stack addArrangedSubview:note];
    [self refreshStatus];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[textField resignFirstResponder];[self saveFields];return YES;}
- (void)saveFields {
    DBWrite(@"leadMinutes",@(MAX(0,MIN(720,self.leadField.text.integerValue))));
    DBWrite(@"fallbackHour",@(MAX(0,MIN(23,self.fallbackHourField.text.integerValue))));
    DBWrite(@"fallbackMinute",@(MAX(0,MIN(59,self.fallbackMinuteField.text.integerValue))));
    NSInteger start=MAX(12,MIN(23,self.hourlyStartField.text.integerValue));
    NSInteger end=MAX(start,MIN(23,self.hourlyEndField.text.integerValue));
    DBWrite(@"hourlyStartHour",@(start));
    DBWrite(@"hourlyEndHour",@(end));
    notify_post("com.soum91.daybreak.preferences");
}
- (void)saveSwitches {
    BOOL previousCloud=[DBValue(@"experimentalSleepCloudSync") boolValue];
    DBWrite(@"automaticEnabled",@(self.autoSwitch.isOn));
    DBWrite(@"notificationsEnabled",@(self.notificationsSwitch.isOn));
    DBWrite(@"experimentalSleepCloudSync",@(self.cloudOverrideSwitch.isOn));
    if(self.notificationsSwitch.isOn) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert|UNAuthorizationOptionSound) completionHandler:^(BOOL granted,NSError *error){
            NSLog(@"[Daybreak] Companion notification authorization: %@ %@",granted?@"granted":@"denied",error?:@"");
        }];
    }
    notify_post("com.soum91.daybreak.preferences");
    if(previousCloud!=self.cloudOverrideSwitch.isOn) {
        [self alert:@"Cloud experiment saved" message:self.cloudOverrideSwitch.isOn?
            @"EXPERIMENT ENABLED for the next sleepd startup. Use Dopamine → Reboot Userspace to apply. This can affect iCloud Sleep scheduling; keep a backup alarm and inspect iPhone 17 separately.":
            @"EXPERIMENT DISABLED for the next sleepd startup. Use Dopamine → Reboot Userspace to restore Apple's original feature behavior."];
        [self refreshStatus];
    }
}
- (void)runAutomationNow {
    [self saveFields];
    notify_post("com.soum91.daybreak.forceautomation");
    [self alert:@"Automatic update requested" message:@"SpringBoard will calculate tomorrow's wake and submit it through the native Sleep writer. Refresh status after a few seconds. If the native framework cannot write in background, the pending request may be processed when Apple Health opens."];
}
- (void)alert:(NSString *)title message:(NSString *)message {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)chooseCalendar {
    [self withCalendarAccess:^{
        UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Choose calendar" message:@"All calendars, or one selected calendar" preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:@"All calendars" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;DBWrite(@"calendarID",nil);}]];
        for(EKCalendar *calendar in [self.events calendarsForEntityType:EKEntityTypeEvent]) {
            NSString *identifier=[calendar.calendarIdentifier copy];
            [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ · %@",calendar.title,calendar.source.title] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;DBWrite(@"calendarID",identifier);}]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
    }];
}
- (void)withCalendarAccess:(dispatch_block_t)completion {
    EKAuthorizationStatus access=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if(access==EKAuthorizationStatusAuthorized) {completion();return;}
    if(access==EKAuthorizationStatusNotDetermined) {
        [self.events requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted,NSError *error){
            dispatch_async(dispatch_get_main_queue(),^{
                if(granted) completion(); else [self alert:@"Calendar unavailable" message:error.localizedDescription?:@"Allow Calendar access for the Daybreak app in iOS Settings."];
            });
        }];return;
    }
    [self alert:@"Calendar permission denied" message:@"Allow Daybreak to read calendars in iOS Settings. No alarm was changed."];
}
- (void)calculate:(BOOL)apply {
    [self saveFields];
    if(self.busy) return;
    if(apply && [NSCalendar.currentCalendar component:NSCalendarUnitHour fromDate:NSDate.date]<12) {
        [self alert:@"Too early" message:@"Apply tomorrow's Sleep alarm after noon."];return;
    }
    [self withCalendarAccess:^{
        self.busy=YES;
        NSCalendar *cal=NSCalendar.currentCalendar;NSDate *now=NSDate.date;
        NSDate *morning=[cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[cal startOfDayForDate:now] options:0];
        NSDate *noon=[cal dateBySettingHour:12 minute:0 second:0 ofDate:morning options:0];
        NSString *identifier=DBValue(@"calendarID");
        EKCalendar *selected=identifier.length?[self.events calendarWithIdentifier:identifier]:nil;
        if(identifier.length && !selected) {
            self.busy=NO;[self alert:@"Calendar missing" message:@"Select another calendar. No alarm was changed."];return;
        }
        NSArray *events=[self.events eventsMatchingPredicate:[self.events predicateForEventsWithStartDate:morning endDate:noon calendars:selected?@[selected]:nil]];
        NSMutableArray<NSDate *> *starts=[NSMutableArray new];
        for(EKEvent *event in events) {
            if(event.isAllDay || event.status==EKEventStatusCanceled || !event.startDate)continue;
            BOOL declined=NO;
            for(EKParticipant *person in event.attendees) if(person.isCurrentUser && person.participantStatus==EKParticipantStatusDeclined)declined=YES;
            if(!declined)[starts addObject:event.startDate];
        }
        NSDictionary *plan=DBWakePlan(cal,now,starts,DBInt(@"leadMinutes",60,0,720),DBInt(@"fallbackHour",8,0,23),DBInt(@"fallbackMinute",30,0,59));
        NSDate *wake=plan[@"wake"];
        NSDateFormatter *fmt=[NSDateFormatter new];fmt.dateStyle=NSDateFormatterMediumStyle;fmt.timeStyle=NSDateFormatterShortStyle;
        BOOL valid=DBIsSameDay(cal,wake,morning) && [wake timeIntervalSinceDate:NSDate.date]>60;
        self.preview.text=[NSString stringWithFormat:@"%@\n%@ (%lu eligible events)",[fmt stringFromDate:wake],
                           [plan[@"usedEvent"] boolValue]?@"Earliest morning event minus preparation":@"No event: fallback time",(unsigned long)starts.count];
        self.busy=NO;
        if(!apply) return;
        if(!valid){[self alert:@"Wake time invalid" message:@"The calculated time crossed into today or has already passed. No update sent."];return;}
        // Only Apple's Health app receives this short-lived one-shot request.
        // SpringBoard's historical device-local MobileTimer writer stays off.
        DBWrite(@"nativeSleepRequest",@{@"wake":wake,@"morning":morning,
             @"created":NSDate.date,@"identifier":NSUUID.UUID.UUIDString});
        notify_post("com.soum91.daybreak.nativeapply");
        [self alert:@"Native Sleep request prepared" message:@"Open Apple Health on this iPhone 13 now, wait about ten seconds, then return to Daybreak and Refresh status. Check the result before trusting the Watch alarm. The request expires in ten minutes."];
    }];
}
- (void)previewTapped {[self calculate:NO];}
- (void)applyTapped {
    [self calculate:YES];
}
- (void)refreshStatus {
    NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.status.plist"]?:@{};
    self.status.text=[NSString stringWithFormat:@"%@\n%@\nUpdated: %@\nHealth schedule probe: %@ (%@)\nSleep cloud feature (Health process): %@\nOne-night override in cloud sync key set: %@\nHealth cloud probe: %@\nCloud override configured: %@ (applies after userspace reboot)\nSleep daemon observed: %@\nSystem cloud feature (daemon): %@\nCloud override loaded in daemon: %@\nEffective cloud feature (daemon): %@\nSleep daemon cloud preference: %@\nInitial cloud sync: %@\nCloud pull required: %@\nDaemon probe: %@",state[@"code"]?:@"Not started",state[@"message"]?:@"No engine report yet",state[@"updated"]?:@"never",state[@"healthProbe"]?:@"not run: open Apple Health first",state[@"healthProbeUpdated"]?:@"never",state[@"sleepCloudFeature"]?:@"not checked",state[@"sleepOverrideSyncKey"]?:@"not checked",state[@"sleepCloudChecked"]?:@"never",[DBValue(@"experimentalSleepCloudSync") boolValue]?@"on":@"off",[state[@"sleepDaemonSeen"] boolValue]?@"yes":@"not observed (await sleepd start)",state[@"sleepDaemonOriginalFeature"]?:@"not observed",state[@"sleepDaemonOverride"]?:@"not observed",state[@"sleepDaemonFeature"]?:@"not observed",state[@"sleepDaemonCloud"]?:@"not observed",state[@"sleepDaemonInitial"]?:@"not observed",state[@"sleepDaemonPull"]?:@"not observed",state[@"sleepDaemonChecked"]?:@"never"];
    self.details.text=[self report];
}
- (NSString *)report {
    NSString *log=[NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log" encoding:NSUTF8StringEncoding error:nil]?:@"No SpringBoard log accessible.";
    NSString *version=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"unknown";
    NSString *build=NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"unknown";
    return [NSString stringWithFormat:@"Daybreak tweak %@ (%@) · iOS %@\n\n%@\n\n%@",version,build,UIDevice.currentDevice.systemVersion,self.status.text?:@"",log];
}
- (void)copyReport {
    NSString *failure=nil;
    BOOL copied=DBDiagnosticCopyToClipboard([self report],&failure);
    [self alert:copied?@"Copied and verified":@"Copy failed"
         message:copied?@"Full report read back from clipboard. You can paste it into another app.":failure?:@"Use Share or Save to Files instead."];
}
- (void)shareReport {
    UIActivityViewController *activity=[[UIActivityViewController alloc] initWithActivityItems:@[[self report]] applicationActivities:nil];
    [self presentViewController:activity animated:YES completion:nil];
}
- (void)saveReport {
    NSError *error=nil;
    NSURL *url=DBDiagnosticWriteExport([self report],&error);
    if(!url) {
        [self alert:@"Export failed" message:error.localizedDescription?:@"Cannot write diagnostic file."];return;
    }
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
    [self presentViewController:picker animated:YES completion:nil];
}
@end

@interface DBAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation DBAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application;(void)options;
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[DBHomeController new];
    [self.window makeKeyAndVisible];
    if(![DBValue(@"notificationsEnabled") respondsToSelector:@selector(boolValue)] || [DBValue(@"notificationsEnabled") boolValue]) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings){
            if(settings.authorizationStatus==UNAuthorizationStatusNotDetermined)
                [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert|UNAuthorizationOptionSound) completionHandler:^(BOOL granted,NSError *error){
                    NSLog(@"[Daybreak] Notification authorization: %@ %@",granted?@"granted":@"denied",error?:@"");
                }];
        }];
    }
    return YES;
}
@end

int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(DBAppDelegate.class));}}
