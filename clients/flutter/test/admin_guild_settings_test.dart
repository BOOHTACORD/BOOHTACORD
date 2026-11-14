import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/presentation/view.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  test(
    'conflict preserves drafts and reloads revision before explicit retry',
    () async {
      var reads = 0, writes = 0;
      final state = GuildSettingsController(
        () async => GuildSettings('Другой', ++reads, null),
        (name, channel, revision) async {
          writes++;
          if (writes == 1) throw ApiFailure('conflict', status: 409);
          expect(revision, 2);
          return GuildSettings(name, 3, channel);
        },
      );
      await state.load();
      state.name = 'Черновик';
      await state.save([]);
      expect(state.name, 'Черновик');
      expect(state.revision, 2);
      expect(writes, 1);
      await state.save([]);
      expect(state.saved, true);
      state.dispose();
    },
  );
  test('unavailable welcome channel rejects before mutation', () async {
    var writes = 0;
    final state = GuildSettingsController(
      () async => const GuildSettings('Имя', 1, null),
      (name, channel, revision) async {
        writes++;
        return GuildSettings(name, 2, channel);
      },
    );
    await state.load();
    state.welcome = 'archived';
    await state.save([]);
    expect(writes, 0);
    expect(state.error, contains('канал'));
    state.dispose();
  });

  test(
    'selecting an AFK channel defaults to five minutes and saves both values',
    () async {
      String? savedChannel;
      var savedTimeout = 0;
      final state = GuildSettingsController(
        () async => const GuildSettings('Имя', 1, null),
        (name, channel, revision) async =>
            GuildSettings(name, revision + 1, channel),
        writeAfk: (name, welcome, revision, channel, timeout) async {
          savedChannel = channel;
          savedTimeout = timeout;
          return GuildSettings(
            name,
            revision + 1,
            welcome,
            afkChannelID: channel,
            afkTimeoutSeconds: timeout,
          );
        },
      );
      await state.load();
      state.afkChannel = 'afk-voice';
      expect(state.afkTimeout, 300);
      await state.save([], ['afk-voice']);
      expect(savedChannel, 'afk-voice');
      expect(savedTimeout, 300);
      expect(state.saved, isTrue);
      state.dispose();
    },
  );

  test(
    'AFK routing rejects channels outside the available voice list',
    () async {
      var writes = 0;
      final state = GuildSettingsController(
        () async => const GuildSettings('Имя', 1, null),
        (name, channel, revision) async {
          writes++;
          return GuildSettings(name, revision + 1, channel);
        },
        writeAfk: (name, welcome, revision, channel, timeout) async {
          writes++;
          return GuildSettings(name, revision + 1, welcome);
        },
      );
      await state.load();
      state.afkChannel = 'archived';
      await state.save([], []);
      expect(writes, 0);
      expect(state.error, contains('AFK'));
      state.dispose();
    },
  );

  testWidgets('AFK timeout explains that a channel must be selected first', (
    tester,
  ) async {
    final state = GuildSettingsController(
      () async => const GuildSettings('Имя', 1, null),
      (name, channel, revision) async =>
          GuildSettings(name, revision + 1, channel),
    );
    await state.load();
    final name = TextEditingController(text: state.name);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuildSettingsPresentation(
            state: state,
            name: name,
            channels: const [],
            voiceChannels: const [],
            onSave: () {},
            onLoad: () {},
            onWelcomeChanged: (_) {},
            onAfkChannelChanged: (_) {},
            onAfkTimeoutChanged: (_) {},
            onCancel: () {},
            onNameChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Сначала выберите AFK-канал'), findsOneWidget);
    expect(
      find.text(
        'Таймер сбрасывают действия в BOOHTACORD и активная речь в голосе. В AFK-канале микрофон будет выключен.',
      ),
      findsOneWidget,
    );
    expect(find.text('5 мин.'), findsNothing);
    final timeout = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(ValueKey('afk-timeout:${state.revision}:0')),
    );
    expect(timeout.onChanged, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    name.dispose();
    state.dispose();
  });
}
