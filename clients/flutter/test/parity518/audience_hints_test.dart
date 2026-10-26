import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer_presence/controller.dart';

const owner = '22222222-2222-4222-8222-222222222222';
const account = '33333333-3333-4333-8333-333333333333';
void main() {
  test(
    'hints coalesce into one in-flight refresh plus a latest refresh',
    () async {
      var reads = 0;
      Completer<List<String>>? blocked;
      final snapshots = <List<String>>[];
      final presence = ScreenViewerPresenceController(
        togglePresence: (_, _, _, _) async {},
        clearOwnerAudience: (_, {trackSid}) async {},
        readOwnerAudience: (_) {
          reads++;
          return blocked?.future ?? Future.value([]);
        },
        readViewerAudience: (_, _) async => [],
        onOwnerAudienceChanged: snapshots.add,
        onViewerAudienceChanged: (_) {},
      );
      addTearDown(presence.clear);
      await presence.localTrackPublished(owner, 'TR_test');
      blocked = Completer<List<String>>();
      final a = presence.refreshFromHint(),
          b = presence.refreshFromHint(),
          c = presence.refreshFromHint();
      expect(identical(a, b) && identical(b, c), isTrue);
      expect(reads, 2);
      blocked.complete([account]);
      blocked = null;
      await a;
      expect(reads, 3);
    },
  );
  test(
    'leave/unpublish cannot be undone by a delayed audience response',
    () async {
      Completer<List<String>>? blocked;
      final snapshots = <List<String>>[];
      final presence = ScreenViewerPresenceController(
        togglePresence: (_, _, _, _) async {},
        clearOwnerAudience: (_, {trackSid}) async {},
        readOwnerAudience: (_) => blocked?.future ?? Future.value([account]),
        readViewerAudience: (_, _) async => [],
        onOwnerAudienceChanged: snapshots.add,
        onViewerAudienceChanged: (_) {},
      );
      await presence.localTrackPublished(owner, 'TR_test');
      blocked = Completer<List<String>>();
      final pending = presence.refreshFromHint();
      await presence.localTrackUnpublished(owner, 'TR_test');
      blocked.complete([account]);
      await pending;
      expect(snapshots.last, isEmpty);
      await presence.clear();
    },
  );
}
