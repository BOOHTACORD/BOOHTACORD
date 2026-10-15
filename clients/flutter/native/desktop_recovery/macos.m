#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>
#import <pwd.h>
#import "macos_state.h"
#import "macos_handoff.h"
#import <os/log.h>
#import <CoreServices/CoreServices.h>

#ifndef BOOH_RECOVERY_PACKAGE_ID
#define BOOH_RECOVERY_PACKAGE_ID @"ru.boohtacord.boohtacordDesktop"
#endif
static NSString *const PackageID = BOOH_RECOVERY_PACKAGE_ID;
// LaunchServices can inherit a sandbox's CFFIXED_USER_HOME. It must not
// redefine this user's permitted installation or login recovery directory.
static NSString *UserHome(void) {
  struct passwd *user = getpwuid(getuid());
  return user ? [NSString stringWithUTF8String:user->pw_dir] : nil;
}
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
    status = SecStaticCodeCheckValidity(code,
                                        kSecCSCheckAllArchitectures |
                                            kSecCSCheckNestedCode |
                                            kSecCSStrictValidate,
                                        NULL);
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
  return [UserHome()
      stringByAppendingPathComponent:
          [NSString stringWithFormat:
                        @"Library/LaunchAgents/ru.boohtacord.recovery.%@.plist",
                        transaction]];
}
static void Register(NSString *plan, NSString *transaction, NSString *executable) {
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
        @[ executable, @"--plan", plan, @"--resumed" ],
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
static void CleanupRetiredRegistrations(NSString *root, NSString *target) {
  NSString *history = [root stringByAppendingPathComponent:@"retired"];
  NSFileManager *files = NSFileManager.defaultManager;
  for (NSString *name in [files contentsOfDirectoryAtPath:history error:nil]) {
    if (![[NSUUID alloc] initWithUUIDString:name]) continue;
    NSString *directory = [history stringByAppendingPathComponent:name];
    NSDictionary *cancel = Read([directory stringByAppendingPathComponent:@"cancel.json"]);
    NSDictionary *outcome = Read([directory stringByAppendingPathComponent:@"recovery-outcome.json"]);
    for (NSString *file in [files contentsOfDirectoryAtPath:directory error:nil]) {
      if (!RecoveryPlanName(file)) continue;
      NSDictionary *plan = Read([directory stringByAppendingPathComponent:file]);
      NSString *identifier = plan[@"transaction"];
      if (![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:identifier] ||
          ![plan[@"target"] isEqual:target]) continue;
      if ([cancel[@"transaction"] isEqual:identifier] || [outcome[@"transaction"] isEqual:identifier])
        RemoveRegistration(identifier);
    }
  }
}
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger position = [arguments indexOfObject:@"--plan"];
    os_log(OS_LOG_DEFAULT,
           "BOOHTACORD recovery: recovery_process_started argc=%{public}u plan_position=%{public}d",
           (unsigned)MIN(arguments.count, 64), position == NSNotFound ? -1 : (int)MIN(position, 64));
    BOOL documents = arguments.count == 1;
    if (!documents && (arguments.count < 3 || ![arguments[1] isEqual:@"--plan"])) {
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_arguments");
      return 2;
    }
    if (documents) {
      OSStatus registered = LSRegisterURL((__bridge CFURLRef)NSBundle.mainBundle.bundleURL, true);
      if (registered != noErr) {
        os_log_error(OS_LOG_DEFAULT,
            "BOOHTACORD recovery: recovery_registration code=%{public}d", registered);
        return 2;
      }
    }
    // Complete Cocoa startup before file access, signature validation or copying
    // the baseline. Those operations can block; LaunchServices must still be
    // able to report that the monitor started, independently of preflight.
    NSApplication *application = NSApplication.sharedApplication;
    [application setActivationPolicy:NSApplicationActivationPolicyProhibited];
    __attribute__((objc_precise_lifetime)) RecoveryDocumentHandoff *handoff =
        documents ? [RecoveryDocumentHandoff new] : nil;
    if (handoff) application.delegate = handoff;
    [application finishLaunching];
    os_log(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_cocoa_started");
    NSString *requestedTransaction = nil;
    NSString *requestedPlan = nil;
    if (documents) {
      if (!handoff.received) {
        NSTimer *timeout = [NSTimer scheduledTimerWithTimeInterval:10 repeats:NO
            block:^(NSTimer *timer) { StopRecoveryDocumentWait(application); }];
        // AppKit dispatches document-open events through its event loop.
        [application run];
        [timeout invalidate];
      }
      requestedPlan = RecoveryDocumentPlan(handoff.directory, UserHome(), &requestedTransaction);
      if (!requestedPlan) {
        os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_document_handoff");
        return 2;
      }
    } else {
      requestedPlan = arguments[2];
    }
    NSString *planPath =
        requestedPlan.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    if (![planPath
            hasPrefix:[UserHome() stringByAppendingString:@"/"]] ||
        ![planPath containsString:@"/DesktopUpdates/"]) {
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_plan_path");
      return 2;
    }
    NSDictionary *plan = Read(planPath);
    if (!plan) {
      // Fixed support reason only: never log a plan, user path or transaction.
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_plan_unreadable");
      fputs("recovery_plan_unreadable\n", stderr);
      return 2;
    }
    os_log(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_plan_loaded");
    NSString *transaction = plan[@"transaction"],
             *target = [plan[@"target"] stringByStandardizingPath],
             *backup = plan[@"backup"],
             *root = planPath.stringByDeletingLastPathComponent;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:transaction];
    BOOL permitted =
        [target hasPrefix:@"/Applications/"] ||
        [target hasPrefix:[UserHome()
                              stringByAppendingString:@"/Applications/"]];
    if (!uuid || !permitted ||
        (documents && ![requestedTransaction isEqual:transaction]) ||
        ![backup isEqual:[root stringByAppendingPathComponent:@"previous.app"]]) {
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_plan_identity");
      return 2;
    }
    int descriptor =
        open([[root stringByAppendingPathComponent:@"recovery.lock"]
                 fileSystemRepresentation],
             O_CREAT | O_RDWR, 0600);
    if (descriptor < 0) {
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_lock_open");
      return 0;
    }
    if (flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
      os_log_error(OS_LOG_DEFAULT, "BOOHTACORD recovery: recovery_lock_busy");
      close(descriptor);
      return 0;
    }
    // A queued launch may have read an older plan before acquiring the lock.
    if (![Read(planPath)[@"transaction"] isEqual:transaction]) return 0;
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
    NSString *monitorExecutable = NSBundle.mainBundle.executablePath;
    if (documents || [arguments containsObject:@"--retain-installed"]) {
      NSString *embedded = [target stringByAppendingPathComponent:
          @"Contents/Resources/BOOHTACORDRecovery.app"];
      if (![NSBundle.mainBundle.bundlePath.stringByResolvingSymlinksInPath
              isEqual:embedded.stringByResolvingSymlinksInPath] ||
          !ValidCode(target, plan[@"old_build"])) {
        finish(@"manualRecovery", @"monitor_identity");
        return 0;
      }
      // Copy only the verified, locally running installation. Never execute a
      // helper produced by the sandbox, downloaded separately or named by a
      // server field. Its retained copy survives replacement of the outer app.
      NSFileManager *files = NSFileManager.defaultManager;
      NSString *retained = [root stringByAppendingPathComponent:
          @"BOOHTACORDRecovery.app"];
      if (![files copyItemAtPath:target toPath:backup error:nil] ||
          !ValidCode(backup, plan[@"old_build"]) ||
          ![files copyItemAtPath:embedded toPath:retained error:nil]) {
        finish(@"manualRecovery", @"baseline_copy");
        return 0;
      }
      monitorExecutable = [retained stringByAppendingPathComponent:
          @"Contents/MacOS/BOOHTACORDRecovery"];
    }
    CleanupRetiredRegistrations(root, target);
    if (![arguments containsObject:@"--resumed"])
      Register(planPath, transaction, monitorExecutable);
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
    // The rollback monitor runs as this user, so reject an installation it
    // could not restore. Probe only after explicit apply consent, before Ready.
    struct stat installedVolume, recoveryVolume;
    NSString *parent = target.stringByDeletingLastPathComponent;
    if (stat(parent.fileSystemRepresentation, &installedVolume) != 0 ||
        stat(root.fileSystemRepresentation, &recoveryVolume) != 0 ||
        installedVolume.st_dev != recoveryVolume.st_dev) {
      finish(@"manualRecovery", @"recovery_volume");
      return 0;
    }
    NSString *probe = [parent
        stringByAppendingPathComponent:
            [@".boohtacord-update-" stringByAppendingString:transaction]];
    int probeDescriptor =
        open(probe.fileSystemRepresentation, O_CREAT | O_EXCL | O_WRONLY, 0600);
    if (probeDescriptor < 0) {
      finish(@"manualRecovery", @"replace_denied");
      return 0;
    }
    close(probeDescriptor);
    unlink(probe.fileSystemRepresentation);
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
      [NSRunLoop.currentRunLoop
          runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
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
      [NSRunLoop.currentRunLoop
          runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
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
        [NSRunLoop.currentRunLoop
          runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
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
