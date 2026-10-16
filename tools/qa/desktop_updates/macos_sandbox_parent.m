// Real App Sandbox fixture. It accesses only its own fresh application data.
#import <Cocoa/Cocoa.h>
#import <unistd.h>

static void Write(NSDictionary *value, NSString *file) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
  [data writeToFile:file options:NSDataWritingAtomic error:nil];
}
static NSDictionary *Read(NSString *file) {
  NSData *data = [NSData dataWithContentsOfFile:file];
  return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
}
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc != 2 || ![[NSUUID alloc] initWithUUIDString:@(argv[1])]) return 2;
    NSApplication *application = NSApplication.sharedApplication;
    [application setActivationPolicy:NSApplicationActivationPolicyProhibited];
    [application finishLaunching];
    NSString *transaction = @(argv[1]);
    NSString *support = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *owned = [[support stringByAppendingPathComponent:@"DesktopUpdates"]
        stringByAppendingPathComponent:transaction];
    NSString *root = [owned stringByAppendingPathComponent:@"recovery"];
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files createDirectoryAtPath:root withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions:@0700} error:nil]) return 3;
    NSString *target = NSBundle.mainBundle.bundlePath;
    NSString *probe = [target.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:[@".sandbox-denial-" stringByAppendingString:transaction]];
    if ([@"fixture" writeToFile:probe atomically:NO encoding:NSUTF8StringEncoding error:nil]) {
      [files removeItemAtPath:probe error:nil];
      puts("SANDBOX_NOT_ENFORCED");
      return 4;
    }
    Write(@{@"schema_version":@1, @"transaction":transaction, @"target":target,
        @"backup":[root stringByAppendingPathComponent:@"previous.app"],
        @"old_pid":@(getpid()), @"old_build":@"77", @"new_build":@"78",
        @"new_release":@"native-sandbox-test"},
        [root stringByAppendingPathComponent:@"plan.json"]);
    Write(@{@"schema_version":@1, @"transaction":transaction, @"plan":@"plan.json"},
        [root stringByAppendingPathComponent:@"launch.json"]);
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = NO;
    configuration.addsToRecentItems = NO;
    configuration.createsNewApplicationInstance = YES;
    configuration.allowsRunningApplicationSubstitution = NO;
    __block BOOL done = NO, launched = NO;
    NSURL *helper = [NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"BOOHTACORDRecovery.app"];
    void (^complete)(NSRunningApplication *, NSError *) =
        ^(NSRunningApplication *app, NSError *error) {
          launched = app != nil && error == nil;
          if (error) {
            const char *domain = [error.domain isEqual:NSOSStatusErrorDomain] ? "osstatus" :
                [error.domain isEqual:NSCocoaErrorDomain] ? "cocoa" :
                [error.domain isEqual:NSPOSIXErrorDomain] ? "posix" : "other";
            printf("LAUNCH_FAILED domain=%s code=%ld\n", domain, (long)error.code);
          }
          done = YES;
        };
    [NSWorkspace.sharedWorkspace openApplicationAtURL:helper configuration:configuration
        completionHandler:^(NSRunningApplication *app, NSError *error) {
          if (error || !app) { complete(app, error); return; }
          NSWorkspaceOpenConfiguration *delivery = [configuration copy];
          delivery.createsNewApplicationInstance = NO;
          [NSWorkspace.sharedWorkspace openURLs:@[[NSURL fileURLWithPath:root isDirectory:YES]]
              withApplicationAtURL:helper configuration:delivery completionHandler:complete];
        }];
    NSDate *launchDeadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done && [NSDate.date compare:launchDeadline] == NSOrderedAscending)
      [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    BOOL ready = NO;
    if (launched) {
      NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
      while ([NSDate.date compare:deadline] == NSOrderedAscending) {
        ready = [Read([root stringByAppendingPathComponent:@"recovery-ready.json"])
            [@"transaction"] isEqual:transaction];
        if (ready) break;
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
      }
    }
    Write(@{@"transaction":transaction}, [root stringByAppendingPathComponent:@"cancel.json"]);
    BOOL cancelled = NO;
    NSDate *cancelDeadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (launched && [NSDate.date compare:cancelDeadline] == NSOrderedAscending) {
      NSDictionary *outcome = Read([root stringByAppendingPathComponent:@"recovery-outcome.json"]);
      cancelled = [outcome[@"transaction"] isEqual:transaction] &&
          [outcome[@"status"] isEqual:@"cancelled"];
      if (cancelled) break;
      [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    }
    printf("SANDBOX launched=%d ready=%d cancelled=%d\n", launched, ready, cancelled);
    if (cancelled) [files removeItemAtPath:owned error:nil];
    return ready && cancelled ? 0 : 3;
  }
}
