#import <Foundation/Foundation.h>
// Explicit, read-only Clock storage discovery. Does not invoke XCTest or Siri.
@interface ClockAccess : NSObject
+ (void)inspect:(void (^)(NSString *report))completion;
+ (void)inspectWithProgress:(void (^)(NSString *report, BOOL finished))progress;
@end
