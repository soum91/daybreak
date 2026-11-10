#import <UIKit/UIKit.h>

// Common diagnostic export helpers for the home-screen app and the Preferences
// bundle. Copy never creates a file. Save uses a writable user-cache location
// instead of relying on NSTemporaryDirectory(), which can resolve to /tmp in
// an unsandboxed jailbreak app or in the Preferences host.

static inline BOOL DBDiagnosticCopyToClipboard(NSString *report, NSString **failure) {
    if(!report.length) {
        if(failure) *failure=@"The diagnostic report was empty.";
        return NO;
    }
    @try {
        UIPasteboard *board=UIPasteboard.generalPasteboard;
        board.string=report;
        if([board.string isEqualToString:report]) return YES;

        // Some tweak-injected processes reject the convenience setter. Try
        // the standard explicit UTF-8 item representation before failing.
        [board setItems:@[@{@"public.utf8-plain-text":report}]];
        if([board.string isEqualToString:report]) return YES;
        if(failure) *failure=@"The clipboard did not return the full report. Use Share, Save to Files, or select the report text.";
    } @catch(NSException *exception) {
        if(failure) *failure=[NSString stringWithFormat:@"Clipboard exception: %@. Use Share or Save to Files.",exception.name];
    }
    return NO;
}

static inline NSURL *DBDiagnosticWriteExport(NSString *report, NSError **error) {
    if(!report.length) {
        if(error) *error=[NSError errorWithDomain:@"DaybreakDiagnostics" code:1
                                              userInfo:@{NSLocalizedDescriptionKey:@"Report is empty."}];
        return nil;
    }
    NSFileManager *manager=NSFileManager.defaultManager;
    NSURL *caches=[manager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    if(!caches) {
        if(error) *error=[NSError errorWithDomain:@"DaybreakDiagnostics" code:2
                                              userInfo:@{NSLocalizedDescriptionKey:@"No writable cache directory was returned."}];
        return nil;
    }
    NSURL *directory=[caches URLByAppendingPathComponent:@"DaybreakDiagnostics" isDirectory:YES];
    if(![manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSString *filename=[NSString stringWithFormat:@"Daybreak-diagnostic-%@.txt",[[NSUUID UUID] UUIDString]];
    NSURL *file=[directory URLByAppendingPathComponent:filename isDirectory:NO];
    NSData *contents=[report dataUsingEncoding:NSUTF8StringEncoding];
    if(![contents writeToURL:file options:NSDataWritingAtomic error:error]) return nil;
    NSData *verified=[NSData dataWithContentsOfURL:file options:0 error:error];
    if(![verified isEqualToData:contents]) {
        if(error) *error=[NSError errorWithDomain:@"DaybreakDiagnostics" code:3
                                              userInfo:@{NSLocalizedDescriptionKey:@"Saved file did not match the full report."}];
        return nil;
    }
    return file;
}
