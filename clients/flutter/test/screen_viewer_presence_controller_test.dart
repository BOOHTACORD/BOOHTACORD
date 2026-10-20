import 'dart:async';

import 'package:boohtacord_desktop/src/features/voice/screen_viewer_presence/controller.dart';
import 'package:flutter_test/flutter_test.dart';

const viewerLeaseId = '11111111-1111-4111-8111-111111111111';
const ownerLeaseId = '22222222-2222-4222-8222-222222222222';
const anotherOwnerLeaseId = '44444444-4444-4444-8444-444444444444';
const watcherAccountId = '33333333-3333-4333-8333-333333333333';

void main() {
  test(
    'reports only subscribed tracks and loads their selected audience',
    () async {
      final calls = <(String, String, String, bool)>[];
      final viewerSnapshots = <(String, String)>[];
      final viewerAudienceChanges = <List<String>>[];
      final controller = ScreenViewerPresenceController(
        togglePresence: (viewer, owner, track, watching) async {
          calls.add((viewer, owner, track, watching));
        },
        clearOwnerAudience: (_, {trackSid}) async {},
        readOwnerAudience: (_) async => const [],
        readViewerAudience: (viewer, owner) async {
          viewerSnapshots.add((viewer, owner));
          return [watcherAccountId];
        },
        onViewerAudienceChanged: viewerAudienceChanges.add,
        onOwnerAudienceChanged: (_) {},
      );

      await controller.selectAudience(viewerLeaseId, ownerLeaseId);
      expect(viewerSnapshots, isEmpty);

      await controller.remoteTrackSubscribed(
        viewerLeaseId,
        ownerLeaseId,
        'TR_active',
      );

      expect(calls, [(viewerLeaseId, ownerLeaseId, 'TR_active', true)]);
      expect(viewerSnapshots, [(viewerLeaseId, ownerLeaseId)]);
      expect(viewerAudienceChanges.last, [watcherAccountId]);
      await controller.clear();
    },
  );

  test('stops the old stream and clears its audience on unsubscribe', () async {
    final calls = <(String, String, String, bool)>[];
    final viewerAudienceChanges = <List<String>>[];
    final controller = ScreenViewerPresenceController(
      togglePresence: (viewer, owner, track, watching) async {
        calls.add((viewer, owner, track, watching));
      },
      clearOwnerAudience: (_, {trackSid}) async {},
      readOwnerAudience: (_) async => const [],
      readViewerAudience: (_, _) async => [watcherAccountId],
      onViewerAudienceChanged: viewerAudienceChanges.add,
      onOwnerAudienceChanged: (_) {},
    );

    await controller.selectAudience(viewerLeaseId, ownerLeaseId);
    await controller.remoteTrackSubscribed(
      viewerLeaseId,
      ownerLeaseId,
      'TR_old',
    );
    await controller.remoteTrackUnsubscribed(ownerLeaseId, 'TR_old');

    expect(calls, [
      (viewerLeaseId, ownerLeaseId, 'TR_old', true),
      (viewerLeaseId, ownerLeaseId, 'TR_old', false),
    ]);
    expect(viewerAudienceChanges.last, isEmpty);
    await controller.clear();
  });

  test(
    'reads the publisher audience and clears it when the local stream ends',
    () async {
      final readOwners = <String>[];
      final clearedOwners = <(String, String?)>[];
      final ownerAudienceChanges = <List<String>>[];
      final controller = ScreenViewerPresenceController(
        togglePresence: (_, _, _, _) async {},
        clearOwnerAudience: (owner, {trackSid}) async {
          clearedOwners.add((owner, trackSid));
        },
        readOwnerAudience: (owner) async {
          readOwners.add(owner);
          return [watcherAccountId];
        },
        readViewerAudience: (_, _) async => const [],
        onViewerAudienceChanged: (_) {},
        onOwnerAudienceChanged: ownerAudienceChanges.add,
      );

      await controller.localTrackPublished(ownerLeaseId, 'TR_local');
      expect(readOwners, [ownerLeaseId]);
      expect(ownerAudienceChanges.last, [watcherAccountId]);

      await controller.localTrackUnpublished(ownerLeaseId, 'TR_local');
      expect(clearedOwners, [(ownerLeaseId, 'TR_local')]);
      expect(ownerAudienceChanges.last, isEmpty);
      await controller.clear();
    },
  );

  test('ignores a stale viewer snapshot after switching streams', () async {
    final staleSnapshot = Completer<List<String>>();
    final viewerAudienceChanges = <List<String>>[];
    final controller = ScreenViewerPresenceController(
      togglePresence: (_, _, _, _) async {},
      clearOwnerAudience: (_, {trackSid}) async {},
      readOwnerAudience: (_) async => const [],
      readViewerAudience: (_, owner) => owner == ownerLeaseId
          ? staleSnapshot.future
          : Future.value([watcherAccountId]),
      onViewerAudienceChanged: viewerAudienceChanges.add,
      onOwnerAudienceChanged: (_) {},
    );

    await controller.selectAudience(viewerLeaseId, ownerLeaseId);
    final oldSubscription = controller.remoteTrackSubscribed(
      viewerLeaseId,
      ownerLeaseId,
      'TR_old',
    );
    await controller.selectAudience(viewerLeaseId, anotherOwnerLeaseId);
    await controller.remoteTrackSubscribed(
      viewerLeaseId,
      anotherOwnerLeaseId,
      'TR_new',
    );
    staleSnapshot.complete(const ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']);
    await oldSubscription;

    expect(viewerAudienceChanges.last, [watcherAccountId]);
    await controller.clear();
  });
}
