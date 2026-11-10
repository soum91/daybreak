#import <Foundation/Foundation.h>
#import "../tweak/DBPlanner.h"

static NSDate *At(NSCalendar *c,NSInteger year,NSInteger month,NSInteger day,NSInteger hour,NSInteger minute) {
    NSDateComponents *parts=[NSDateComponents new];
    parts.year=year;parts.month=month;parts.day=day;parts.hour=hour;parts.minute=minute;
    return [c dateFromComponents:parts];
}
int main(void) {
    @autoreleasepool {
        NSCalendar *calendar=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        calendar.timeZone=[NSTimeZone timeZoneWithName:@"America/Toronto"];
        NSDate *now=At(calendar,2026,11,10,18,0);
        NSArray *events=@[At(calendar,2026,11,11,12,0),At(calendar,2026,11,11,9,10),
                          At(calendar,2026,11,11,10,0)];
        NSDictionary *plan=DBWakePlan(calendar,now,events,75,8,30);
        NSCAssert([plan[@"usedEvent"] boolValue],@"Morning event should win");
        NSCAssert([plan[@"wake"] isEqual:At(calendar,2026,11,11,7,55)],@"Event minus lead");
        plan=DBWakePlan(calendar,now,@[At(calendar,2026,11,11,12,0)],60,8,30);
        NSCAssert(![plan[@"usedEvent"] boolValue],@"Noon isn't a morning event");
        NSCAssert([plan[@"wake"] isEqual:At(calendar,2026,11,11,8,30)],@"Fallback exact");
        plan=DBWakePlan(calendar,now,@[At(calendar,2026,11,11,1,0)],720,8,30);
        NSCAssert(!DBIsSameDay(calendar,plan[@"wake"],plan[@"morning"]),@"Cross-day alarm must be rejected by engine");
        plan=DBWakePlan(calendar,now,@[],999,25,-2);
        NSCAssert([plan[@"wake"] isEqual:At(calendar,2026,11,11,23,0)],@"Clamp invalid fallback inputs");
        puts("DAYBREAK_TWEAK_PLANNER_PASS");
    }
    return 0;
}
