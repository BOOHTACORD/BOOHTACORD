#import "Bridge.h"
#import <Security/Security.h>
#import <Sparkle/Sparkle.h>
#import <objc/runtime.h>
#import <pwd.h>
#import <unistd.h>
#import "../../../native/desktop_recovery/macos_state.h"

@interface BOOHDesktopUpdates : NSObject <SPUUserDriver, SPUUpdaterDelegate>
@property(nonatomic, strong) FlutterMethodChannel *channel;
@property(nonatomic, strong) SPUUpdater *updater;
@property(nonatomic, strong) NSURL *feed;
@property(nonatomic, copy) NSString *expectedBuild;
@property(nonatomic, copy) NSString *expectedURL;
@end

@implementation BOOHDesktopUpdates
- (BOOL)capable {
  NSString *location = NSBundle.mainBundle.bundlePath;
  struct passwd *user = getpwuid(getuid());
  NSString *home =
      user ? [NSString stringWithUTF8String:user->pw_dir] : NSHomeDirectory();
  BOOL installed =
      [location hasPrefix:@"/Applications/"] ||
      [location hasPrefix:[home stringByAppendingString:@"/Applications/"]];
  NSNumber *readOnly = nil;
  [NSBundle.mainBundle.bundleURL getResourceValue:&readOnly
                                           forKey:NSURLVolumeIsReadOnlyKey
                                            error:nil];
  return installed && ![location containsString:@"AppTranslocation"] &&
         !readOnly.boolValue;
}
- (void)fail:(FlutterResult)result code:(NSString *)code {
  result([FlutterError
      errorWithCode:code
            message:@"Desktop update could not be applied safely"
            details:nil]);
}
- (BOOL)ownedPath:(NSString *)value {
  NSString *support = NSSearchPathForDirectoriesInDomains(
                          NSApplicationSupportDirectory, NSUserDomainMask, YES)
                          .firstObject;
  NSString *resolved =
      value.stringByStandardizingPath.stringByResolvingSymlinksInPath;
  return [resolved hasPrefix:[support stringByAppendingString:@"/"]] &&
         [resolved containsString:@"/DesktopUpdates/"];
}
- (void)handle:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"capable"]) {
    result(@([self capable]));
    return;
  }
  NSDictionary *args =
      [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
  if ([call.method isEqualToString:@"freeBytes"]) {
    NSString *directory = args[@"directory"];
    if (![directory isKindOfClass:NSString.class] ||
        ![self ownedPath:directory]) {
      [self fail:result code:@"staging_path"];
      return;
    }
    NSDictionary *attributes =
        [NSFileManager.defaultManager attributesOfFileSystemForPath:directory
                                                              error:nil];
    result(attributes[NSFileSystemFreeSize] ?: @0);
    return;
  }
  if ([call.method isEqualToString:@"resetRecovery"]) {
    NSString *directory = args[@"directory"];
    if (![directory isKindOfClass:NSString.class] || ![self ownedPath:directory] ||
        ![directory.lastPathComponent isEqual:@"recovery"]) {
      [self fail:result code:@"recovery_path"];
      return;
    }
    result(@(ResetInactiveRecovery(directory)));
    return;
  }
  if ([call.method isEqualToString:@"armRecovery"]) {
    NSString *plan = args[@"plan"];
    if (![plan isKindOfClass:NSString.class] || ![self ownedPath:plan] ||
        !RecoveryPlanName(plan.lastPathComponent)) {
      [self fail:result code:@"recovery_path"];
      return;
    }
    // Sandbox-created executable copies receive quarantine flags. Launch only
    // the monitor sealed inside this installed app; it retains its own trusted
    // copy and baseline outside the application sandbox after apply consent.
    NSURL *helper = [NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"BOOHTACORDRecovery.app"];
    NSWorkspaceOpenConfiguration *configuration =
        [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = NO;
    configuration.addsToRecentItems = NO;
    configuration.createsNewApplicationInstance = YES;
    configuration.allowsRunningApplicationSubstitution = NO;
    NSURL *directory = [NSURL fileURLWithPath:plan.stringByDeletingLastPathComponent
                                 isDirectory:YES];
    // App Sandbox ignores NSWorkspace launch arguments. The document-open
    // event carries this owned directory and its scoped access instead.
    [NSWorkspace.sharedWorkspace
        openURLs:@[ directory ]
        withApplicationAtURL:helper
               configuration:configuration
           completionHandler:^(NSRunningApplication *app, NSError *error) {
             dispatch_async(dispatch_get_main_queue(), ^{
               if (error || !app) {
                 [self fail:result code:@"recovery_start"];
                 return;
               }
               result(nil);
             });
           }];
    return;
  }
  if ([call.method isEqualToString:@"acknowledge"]) {
    BOOL correct =
        [args[@"version"]
            isEqual:NSBundle.mainBundle
                        .infoDictionary[@"CFBundleShortVersionString"]] &&
        [args[@"native_build"]
            isEqual:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
    if (!correct) {
      [self fail:result code:@"bootstrap_identity"];
      return;
    }
    result(nil);
    return;
  }
  NSString *archive = args[@"archive"], *extracted = args[@"extracted"];
  NSDictionary *artifact = args[@"artifact"];
  if (![archive isKindOfClass:NSString.class] ||
      ![extracted isKindOfClass:NSString.class] ||
      ![artifact isKindOfClass:NSDictionary.class] ||
      ![self ownedPath:archive] || ![self ownedPath:extracted] ||
      ![artifact[@"package_id"] isEqual:NSBundle.mainBundle.bundleIdentifier] ||
      ![self capable]) {
    [self fail:result code:@"installation_location"];
    return;
  }
  if ([call.method isEqualToString:@"stage"]) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      NSURL *app = [NSURL
          fileURLWithPath:
              [extracted stringByAppendingPathComponent:@"BOOHTACORD.app"]];
      NSBundle *bundle = [NSBundle bundleWithURL:app];
      BOOL identity =
          [bundle.bundleIdentifier isEqual:artifact[@"package_id"]] &&
          [bundle.infoDictionary[@"CFBundleVersion"]
              isEqual:artifact[@"native_build"]] &&
          [bundle.infoDictionary[@"CFBundleShortVersionString"]
              isEqual:artifact[@"version"]];
      SecStaticCodeRef code = NULL;
      OSStatus status =
          identity ? SecStaticCodeCreateWithPath((__bridge CFURLRef)app,
                                                 kSecCSDefaultFlags, &code)
                   : errSecCSBadBundleFormat;
      if (status == errSecSuccess)
        status = SecStaticCodeCheckValidity(code,
                                            kSecCSCheckAllArchitectures |
                                                kSecCSCheckNestedCode |
                                                kSecCSStrictValidate,
                                            NULL);
      if (code)
        CFRelease(code);
      dispatch_async(dispatch_get_main_queue(), ^{
        if (status != errSecSuccess) {
          [self fail:result code:@"bundle_signature"];
          return;
        }
        result(nil);
      });
    });
    return;
  }
  if ([call.method isEqualToString:@"apply"]) {
    // No updater/XPC installer exists before this explicitly consented call.
    if (self.updater.sessionInProgress) {
      [self fail:result code:@"apply_busy"];
      return;
    }
    self.expectedBuild = artifact[@"native_build"];
    NSURL *feedURL = [NSURL URLWithString:args[@"feed_url"] ?: @""];
    NSURL *archiveURL = [NSURL URLWithString:args[@"archive_url"] ?: @""];
    if (![feedURL.scheme isEqual:@"http"] ||
        ![archiveURL.scheme isEqual:@"http"] ||
        ![feedURL.host isEqual:@"127.0.0.1"] ||
        ![archiveURL.host isEqual:@"127.0.0.1"] ||
        ![feedURL.port isEqual:archiveURL.port] || feedURL.user ||
        archiveURL.user || feedURL.query || archiveURL.query) {
      [self fail:result code:@"local_transport"];
      return;
    }
    self.expectedURL = archiveURL.absoluteString;
    NSString *nativeSignature = artifact[@"native_signature"];
    NSData *sig = [[NSData alloc] initWithBase64EncodedString:nativeSignature
                                                      options:0];
    if (sig.length != 64) {
      [self fail:result code:@"native_signature"];
      return;
    }
    self.feed = feedURL;
    self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle
                                        applicationBundle:NSBundle.mainBundle
                                               userDriver:self
                                                 delegate:self];
    self.updater.automaticallyChecksForUpdates = NO;
    self.updater.automaticallyDownloadsUpdates = NO;
    NSError *error = nil;
    if (![self.updater startUpdater:&error]) {
      [self fail:result code:@"native_start"];
      return;
    }
    [self.updater checkForUpdates];
    result(nil);
    return;
  }
  result(FlutterMethodNotImplemented);
}
- (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater {
  return self.feed.absoluteString;
}
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:
    (SPUUpdater *)updater {
  return NO;
}
- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast
                                 forUpdater:(SPUUpdater *)updater {
  for (SUAppcastItem *item in appcast.items)
    if ([item.versionString isEqual:self.expectedBuild] &&
        [item.fileURL.absoluteString isEqual:self.expectedURL])
      return item;
  return nil;
}
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request
                              reply:(void (^)(SUUpdatePermissionResponse *))
                                        reply {
  reply([[SUUpdatePermissionResponse alloc] initWithAutomaticUpdateChecks:NO
                                                        sendSystemProfile:NO]);
}
- (void)showUserInitiatedUpdateCheckWithCancellation:
    (void (^)(void))cancellation {
}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item
                                 state:(SPUUserUpdateState *)state
                                 reply:(void (^)(SPUUserUpdateChoice))reply {
  reply(SPUUserUpdateChoiceInstall);
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {
}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error {
}
- (void)showUpdateNotFoundWithError:(NSError *)error
                    acknowledgement:(void (^)(void))ack {
  ack();
  [self error];
}
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack {
  ack();
  [self error];
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation {
}
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {
}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {
}
- (void)showDownloadDidStartExtractingUpdate {
}
- (void)showExtractionReceivedProgress:(double)progress {
}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply {
  reply(SPUUserUpdateChoiceInstall);
}
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated
                          retryTerminatingApplication:(void (^)(void))retry {
}
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched
                         acknowledgement:(void (^)(void))ack {
  ack();
}
- (void)dismissUpdateInstallation {
}
- (void)showUpdateInFocus {
}
- (void)error {
  [self.channel invokeMethod:@"failed"
                   arguments:@{@"reason" : @"native_apply"}];
}
@end

void RegisterDesktopUpdates(FlutterViewController *controller) {
  BOOHDesktopUpdates *bridge = [BOOHDesktopUpdates new];
  bridge.channel = [FlutterMethodChannel
      methodChannelWithName:@"boohtacord/desktop_updates"
            binaryMessenger:controller.engine.binaryMessenger];
  static char registration;
  objc_setAssociatedObject(controller, &registration, bridge,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  __weak BOOHDesktopUpdates *weakBridge = bridge;
  [bridge.channel
      setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        [weakBridge handle:call result:result];
      }];
}
