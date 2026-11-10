#import <UIKit/UIKit.h>
#import "../DBDiagnosticExport.h"
#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <Preferences/PSListController.h>

// Small PreferenceLoader controller with no Cephei dependency.
@interface DBRootListController : PSListController
@end

@implementation DBRootListController
- (NSMutableArray *)specifiers {
    // Use PSListController's inherited _specifiers ivar. A shadow ivar left
    // the superclass table data source empty, causing the black Settings page.
    if(!_specifiers) {
        NSArray *loaded=[self loadSpecifiersFromPlistName:@"Root" target:self bundle:[NSBundle bundleForClass:self.class]];
        _specifiers=[loaded mutableCopy]?:[NSMutableArray new];
    }
    return _specifiers;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"Daybreak";
    // Show actual installed bundle metadata, not an online release version.
    NSDictionary *info=[NSBundle bundleForClass:self.class].infoDictionary;
    NSString *version=info[@"CFBundleShortVersionString"]?:@"unknown";
    NSString *build=info[@"CFBundleVersion"]?:@"unknown";
    self.navigationItem.prompt=[NSString stringWithFormat:@"Installed %@ (%@) · iOS 16 Dopamine",version,build];
}
- (void)notify:(const char *)name { notify_post(name); }
- (void)info:(NSString *)title message:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)previewNow:(id)specifier {
    (void)specifier; [self notify:"com.soum91.daybreak.preview"];
    [self info:@"Preview requested" message:@"Open Show / export diagnostic after a few seconds to see tomorrow's calculated wake time. This does not change Clock."];
}
- (void)applyNow:(id)specifier {
    (void)specifier;
    [self info:@"Automatic Sleep updates"
       message:@"With automatic mode on, Daybreak rechecks tomorrow's calendar once per hour during the configured daytime window, then attempts a one-day native Sleep override without an Apply step. Use Run automation now in the Daybreak app to request an immediate check. Native changes on this iPhone do not prove that iPhone 17 or Apple Watch received the time. No ordinary MobileTimer alarm is created."];
}
- (void)chooseCalendar:(id)specifier {
    (void)specifier;
    EKAuthorizationStatus status=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if(status!=EKAuthorizationStatusAuthorized) {
        [self info:@"Calendar access unavailable"
              message:@"The Settings process cannot enumerate calendars. Daybreak defaults to All calendars. Check diagnostics for SpringBoard's calendar permission (no private TCC database is modified)."];
        return;
    }
    EKEventStore *store=[EKEventStore new];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Calendar selection"
        message:@"Choose one calendar for the earliest morning event, or use all calendars."
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"All calendars" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action; [self setCalendarID:nil];
    }]];
    for(EKCalendar *calendar in [store calendarsForEntityType:EKEntityTypeEvent]) {
        NSString *identifier=[calendar.calendarIdentifier copy];
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)",calendar.title,calendar.source.title]
                   style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;[self setCalendarID:identifier];}]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover=sheet.popoverPresentationController;
    if(popover) {popover.sourceView=self.view;popover.sourceRect=CGRectMake(self.view.bounds.size.width/2,100,1,1);}
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)setCalendarID:(NSString *)identifier {
    CFPreferencesSetAppValue(CFSTR("calendarID"),(__bridge CFPropertyListRef)identifier,CFSTR("com.soum91.daybreak.tweak"));
    CFPreferencesAppSynchronize(CFSTR("com.soum91.daybreak.tweak"));
    [self notify:"com.soum91.daybreak.preferences"];
    [self info:@"Calendar saved" message:identifier?@"Selected calendar saved.":@"All calendars selected."];
}
- (NSString *)report {
    NSString *log=[NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.log"
                                               encoding:NSUTF8StringEncoding error:nil]?:@"No log yet. SpringBoard injection may not have loaded.";
    NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.soum91.daybreak.tweak.status.plist"]?:@{};
    NSDictionary *info=[NSBundle bundleForClass:self.class].infoDictionary;
    return [NSString stringWithFormat:@"Daybreak tweak diagnostics\nInstalled: %@ (%@)\nSystem: %@\n\nStatus:\n%@\n\nEvents:\n%@",
            info[@"CFBundleShortVersionString"]?:@"unknown",info[@"CFBundleVersion"]?:@"unknown",
            UIDevice.currentDevice.systemVersion,status,log];
}
- (void)showDiagnostic:(id)specifier {
    (void)specifier;
    NSString *report=[self report];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Daybreak diagnostic"
        message:[report substringFromIndex:MAX((NSInteger)report.length-1400,0)] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy and verify" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;
        NSString *failure=nil;
        BOOL match=DBDiagnosticCopyToClipboard(report,&failure);
        [self info:match?@"Copied and verified":@"Clipboard failed"
              message:match?@"The full diagnostic was read back from the clipboard.":failure?:@"Use Share or Save to Files instead."];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[report] applicationActivities:nil];
        [self presentViewController:share animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save to Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;
        NSError *error=nil;
        NSURL *url=DBDiagnosticWriteExport(report,&error);
        if(!url) {
            [self info:@"Save failed" message:error.localizedDescription?:@"Cannot create diagnostic file."];return;
        }
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
