#import <Foundation/Foundation.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>

static NSDictionary *ReadRecoveryRecord(NSString *file) {
  NSData *data = [NSData dataWithContentsOfFile:file];
  if (!data || data.length > 65536) return nil;
  id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL RecoveryPlanName(NSString *name) {
  if ([name isEqual:@"plan.json"]) return YES;
  if (![name hasPrefix:@"plan-"] || ![name hasSuffix:@".json"] || name.length != 46)
    return NO;
  return [[NSUUID alloc] initWithUUIDString:[name substringWithRange:NSMakeRange(5, 36)]] != nil;
}

// Keep the lock inode across retries: a delayed old monitor must contend with
// the new monitor, even if it already opened this file before cleanup began.
// No outcome or bootstrap acknowledgement is invented by this operation.
static BOOL ResetInactiveRecovery(NSString *root) {
  NSFileManager *files = NSFileManager.defaultManager;
  int descriptor = open([[root stringByAppendingPathComponent:@"recovery.lock"] fileSystemRepresentation],
                        O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0600);
  if (descriptor < 0) return NO;
  if (flock(descriptor, LOCK_EX | LOCK_NB) != 0) { close(descriptor); return NO; }
  BOOL success = NO;
  @try {
    NSArray<NSString *> *names = [files contentsOfDirectoryAtPath:root error:nil];
    if (!names) return NO;
    NSString *transaction = nil;
    NSDictionary *cancel = ReadRecoveryRecord([root stringByAppendingPathComponent:@"cancel.json"]);
    NSDictionary *outcome = ReadRecoveryRecord([root stringByAppendingPathComponent:@"recovery-outcome.json"]);
    for (NSString *name in names) {
      if (!RecoveryPlanName(name)) continue;
      NSDictionary *plan = ReadRecoveryRecord([root stringByAppendingPathComponent:name]);
      NSString *identifier = plan[@"transaction"];
      if (![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:identifier]) return NO;
      BOOL cancelled = [cancel[@"transaction"] isEqual:identifier];
      BOOL finished = [outcome[@"transaction"] isEqual:identifier] &&
          [@[@"completed", @"rolledBack", @"manualRecovery", @"cancelled"] containsObject:outcome[@"status"] ?: @""];
      if (!cancelled && !finished) return NO;
      if (transaction && ![transaction isEqual:identifier]) return NO;
      transaction = identifier;
    }
    NSMutableArray<NSString *> *retire = [NSMutableArray new];
    for (NSString *name in names)
      if (![name isEqual:@"recovery.lock"] && ![name isEqual:@"retired"]) [retire addObject:name];
    if (retire.count == 0) return YES;
    NSString *history = [root stringByAppendingPathComponent:@"retired"];
    struct stat attributes;
    if (lstat(history.fileSystemRepresentation, &attributes) == 0 && !S_ISDIR(attributes.st_mode)) return NO;
    NSString *destination = [history stringByAppendingPathComponent:transaction ?: NSUUID.UUID.UUIDString];
    struct stat destinationAttributes;
    if (lstat(destination.fileSystemRepresentation, &destinationAttributes) == 0) {
      if (!S_ISDIR(destinationAttributes.st_mode)) return NO;
    } else if (![files createDirectoryAtPath:destination withIntermediateDirectories:YES
                                 attributes:@{NSFilePosixPermissions:@0700} error:nil]) return NO;
    for (NSString *name in retire)
      if (![files moveItemAtPath:[root stringByAppendingPathComponent:name]
                         toPath:[destination stringByAppendingPathComponent:name] error:nil]) return NO;
    // Only retired, quiescent attempts live here; retain a small bounded history.
    NSArray<NSString *> *old = [[files contentsOfDirectoryAtPath:history error:nil]
        sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
          NSDate *left = [files attributesOfItemAtPath:[history stringByAppendingPathComponent:a] error:nil][NSFileModificationDate];
          NSDate *right = [files attributesOfItemAtPath:[history stringByAppendingPathComponent:b] error:nil][NSFileModificationDate];
          return [right compare:left];
        }];
    for (NSUInteger i = 3; i < old.count; i++)
      if ([[NSUUID alloc] initWithUUIDString:old[i]])
        [files removeItemAtPath:[history stringByAppendingPathComponent:old[i]] error:nil];
    success = YES;
  } @finally {
    flock(descriptor, LOCK_UN);
    close(descriptor);
  }
  return success;
}
