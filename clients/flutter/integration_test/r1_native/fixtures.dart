import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/types.dart';
import 'package:boohtacord_desktop/src/models.dart';

import 'harness.dart';
import 'metrics.dart';

extension R1Fixtures on R1Harness {
  Future<void> fixtures() async {
    await real(() async {
      await api.createCategory('Native R1');
      final category = (await api.topology()).categories.firstWhere(
        (c) => c.name == 'Native R1',
      );
      categoryId = category.id;
      await api.createChannel(
        categoryId: category.id,
        name: 'Native R1 Voice',
        kind: ChannelKind.voice,
      );
      await api.createChannel(
        categoryId: category.id,
        name: 'Native R1 Text',
        kind: ChannelKind.text,
      );
      await app.workspace.refreshTopology();
    });
    await wait(
      () => hasChannel('Native R1 Voice') && hasChannel('Native R1 Text'),
    );
    await real(() async {
      final channels = app.topology!.categories.expand((c) => c.channels);
      voice = channels.firstWhere((c) => c.name == 'Native R1 Voice');
      text = channels.firstWhere((c) => c.name == 'Native R1 Text');
      await app.workspace.selectChannel(voice);
    });
    await joinPeer();
    await wait(() => fresh && participants == 1);
    await capture('populated');
  }

  Future<void> joinPeer() async {
    await realPeer(() => peer.joinVoice(voice, listenerOnly: true));
    await wait(
      () => peer.voicePhase == VoicePhase.listener && peer.room != null,
    );
  }

  Future<void> addFreshChannel(String name) async {
    await real(() async {
      await api.createChannel(
        categoryId: categoryId,
        name: name,
        kind: ChannelKind.text,
      );
    });
  }

  Future<void> steady() async {
    var server = await authenticatedConnections();
    for (var i = 0; i < 20 && server != 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      server = await authenticatedConnections();
    }
    debugPrint(
      'R1_STEADY_NATIVE=${api.sockets.where((s) => s.readyState == 1).length} SERVER=$server',
    );
    // Cancelled Dart stream objects may retain OPEN; measure actual server peers.
    expect(server, 2);
    expect(api.sockets.contains(app.realtime.socket), isTrue);
    (report.putIfAbsent(
      'authenticated_connection_samples',
      () => <int>[],
    ) as List<int>).add(server);
    expect(api.legacyRequests, 0);
    expect(peerApi.legacyRequests, 0);
    expect(tester.takeException(), isNull);
  }
}
