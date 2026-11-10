#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import "../DBPlanner.h"

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
@property(nonatomic) UITextField *leadField;
@property(nonatomic) UITextField *fallbackHourField;
@property(nonatomic) UITextField *fallbackMinuteField;
@property(nonatomic) UITextField *runHourField;
@property(nonatomic) UISwitch *autoSwitch;
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
        [self button:@"Preview tomorrow" action:@selector(previewTapped) emphasized:NO],
        [self button:@"Apply to Sleep | Wake Up" action:@selector(applyTapped) emphasized:YES]
    ]]];
    self.leadField=[self field:@"leadMinutes" fallback:60];
    self.fallbackHourField=[self field:@"fallbackHour" fallback:8];
    self.fallbackMinuteField=[self field:@"fallbackMinute" fallback:30];
    self.runHourField=[self field:@"runHour" fallback:18];
    self.autoSwitch=[UISwitch new];self.autoSwitch.on=[DBValue(@"automaticEnabled") boolValue];
    self.enableSwitch=[UISwitch new];self.enableSwitch.on=[DBValue(@"enableNextSleepAlarm") boolValue];
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Wake planner settings" size:21 bold:YES],
        [self fieldRow:@"Preparation minutes (0–720)" field:self.leadField],
        [self fieldRow:@"Fallback hour (0–23)" field:self.fallbackHourField],
        [self fieldRow:@"Fallback minute (0–59)" field:self.fallbackMinuteField],
        [self fieldRow:@"Evening run hour (12–23)" field:self.runHourField],
        [self button:@"Choose calendar" action:@selector(chooseCalendar) emphasized:NO],
        [self switchRow:@"Automatic evening updates" control:self.autoSwitch],
        [self switchRow:@"Enable next Sleep alarm" control:self.enableSwitch]
    ]]];
    self.status=[self label:@"No diagnostic yet." size:13 bold:NO];
    self.status.textColor=[UIColor colorWithWhite:1 alpha:.78];
    [self.stack addArrangedSubview:[self card:@[
        [self label:@"Tweak status" size:21 bold:YES],self.status,
        [self button:@"Refresh status" action:@selector(refreshStatus) emphasized:NO],
        [self button:@"Copy diagnostic" action:@selector(copyReport) emphasized:NO],
        [self button:@"Share diagnostic" action:@selector(shareReport) emphasized:NO],
        [self button:@"Save diagnostic to Files" action:@selector(saveReport) emphasized:NO]
    ]]];
    UILabel *note=[self label:@"Only an existing next-only Sleep override can be changed. Recurring Health sleep schedules and ordinary alarms are never edited. Automatic updates remain off until enabled." size:13 bold:NO];
    note.textColor=[UIColor colorWithWhite:1 alpha:.65];[self.stack addArrangedSubview:note];
    [self refreshStatus];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[textField resignFirstResponder];[self saveFields];return YES;}
- (void)saveFields {
    DBWrite(@"leadMinutes",@(MAX(0,MIN(720,self.leadField.text.integerValue))));
    DBWrite(@"fallbackHour",@(MAX(0,MIN(23,self.fallbackHourField.text.integerValue))));
    DBWrite(@"fallbackMinute",@(MAX(0,MIN(59,self.fallbackMinuteField.text.integerValue))));
    DBWrite(@"runHour",@(MAX(12,MIN(23,self.runHourField.text.integerValue))));
    notify_post("com.soum91.daybreak.preferences");
}
- (void)saveSwitches {
    DBWrite(@"automaticEnabled",@(self.autoSwitch.on));
    DBWrite(@"enableNextSleepAlarm",@(self.enableSwitch.on));
    notify_post("com.soum91.daybreak.preferences");
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
        // A freshly calculated, short-lived plan can be used by the tweak even
        // if SpringBoard's own EventKit authorization is unavailable.
        DBWrite(@"appPlannedWake",wake);DBWrite(@"appPlanTimestamp",NSDate.date);DBWrite(@"appPlanMorning",morning);
        notify_post("com.soum91.daybreak.apply");
        [self alert:@"Sleep update requested" message:@"The tweak is checking the next-only Sleep override. Refresh the diagnostic after a few seconds, then verify Clock."];
    }];
}
- (void)previewTapped {[self calculate:NO];}
- (void)applyTapped {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Apply to Sleep | Wake Up?" message:@"Only an existing next-only override for tomorrow will be changed. Recurring sleep schedules remain untouched." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Apply once" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;[self calculate:YES];}]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)refreshStatus {
    NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.status.plist"]?:@{};
    self.status.text=[NSString stringWithFormat:@"%@\n%@\nUpdated: %@",state[@"code"]?:@"Not started",state[@"message"]?:@"No engine report yet",state[@"updated"]?:@"never"];
}
- (NSString *)report {
    NSString *log=[NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log" encoding:NSUTF8StringEncoding error:nil]?:@"No SpringBoard log accessible.";
    NSString *version=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"unknown";
    NSString *build=NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"unknown";
    return [NSString stringWithFormat:@"Daybreak tweak %@ (%@) · iOS %@\n\n%@\n\n%@",version,build,UIDevice.currentDevice.systemVersion,self.status.text?:@"",log];
}
- (void)copyReport {
    NSString *text=[self report];UIPasteboard.generalPasteboard.string=text;
    BOOL matched=[UIPasteboard.generalPasteboard.string isEqualToString:text];
    [self alert:matched?@"Copied and verified":@"Copy failed" message:matched?@"Full diagnostic read back from clipboard.":@"Use Share or Save to Files instead."];
}
- (void)shareReport {
    UIActivityViewController *activity=[[UIActivityViewController alloc] initWithActivityItems:@[[self report]] applicationActivities:nil];
    [self presentViewController:activity animated:YES completion:nil];
}
- (void)saveReport {
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Daybreak-diagnostic.txt"]];
    NSError *error=nil;
    if(![[self report] writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
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
    [self.window makeKeyAndVisible];return YES;
}
@end

int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(DBAppDelegate.class));}}
