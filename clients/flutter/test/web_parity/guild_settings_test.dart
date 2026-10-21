import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  test(
    'clean save is inert, editing and cancel restore confirmed baseline',
    () async {
      var writes = 0;
      final c = GuildSettingsController(
        () async => const GuildSettings('База', 1, null),
        (name, welcome, revision) async {
          writes++;
          return GuildSettings(name, 2, welcome);
        },
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.dirty, false);
      await c.save([]);
      expect(writes, 0);
      c.name = 'Черновик';
      expect(c.dirty, true);
      c.cancel();
      expect(c.name, 'База');
      expect(c.dirty, false);
      expect(writes, 0);
      c.name = 'Новое';
      await c.save([]);
      expect(c.saved, true);
      expect(c.dirty, false);
      c.name = 'Ещё правка';
      c.cancel();
      expect(c.name, 'Новое');
    },
  );

  test(
    '409 keeps draft and Cancel uses latest confirmed server values',
    () async {
      var reads = 0, writes = 0;
      final c = GuildSettingsController(
        () async =>
            GuildSettings(++reads == 1 ? 'База' : 'Другая база', reads, null),
        (_, _, _) async {
          writes++;
          throw ApiFailure('conflict', status: 409);
        },
      );
      addTearDown(c.dispose);
      await c.load();
      c.name = 'Мой черновик';
      await c.save([]);
      expect(c.name, 'Мой черновик');
      expect(c.revision, 2);
      expect(c.conflict, true);
      expect(writes, 1);
      c.name = 'Исправленный черновик';
      expect(c.conflict, true);
      c.cancel();
      expect(c.name, 'Другая база');
      expect(c.conflict, false);
      expect(c.dirty, false);
      expect(writes, 1);
    },
  );

  test('pending mutation blocks repeated submit, reload and cancel', () async {
    final pending = Completer<GuildSettings>();
    var reads = 0, writes = 0;
    final c = GuildSettingsController(
      () async {
        reads++;
        return const GuildSettings('База', 1, null);
      },
      (_, _, _) {
        writes++;
        return pending.future;
      },
    );
    addTearDown(c.dispose);
    await c.load();
    c.name = 'Новое';
    final saving = c.save([]);
    await c.save([]);
    await c.load();
    c.cancel();
    expect(reads, 1);
    expect(writes, 1);
    expect(c.name, 'Новое');
    pending.complete(const GuildSettings('Новое', 2, null));
    await saving;
    expect(c.dirty, false);
  });
  test(
    'validation and failed requests preserve draft without writing on cancel',
    () async {
      var writes = 0;
      final c = GuildSettingsController(
        () async => const GuildSettings('База', 1, null),
        (_, _, _) async {
          writes++;
          throw const ApiFailure('unavailable', status: 503);
        },
      );
      addTearDown(c.dispose);
      await c.load();
      c.name = 'bad\nname';
      await c.save([]);
      expect(c.error, contains('Название'));
      expect(writes, 0);
      c.name = 'Правка';
      c.welcome = 'unavailable';
      await c.save([]);
      expect(writes, 0);
      c.welcome = null;
      await c.save([]);
      expect(writes, 1);
      expect(c.name, 'Правка');
      expect(c.dirty, isTrue);
      c.cancel();
      expect(c.name, 'База');
      expect(c.error, isNull);
      expect(writes, 1);
    },
  );
  test(
    'conflict retry is explicit and uses freshly confirmed revision',
    () async {
      var reads = 0;
      final revisions = <int>[];
      final c = GuildSettingsController(
        () async => GuildSettings('База', ++reads, null),
        (name, welcome, revision) async {
          revisions.add(revision);
          if (revisions.length == 1)
            throw const ApiFailure('conflict', status: 409);
          return GuildSettings(name, revision + 1, welcome);
        },
      );
      addTearDown(c.dispose);
      await c.load();
      c.name = 'Правка';
      await c.save([]);
      expect(revisions, [1]);
      expect(c.conflict, isTrue);
      await c.save([]);
      expect(revisions, [1, 2]);
      expect(c.conflict, isFalse);
      expect(c.dirty, isFalse);
    },
  );
  test(
    'late read and mutation responses after disposal do not notify',
    () async {
      for (final saving in [false, true]) {
        final pending = Completer<GuildSettings>();
        var calls = 0;
        final c = GuildSettingsController(
          () => saving
              ? Future.value(const GuildSettings('База', 1, null))
              : pending.future,
          (_, _, _) => pending.future,
        );
        c.addListener(() => calls++);
        Future<void> operation;
        if (saving) {
          await c.load();
          c.name = 'Правка';
          operation = c.save([]);
        } else {
          operation = c.load();
        }
        c.dispose();
        final before = calls;
        pending.complete(const GuildSettings('Поздний ответ', 2, null));
        await operation;
        expect(calls, before);
      }
    },
  );
}
