import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class DelayedHistoryApi extends ApiClient {
  String? heldChannel;
  final held = Completer<void>();
  final release = Completer<void>();
  int completedTopologies = 0;

  @override
  Future<ChannelTopology> topology() async {
    final result = await super.topology();
    completedTopologies++;
    return result;
  }

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    final page = await super.messagePage(channelId, before: before, at: at);
    if (channelId == heldChannel) {
      heldChannel = null;
      held.complete();
      await release.future;
    }
    return page;
  }
}
