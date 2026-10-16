#import <Cocoa/Cocoa.h>
#import "macos_state.h"

// NSWorkspace discards launch arguments from a sandboxed caller. A document
// handoff grants the helper access to this one local transaction directory.
static void StopRecoveryDocumentWait(NSApplication *application) {
  [application stop:nil];
  [application postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
      location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
      context:nil subtype:0 data1:0 data2:0] atStart:NO];
}

@interface RecoveryDocumentHandoff : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSURL *directory;
@property(nonatomic) BOOL received;
@property(nonatomic) BOOL accessing;
@end

@implementation RecoveryDocumentHandoff
- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
  if (self.received) return;
  self.received = YES;
  if (urls.count == 1 && urls.firstObject.isFileURL) {
    self.directory = urls.firstObject;
    self.accessing = [self.directory startAccessingSecurityScopedResource];
  }
  StopRecoveryDocumentWait(application);
}
- (void)dealloc {
  if (_accessing) [_directory stopAccessingSecurityScopedResource];
}
@end

static NSString *RecoveryDocumentPlan(NSURL *directory, NSString *home,
                                      NSString **transaction) {
  NSString *root = directory.path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
  if (![root hasPrefix:[home stringByAppendingString:@"/"]] ||
      ![root containsString:@"/DesktopUpdates/"] ||
      ![root.lastPathComponent isEqual:@"recovery"]) return nil;
  NSDictionary *request = ReadRecoveryRecord([root stringByAppendingPathComponent:@"launch.json"]);
  NSString *identifier = request[@"transaction"], *name = request[@"plan"];
  if (![request[@"schema_version"] isEqual:@1] ||
      ![identifier isKindOfClass:NSString.class] ||
      ![[NSUUID alloc] initWithUUIDString:identifier] ||
      ![name isKindOfClass:NSString.class] || !RecoveryPlanName(name)) return nil;
  NSString *plan = [root stringByAppendingPathComponent:name];
  if (![ReadRecoveryRecord(plan)[@"transaction"] isEqual:identifier]) return nil;
  *transaction = identifier;
  return plan;
}
