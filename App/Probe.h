#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

NS_ASSUME_NONNULL_BEGIN
@interface Probe : NSObject
@property(nonatomic, copy) void (^changed)(void);
@property(nonatomic, readonly) NSString *report;
@property(nonatomic, readonly) NSString *status;
@property(nonatomic, readonly) BOOL busy;
@property(nonatomic, readonly) BOOL hasOverride;
@property(nonatomic, readonly) BOOL canRestore;
- (void)scan;
- (void)changeOverrideTo:(NSDate *)date;
- (void)restore;
- (nullable INShortcut *)shortcutForDate:(NSDate *)date;
- (void)note:(NSString *)message;
@end
NS_ASSUME_NONNULL_END
