#import "Backend.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
static volatile sig_atomic_t quitting;
static void quit(int s) { quitting=1; }
int main(void) { @autoreleasepool {
  signal(SIGTERM,quit); signal(SIGINT,quit); signal(SIGPIPE,SIG_IGN);
  const char *dir="/var/jb/var/run/usbkeys", *path="/var/jb/var/run/usbkeys/control.sock";
  mkdir(dir,0750); chown(dir,0,501); chmod(dir,0750);
  int server=socket(AF_UNIX,SOCK_STREAM,0); if(server<0) return 1;
  struct sockaddr_un addr={0}; addr.sun_family=AF_UNIX; strlcpy(addr.sun_path,path,sizeof(addr.sun_path));
  unlink(path); umask(0117);
  if(bind(server,(struct sockaddr *)&addr,sizeof(addr))||listen(server,4)) return 2;
  chown(path,0,501); chmod(path,0660);
  UKBackend *backend=[UKBackend new]; double last=clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9;
  while(!quitting) { @autoreleasepool {
    [backend maintain];
    double now=clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9;
    if(backend.active&&now-last>30) [backend stop];
    struct pollfd p={server,POLLIN,0}; if(poll(&p,1,[backend pollMilliseconds])<=0) continue;
    int client=accept(server,NULL,NULL); if(client<0) continue;
    uid_t uid=0; gid_t gid=0;
    if(getpeereid(client,&uid,&gid)||(uid!=501&&uid!=0)) { close(client); continue; }
    struct timeval timeout={2,0}; setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout)); setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
    char bytes[4096]; size_t used=0; BOOL complete=NO;
    while(used<sizeof(bytes)) { ssize_t n=read(client,bytes+used,sizeof(bytes)-used); if(n<=0) break; used+=n; if(memchr(bytes,'\n',used)) {complete=YES; break;} }
    NSDictionary *request=complete?[NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:bytes length:used] options:0 error:NULL]:nil;
    NSDictionary *result=nil;
    if([request isKindOfClass:NSDictionary.class]) {
      NSString *op=request[@"op"]; last=clock_gettime_nsec_np(CLOCK_MONOTONIC)/1e9;
      @try {
      if([op isEqual:@"start"]) result=[backend start];
      else if([op isEqual:@"stop"]) result=[backend stop];
      else if([op isEqual:@"probe"]) result=[backend probe];
      else if([op isEqual:@"key"]&&[request[@"key"] isKindOfClass:NSNumber.class]&&[request[@"modifier"] isKindOfClass:NSNumber.class]) {
        int key=[request[@"key"] intValue],mod=[request[@"modifier"] intValue];
        if(key>=4&&key<=0x65&&mod>=0&&mod<=255) result=[backend key:key modifier:mod];
      } else if([op isEqual:@"ping"]) { NSMutableDictionary *live=[[backend status] mutableCopy]; live[@"ok"]=@YES; result=live; }
      else if([op isEqual:@"status"]) result=[backend status];
      } @catch(NSException *exception) { result=[backend exception:exception.name]; }
    }
    if(!result) result=@{@"ok":@NO,@"message":@"Invalid request"};
    NSMutableData *data=[[NSJSONSerialization dataWithJSONObject:result options:0 error:NULL] mutableCopy]; [data appendBytes:"\n" length:1];
    const uint8_t *cursor=data.bytes; size_t remaining=data.length;
    while(remaining) { ssize_t n=write(client,cursor,remaining); if(n<=0) break; cursor+=n; remaining-=n; }
    close(client);
    // Create hung on a worker thread: restart cleanly (launchd KeepAlive relaunches us).
    if(backend.exitRequested) _exit(0);
  }}
  [backend stop]; close(server); unlink(path); return 0;
}}
