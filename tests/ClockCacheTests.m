// Exercise cache preservation and interrupted-swap recovery with a fake owned
// group directory. Never requests an extension on a phone or touches Clock.
#define CLOCK_ACCESS_TESTING 1
#import "../App/ClockAccess.m"
static void Require(BOOL ok,NSString *message) { if(!ok) { NSLog(@"FAIL: %@",message);exit(1); } }
static NSString *Fixture(NSString *root) {
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *cache=[root stringByAppendingPathComponent:@"Library/Caches"];
    Require([fm createDirectoryAtPath:[cache stringByAppendingPathComponent:@"nested"] withIntermediateDirectories:YES attributes:nil error:nil],@"create fixture");
    Require([@"retain this cache" writeToFile:[cache stringByAppendingPathComponent:@"nested/original.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil],@"write fixture");
    return cache;
}
int main(void) { @autoreleasepool {
    NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *cache=Fixture(root);NSString *saved=[[cache stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".daybreak-wq-caches.saved"];
    NSString *original=[cache stringByAppendingPathComponent:@"nested/original.txt"];
    struct stat before,after;Require(lstat(cache.fileSystemRepresentation,&before)==0,@"original inode");
    DBClockInspector *probe=[DBClockInspector new];probe.testGroupRoot=root;probe.group=@"group.invalid.daybreak.test";
    // /nonexistent cannot issue a valid extension. Regardless of return code,
    // cleanup must restore the exact cache directory and its nested contents.
    [probe grant:@"/nonexistent-daybreak-test" alternate:NO];
    Require(!probe.cacheFailure,@"normal failure cleanup");
    Require(lstat(cache.fileSystemRepresentation,&after)==0 && before.st_ino==after.st_ino,@"original inode preserved");
    Require([[NSString stringWithContentsOfFile:original encoding:NSUTF8StringEncoding error:nil] isEqual:@"retain this cache"],@"nested contents preserved");
    Require(rename(cache.fileSystemRepresentation,saved.fileSystemRepresentation)==0,@"simulate interrupted rename");
    Require(symlink("/nonexistent-daybreak-test",cache.fileSystemRepresentation)==0,@"simulate interrupted symlink");
    [probe grant:@"/nonexistent-daybreak-test" alternate:NO];
    Require(!probe.cacheFailure && lstat(cache.fileSystemRepresentation,&after)==0 && before.st_ino==after.st_ino,@"interrupted swap recovered");
    // Collision: do not delete either directory if both exist.
    Require([NSFileManager.defaultManager createDirectoryAtPath:saved withIntermediateDirectories:NO attributes:nil error:nil],@"collision fixture");
    int64_t rc=[probe grant:@"/nonexistent-daybreak-test" alternate:NO];
    Require(rc==-18 && probe.cacheFailure,@"collision blocks query");
    Require([[NSString stringWithContentsOfFile:original encoding:NSUTF8StringEncoding error:nil] isEqual:@"retain this cache"],@"collision preserves contents");
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    NSLog(@"PASS: cache inode/content preservation, interrupted swap recovery, collision refusal");
} return 0; }
