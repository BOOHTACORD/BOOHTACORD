import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage implements SoundFenceStorage {
  final values = <String, String>{};
  bool broken = false;
  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('offline');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (broken) throw StateError('offline');
    values[key] = value;
  }
}

void main() {
  const defaults = {
    'enabled': true,
    'joined': true,
    'left': true,
    'started': true,
    'stopped': true,
    'allow_custom': true,
    'volume': 50,
  };

  test(
    'persists restrictions for the same account and deployment only',
    () async {
      final storage = MemoryStorage();
      final first = SoundPreferenceFence(storage, 'https://one.example', 'a');
      await first.restrict({'joined': false, 'volume': 20}, defaults);
      final reopened = SoundPreferenceFence(
        storage,
        'https://one.example',
        'a',
      );
      expect(await reopened.apply(defaults), {
        ...defaults,
        'joined': false,
        'volume': 20,
      });
      expect(
        await SoundPreferenceFence(
          storage,
          'https://one.example',
          'b',
        ).apply(defaults),
        defaults,
      );
      expect(
        await SoundPreferenceFence(
          storage,
          'https://two.example',
          'a',
        ).apply(defaults),
        defaults,
      );
    },
  );

  test('corrupt or unreadable storage fails closed', () async {
    final storage = MemoryStorage();
    final fence = SoundPreferenceFence(storage, 'https://one.example', 'a');
    await fence.restrict({'joined': false}, defaults);
    storage.values.updateAll((_, _) => '{broken');
    expect(
      (await SoundPreferenceFence(
        storage,
        'https://one.example',
        'a',
      ).apply(defaults))['enabled'],
      false,
    );
    storage.broken = true;
    expect(
      (await SoundPreferenceFence(
        storage,
        'https://one.example',
        'b',
      ).apply(defaults))['enabled'],
      false,
    );
  });

  test(
    'acknowledgement cannot clear a more restrictive pending change',
    () async {
      final storage = MemoryStorage();
      final fence = SoundPreferenceFence(storage, 'https://one.example', 'a');
      final first = await fence.restrict({'volume': 30}, defaults);
      await fence.restrict({'volume': 10}, defaults);
      await fence.acknowledge(first);
      expect((await fence.apply(defaults))['volume'], 10);
    },
  );

  test('failed persistence of acknowledgement keeps the local OFF', () async {
    final storage = MemoryStorage();
    final fence = SoundPreferenceFence(storage, 'https://one.example', 'a');
    final receipt = await fence.restrict({'enabled': false}, defaults);
    storage.broken = true;
    await expectLater(fence.acknowledge(receipt), throwsStateError);
    expect((await fence.apply(defaults))['enabled'], false);
  });
}
