#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

static void Dump(Class cls, NSString *selector) {
    id object=[[cls alloc] init]; SEL s=NSSelectorFromString(selector);
    if(![object respondsToSelector:s]){NSLog(@"%@ %@ missing",NSStringFromClass(cls),selector);return;}
    for(int i=0;i<16;i++) {
        id value=((id(*)(id,SEL,int))objc_msgSend)(object,s,i);
        NSLog(@"%@ %d = %@",selector,i,value);
    }
}
int main(void) {
    @autoreleasepool {
        NSLog(@"Host: %@",NSProcessInfo.processInfo.operatingSystemVersionString);
        Dump(NSClassFromString(@"_INPBAlarmSearch"),@"alarmReferenceTypeAsString:");
        Dump(NSClassFromString(@"_INPBAlarmSearch"),@"alarmSearchStatusAsString:");
        Dump(NSClassFromString(@"_INPBUpdateAlarmIntent"),@"operationAsString:");
        for(NSString *name in @[@"INAlarm",@"INAlarmSearch",@"INSleepAlarmAttribute",@"INUpdateAlarmIntent"]) {
            Class cls=NSClassFromString(name); unsigned int count=0;
            Method *methods=class_copyMethodList(cls,&count);
            for(unsigned int i=0;i<count;i++) {
                NSString *s=NSStringFromSelector(method_getName(methods[i]));
                if([s hasPrefix:@"initWith"] || [s containsString:@"Execution"] || [s containsString:@"Suggestions"]) NSLog(@"%@ %@ %s",name,s,method_getTypeEncoding(methods[i]));
            }
            free(methods);
        }
        // No execution, donation, or connection to an alarm service.
        @try {
            id attribute=((id(*)(id,SEL,id,id))objc_msgSend)([NSClassFromString(@"INSleepAlarmAttribute") alloc],NSSelectorFromString(@"initWithBedtime:override:"),nil,@YES);
            id alarm=((id(*)(id,SEL,id,id,id,id,id,unsigned long long,id))objc_msgSend)([NSClassFromString(@"INAlarm") alloc],NSSelectorFromString(@"initWithIdentifier:dateTime:label:enabled:firing:alarmRepeatScheduleOptions:sleepAlarmAttribute:"),nil,nil,nil,@YES,@NO,0,attribute);
            NSDateComponents *c=[NSDateComponents new]; c.hour=8; c.minute=30;
            INDateComponentsRange *range=[[INDateComponentsRange alloc] initWithStartDateComponents:c endDateComponents:nil];
            id intent=((id(*)(id,SEL,id,id,long long,id,id))objc_msgSend)([NSClassFromString(@"INUpdateAlarmIntent") alloc],NSSelectorFromString(@"initWithAlarmSearch:alarm:operation:proposedTime:proposedLabel:"),nil,alarm,2LL,range,nil);
            NSLog(@"Intent constructed: %@",intent);
            INShortcut *shortcut=[[INShortcut alloc] initWithIntent:intent];
            NSLog(@"INShortcut accepted: %@",shortcut?@"YES":@"NO");
            NSLog(@"Codable: %@",((id(*)(id,SEL))objc_msgSend)(intent,NSSelectorFromString(@"_codableDescription")));
        } @catch(NSException *e) { NSLog(@"Construction exception %@: %@",e.name,e.reason); }
    } return 0;
}
