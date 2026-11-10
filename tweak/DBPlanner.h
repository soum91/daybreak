#import <Foundation/Foundation.h>

// The shared planner only accepts already-filtered timed event starts.
FOUNDATION_EXPORT NSDictionary *DBWakePlan(NSCalendar *calendar, NSDate *now,
                                            NSArray<NSDate *> *eventStarts,
                                            NSInteger leadMinutes,
                                            NSInteger fallbackHour,
                                            NSInteger fallbackMinute);
FOUNDATION_EXPORT BOOL DBIsSameDay(NSCalendar *calendar, NSDate *a, NSDate *b);
