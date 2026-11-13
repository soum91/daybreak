#import <Foundation/Foundation.h>
@interface UKBackend : NSObject
@property(nonatomic,readonly) BOOL active;
@property(nonatomic,readonly) BOOL exitRequested;
- (int)pollMilliseconds;
- (void)maintain;
- (NSDictionary *)probe;
- (NSDictionary *)start;
- (NSDictionary *)stop;
- (NSDictionary *)key:(uint8_t)key modifier:(uint8_t)modifier;
- (NSDictionary *)status;
- (NSDictionary *)exception:(NSString *)name;
@end
