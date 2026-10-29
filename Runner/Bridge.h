#import <Foundation/Foundation.h>
@interface DaybreakLaunch : NSObject
+ (NSArray<NSDictionary *> *)takeRequests;
+ (void)markReady;
+ (NSString *)caught:(void (^)(void))work;
@end
