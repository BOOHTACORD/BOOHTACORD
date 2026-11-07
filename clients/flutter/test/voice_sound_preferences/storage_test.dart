import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('persists safety restrictions through shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SoundPreferenceFence(
      SharedSoundFenceStorage(),
      'https://one.example',
      'a',
    );
    const settings = {
      'enabled': true,
      'joined': true,
      'left': true,
      'started': true,
      'stopped': true,
      'allow_custom': true,
      'volume': 50,
    };
    await first.restrict({'enabled': false}, settings);
    final reopened = SoundPreferenceFence(
      SharedSoundFenceStorage(),
      'https://one.example',
      'a',
    );
    expect((await reopened.apply(settings))['enabled'], false);
  });

  test('serializes simultaneous restrictive updates', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedSoundFenceStorage();
    final fence = SoundPreferenceFence(storage, 'https://one.example', 'a');
    const settings = {
      'enabled': true,
      'joined': true,
      'left': true,
      'started': true,
      'stopped': true,
      'allow_custom': true,
      'volume': 50,
    };
    await Future.wait([
      fence.restrict({'joined': false}, settings),
      fence.restrict({'left': false}, settings),
    ]);
    final reopened = SoundPreferenceFence(storage, 'https://one.example', 'a');
    expect(await reopened.apply(settings), {
      ...settings,
      'joined': false,
      'left': false,
    });
  });

  test(
    'canonicalizes equivalent origins before looking up restrictions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedSoundFenceStorage();
      const settings = {
        'enabled': true,
        'joined': true,
        'left': true,
        'started': true,
        'stopped': true,
        'allow_custom': true,
        'volume': 50,
      };
      await SoundPreferenceFence(
        storage,
        'https://one.example/',
        'a',
      ).restrict({'enabled': false}, settings);
      final same = SoundPreferenceFence(storage, 'https://one.example', 'a');
      expect((await same.apply(settings))['enabled'], false);
    },
  );
}
