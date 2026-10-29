#import <UIKit/UIKit.h>
#import <IntentsUI/IntentsUI.h>
#import "Probe.h"

@interface DaybreakController : UIViewController <INUIAddVoiceShortcutViewControllerDelegate>
@property(nonatomic) Probe *probe;
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
    UILabel *intro=[self label:@"Sleep alarm diagnostic · 0.1\nTest the real Clock Sleep | Wake Up alarm before adding calendar automation." size:15 weight:UIFontWeightRegular];
    intro.textColor=UIColor.secondaryLabelColor; [stack addArrangedSubview:intro];
    self.statusLabel=[self label:@"Ready to inspect" size:17 weight:UIFontWeightSemibold];
    self.statusLabel.accessibilityIdentifier=@"probeStatus"; [stack addArrangedSubview:self.statusLabel];
    self.scanButton=[self button:@"1. Inspect Sleep alarm access" action:@selector(scan) primary:YES]; [stack addArrangedSubview:self.scanButton];
    [stack addArrangedSubview:[self label:@"Test wake-up time" size:16 weight:UIFontWeightSemibold]];
    self.picker=[UIDatePicker new]; self.picker.datePickerMode=UIDatePickerModeTime; self.picker.preferredDatePickerStyle=UIDatePickerStyleWheels;
    self.picker.date=[NSCalendar.currentCalendar dateBySettingHour:8 minute:30 second:0 ofDate:NSDate.now options:0];
    [self.picker.heightAnchor constraintEqualToConstant:130].active=YES; [stack addArrangedSubview:self.picker];
    self.siriButton=[self button:@"2. Test Siri shortcut support" action:@selector(siri) primary:NO]; [stack addArrangedSubview:self.siriButton];
    self.writeButton=[self button:@"3. Apply to next-only override" action:@selector(confirmWrite) primary:NO]; [stack addArrangedSubview:self.writeButton];
    self.restoreButton=[self button:@"Restore saved override" action:@selector(confirmRestore) primary:NO]; [stack addArrangedSubview:self.restoreButton];
    UILabel *details=[self label:@"Inspect does not change alarms. The Siri test checks whether the internal action can be saved; saving is not execution. Direct editing is enabled only for an existing next-only override. Check Clock after any test. Calendar automation is not included yet." size:13 weight:UIFontWeightRegular];
    details.textColor=UIColor.secondaryLabelColor; [stack addArrangedSubview:details];
    UIButton *clock=[self button:@"Open Clock" action:@selector(openClock) primary:NO]; [stack addArrangedSubview:clock];
    [stack addArrangedSubview:[self label:@"Diagnostic report" size:18 weight:UIFontWeightBold]];
    self.log=[UITextView new]; self.log.editable=NO; self.log.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.log.backgroundColor=UIColor.secondarySystemBackgroundColor; self.log.layer.cornerRadius=14;
    self.log.textContainerInset=UIEdgeInsetsMake(12,8,12,8); [self.log.heightAnchor constraintEqualToConstant:290].active=YES;
    [stack addArrangedSubview:self.log];
    self.probe=[Probe new]; __weak typeof(self) weak=self;
    self.probe.changed=^{[weak refresh];}; [self refresh];
    [self.probe note:@"App ready. No alarm changes occur on launch."];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"]) [self scan];
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
- (void)scan { [self.probe scan]; }
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
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[DaybreakController new]];
    self.window.tintColor=UIColor.systemOrangeColor; [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(DaybreakApp.class)); }
}
