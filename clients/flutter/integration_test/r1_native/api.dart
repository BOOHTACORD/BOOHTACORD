import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import '../guarded_http.dart';

class HeldRead {
  final reached = Completer<void>(), release = Completer<void>();
  Future<void> hold() async {
    reached.complete();
    await release.future.timeout(const Duration(minutes: 3));
  }

  void finish() {
    if (!release.isCompleted) release.complete();
  }
}

// Only delay unchanged responses from the actual API; never synthesize WS frames.
class NativeR1Api extends ApiClient {
  NativeR1Api() : this._(GuardedHttpClient());
  NativeR1Api._(this.guard) : super(client: guard);
  final GuardedHttpClient guard;
  final sockets = <WebSocket>[], barriers = <HeldRead>[];
  HeldRead? nextTopology, nextHistory;
  bool forceResync = false, durableCursorSent = false;
  int topologyReads = 0, pollingRequests = 0;
  int get legacyRequests => guard.legacyRequests + pollingRequests;
  HeldRead holdTopology() {
    final value = HeldRead();
    barriers.add(value);
    nextTopology = value;
    return value;
  }

  HeldRead holdHistory() {
    final value = HeldRead();
    barriers.add(value);
    nextHistory = value;
    return value;
  }

  @override
  Future<ChannelTopology> topology() async {
    final barrier = nextTopology;
    nextTopology = null;
    final value = await super.topology();
    topologyReads++;
    if (barrier != null) await barrier.hold();
    return value;
  }

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    final barrier = nextHistory;
    nextHistory = null;
    final value = await super.messagePage(channelId, before: before, at: at);
    if (barrier != null) await barrier.hold();
    return value;
  }

  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) async {
    if (forceResync) {
      after = const Uuid().v4();
      forceResync = false;
    } else if (after != null) {
      durableCursorSent = true;
    }
    final value = await super.openRealtime(after: after, client: client);
    sockets.add(value);
    return value;
  }

  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() {
    pollingRequests++;
    throw StateError('Native R1 must not poll legacy voice participants');
  }

  void releaseAll() {
    for (final barrier in barriers) {
      barrier.finish();
    }
  }
}
