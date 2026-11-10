#import "DBPlanner.h"

BOOL DBIsSameDay(NSCalendar *calendar, NSDate *a, NSDate *b) {
    return a && b && [calendar isDate:a inSameDayAsDate:b];
}

NSDictionary *DBWakePlan(NSCalendar *calendar, NSDate *now, NSArray<NSDate *> *eventStarts,
                         NSInteger leadMinutes, NSInteger fallbackHour, NSInteger fallbackMinute) {
    NSDate *tomorrow=[calendar dateByAddingUnit:NSCalendarUnitDay value:1
                                          toDate:[calendar startOfDayForDate:now] options:0];
    NSDate *noon=[calendar dateBySettingHour:12 minute:0 second:0 ofDate:tomorrow options:0];
    NSDate *first=nil;
    for(id date in eventStarts) {
        if(![date isKindOfClass:NSDate.class] || [date compare:tomorrow]==NSOrderedAscending ||
           [date compare:noon]!=NSOrderedAscending) continue;
        if(!first || [date compare:first]==NSOrderedAscending) first=date;
    }
    NSInteger lead=MAX(0,MIN(720,leadMinutes));
    NSInteger hour=MAX(0,MIN(23,fallbackHour));
    NSInteger minute=MAX(0,MIN(59,fallbackMinute));
    NSDate *wake=first?[first dateByAddingTimeInterval:-60*lead]:
        [calendar dateBySettingHour:hour minute:minute second:0 ofDate:tomorrow options:0];
    return @{@"morning":tomorrow,@"wake":wake,@"usedEvent":@(first!=nil),
             @"eventStart":first?:[NSNull null]};
}
