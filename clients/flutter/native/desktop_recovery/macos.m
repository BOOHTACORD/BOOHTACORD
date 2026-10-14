#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString *const PackageID = @"ru.boohtacord.boohtacordDesktop";
static NSDictionary *Read(NSString *file) {
  NSData *data = [NSData dataWithContentsOfFile:file];
  if (data.length > 65536)
    return nil;
  id value = data ? [NSJSONSerialization JSONObjectWithData:data
                                                    options:0
                                                      error:nil]
                  : nil;
  return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static NSDictionary *Info(NSString *app) {
  return [NSDictionary
      dictionaryWithContentsOfFile:
          [app stringByAppendingPathComponent:@"Contents/Info.plist"]];
}
static BOOL ValidCode(NSString *app, NSString *build) {
  NSDictionary *info = Info(app);
  if (![info[@"CFBundleIdentifier"] isEqual:PackageID] ||
      ![info[@"CFBundleVersion"] isEqual:build])
    return NO;
  SecStaticCodeRef code = NULL;
  OSStatus status = SecStaticCodeCreateWithPath(
      (__bridge CFURLRef)[NSURL fileURLWithPath:app], kSecCSDefaultFlags,
      &code);
  if (status == errSecSuccess)
    status = SecStaticCodeCheckValidity(
        code, kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, NULL);
  if (code)
    CFRelease(code);
  return status == errSecSuccess;
}
static void Atomic(NSDictionary *value, NSString *file) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:value
                                                 options:0
                                                   error:nil];
  [data writeToFile:file options:NSDataWritingAtomic error:nil];
}
static NSArray<NSRunningApplication *> *Instances(NSString *target) {
  NSMutableArray *out = [NSMutableArray new];
  for (NSRunningApplication *app in NSWorkspace.sharedWorkspace
           .runningApplications)
    if ([app.bundleURL.path.stringByStandardizingPath isEqual:target])
      [out addObject:app];
  return out;
}
static void Launch(NSString *target) {
  NSWorkspaceOpenConfiguration *configuration =
      [NSWorkspaceOpenConfiguration configuration];
  configuration.activates = NO;
  [NSWorkspace.sharedWorkspace
      openApplicationAtURL:[NSURL fileURLWithPath:target]
             configuration:configuration
         completionHandler:nil];
  // Service the completion callbacks without taking focus.
  [NSRunLoop.currentRunLoop
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
}
static NSString *Registration(NSString *transaction) {
  return [NSHomeDirectory()
      stringByAppendingPathComponent:
          [NSString stringWithFormat:
                        @"Library/LaunchAgents/ru.boohtacord.recovery.%@.plist",
                        transaction]];
}
static void Register(NSString *plan, NSString *transaction) {
  NSString *file = Registration(transaction);
  [NSFileManager.defaultManager
            createDirectoryAtPath:file.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES
                       attributes:@{
                         NSFilePosixPermissions : @0700
                       }
                            error:nil];
  NSDictionary *job = @{
    @"Label" : [@"ru.boohtacord.recovery." stringByAppendingString:transaction],
    @"ProgramArguments" :
        @[ NSBundle.mainBundle.executablePath, @"--plan", plan, @"--resumed" ],
    @"RunAtLoad" : @YES,
    @"StandardOutPath" : @"/dev/null",
    @"StandardErrorPath" : @"/dev/null"
  };
  [job writeToFile:file atomically:YES];
  NSTask *task = [NSTask new];
  task.launchPath = @"/bin/launchctl";
  task.arguments =
      @[ @"bootstrap", [NSString stringWithFormat:@"gui/%u", getuid()], file ];
  task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
  task.standardError = NSFileHandle.fileHandleWithNullDevice;
  [task launchAndReturnError:nil];
  [task waitUntilExit];
}
static void RemoveRegistration(NSString *transaction) {
  [NSFileManager.defaultManager removeItemAtPath:Registration(transaction)
                                           error:nil];
  // RunAtLoad has no KeepAlive: the already-running job exits after this
  // attempt.
}
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    if (arguments.count < 3 || ![arguments[1] isEqual:@"--plan"])
      return 2;
    NSString *planPath =
        arguments[2].stringByStandardizingPath.stringByResolvingSymlinksInPath;
    if (![planPath
            hasPrefix:[NSHomeDirectory() stringByAppendingString:@"/"]] ||
        ![planPath containsString:@"/DesktopUpdates/"])
      return 2;
    NSDictionary *plan = Read(planPath);
    NSString *transaction = plan[@"transaction"],
             *target = [plan[@"target"] stringByStandardizingPath],
             *backup = plan[@"backup"],
             *root = planPath.stringByDeletingLastPathComponent;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:transaction];
    BOOL permitted =
        [target hasPrefix:@"/Applications/"] ||
        [target hasPrefix:[NSHomeDirectory()
                              stringByAppendingString:@"/Applications/"]];
    if (!uuid || !permitted ||
        ![backup isEqual:[root stringByAppendingPathComponent:@"previous.app"]])
      return 2;
    int descriptor =
        open([[root stringByAppendingPathComponent:@"recovery.lock"]
                 fileSystemRepresentation],
             O_CREAT | O_RDWR, 0600);
    if (descriptor < 0 || flock(descriptor, LOCK_EX | LOCK_NB) != 0)
      return 0;
    NSString *outcome =
                 [root stringByAppendingPathComponent:@"recovery-outcome.json"],
             *ack = [root stringByAppendingPathComponent:@"bootstrap-ack.json"];
    NSDictionary *prior = Read(outcome);
    if ([prior[@"transaction"] isEqual:transaction] &&
        [@[ @"completed", @"rolledBack", @"manualRecovery" ]
            containsObject:prior[@"status"]]) {
      RemoveRegistration(transaction);
      return 0;
    }
    if (![arguments containsObject:@"--resumed"])
      Register(planPath, transaction);
    void (^finish)(NSString *, NSString *) =
        ^(NSString *status, NSString *reason) {
          Atomic(@{
            @"transaction" : transaction,
            @"status" : status,
            @"reason" : reason
          },
                 outcome);
          RemoveRegistration(transaction);
        };
    if (!ValidCode(backup, plan[@"old_build"])) {
      if (ValidCode(target, plan[@"old_build"]))
        finish(@"rolledBack", @"restore_interrupted");
      else
        finish(@"manualRecovery", @"baseline_identity");
      return 0;
    }
    BOOL (^cancelled)(void) = ^BOOL {
      return [Read(
          [root stringByAppendingPathComponent:@"cancel.json"])[@"transaction"]
          isEqual:transaction];
    };
    Atomic(@{@"transaction" : transaction},
           [root stringByAppendingPathComponent:@"recovery-ready.json"]);
    pid_t oldPID = [plan[@"old_pid"] intValue];
    NSDate *exitDeadline = [NSDate dateWithTimeIntervalSinceNow:180];
    while ([NSDate.date compare:exitDeadline] == NSOrderedAscending) {
      if (cancelled()) {
        finish(@"cancelled", @"apply_cancelled");
        return 0;
      }
      NSRunningApplication *old =
          [NSRunningApplication runningApplicationWithProcessIdentifier:oldPID];
      if (!old || old.terminated ||
          ![old.bundleURL.path.stringByStandardizingPath isEqual:target])
        break;
      [NSThread sleepForTimeInterval:.25];
    }
    NSRunningApplication *old =
        [NSRunningApplication runningApplicationWithProcessIdentifier:oldPID];
    if (old && !old.terminated &&
        [old.bundleURL.path.stringByStandardizingPath isEqual:target]) {
      finish(@"manualRecovery", @"old_process_running");
      return 0;
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:120];
    while ([NSDate.date compare:deadline] == NSOrderedAscending) {
      if (cancelled()) {
        finish(@"cancelled", @"apply_cancelled");
        return 0;
      }
      NSDictionary *receipt = Read(ack);
      if ([receipt[@"transaction"] isEqual:transaction] &&
          [receipt[@"release_id"] isEqual:plan[@"new_release"]] &&
          [receipt[@"native_build"] isEqual:plan[@"new_build"]] &&
          ValidCode(target, plan[@"new_build"])) {
        finish(@"completed", @"bootstrap");
        return 0;
      }
      [NSThread sleepForTimeInterval:.25];
    }
    NSDictionary *current = Info(target);
    NSString *build = current[@"CFBundleVersion"];
    if (build && ![build isEqual:plan[@"old_build"]] &&
        ![build isEqual:plan[@"new_build"]]) {
      finish(@"manualRecovery", @"installation_changed");
      return 0;
    }
    // Only an unacknowledged new process is asked to exit. Never force-kill it.
    if ([build isEqual:plan[@"new_build"]]) {
      for (NSRunningApplication *app in Instances(target))
        [app terminate];
      NSDate *quitDeadline = [NSDate dateWithTimeIntervalSinceNow:15];
      while (Instances(target).count > 0 &&
             [NSDate.date compare:quitDeadline] == NSOrderedAscending)
        [NSThread sleepForTimeInterval:.25];
      if (Instances(target).count > 0) {
        finish(@"manualRecovery", @"new_process_running");
        return 0;
      }
    }
    if (ValidCode(target, plan[@"old_build"])) {
      finish(@"rolledBack", @"apply_failed");
      if (Instances(target).count == 0)
        Launch(target);
      return 0;
    }
    NSString *failed = [root
        stringByAppendingPathComponent:[NSString
                                           stringWithFormat:@"failed-%@.app",
                                                            transaction]];
    if ([NSFileManager.defaultManager fileExistsAtPath:target] &&
        ![NSFileManager.defaultManager moveItemAtPath:target
                                               toPath:failed
                                                error:nil]) {
      finish(@"manualRecovery", @"replace_denied");
      return 0;
    }
    if (![NSFileManager.defaultManager moveItemAtPath:backup
                                               toPath:target
                                                error:nil]) {
      if ([NSFileManager.defaultManager fileExistsAtPath:failed])
        [NSFileManager.defaultManager moveItemAtPath:failed
                                              toPath:target
                                               error:nil];
      finish(@"manualRecovery", @"restore_denied");
      return 0;
    }
    finish(@"rolledBack", @"local_bootstrap");
    Launch(target);
    flock(descriptor, LOCK_UN);
    close(descriptor);
    return 0;
  }
}
