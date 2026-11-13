#pragma once
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/sysctl.h>
static inline NSNumber *UKBootSession(void) {
  struct timeval boot={0}; size_t length=sizeof(boot);
  return sysctlbyname("kern.boottime",&boot,&length,NULL,0)==0?@(boot.tv_sec):@0;
}
static inline NSString *UKJournalPath(void) { return @"/var/jb/var/run/usbkeys/status.json"; }
static inline NSDictionary *UKReadJournal(void) {
  NSData *data=[NSData dataWithContentsOfFile:UKJournalPath()];
  if(!data.length) return nil;
  id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
  return [value isKindOfClass:NSDictionary.class]?value:nil;
}
static inline BOOL UKWriteJournal(NSDictionary *state) {
  NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:NULL];
  if(!data||![data writeToFile:UKJournalPath() atomically:YES]) return NO;
  const char *path=UKJournalPath().fileSystemRepresentation;
  return chown(path,0,501)==0&&chmod(path,0640)==0;
}
