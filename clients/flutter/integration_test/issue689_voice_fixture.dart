import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'issue689_support.dart';

Future<GuildChannel> createVoiceFixture(
  WidgetTester tester,
  SocketOnlyApi api,
  AppState app, {
  required String categoryName,
  required String channelName,
}) async {
  await tester.runAsync(() async {
    await api.createCategory(categoryName);
    final topology = await api.topology();
    final category = topology.categories.firstWhere(
      (c) => c.name == categoryName,
    );
    await api.createChannel(
      categoryId: category.id,
      name: channelName,
      kind: ChannelKind.voice,
    );
  });
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.runAsync(app.refreshTopology);
    await tester.pump(const Duration(milliseconds: 250));
    final channels = app.topology?.categories.expand((c) => c.channels) ?? [];
    final matching = channels.where(
      (c) => c.name == channelName && c.kind == ChannelKind.voice,
    );
    if (matching.isNotEmpty) return matching.single;
  }
  throw TestFailure('Owned voice channel did not reach the current topology');
}
