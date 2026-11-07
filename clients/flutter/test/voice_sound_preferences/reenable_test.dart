import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaults = <String, dynamic>{
  'enabled': true,
  'joined': true,
  'left': true,
  'started': true,
  'stopped': true,
  'allow_custom': true,
  'volume': 50,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'explicit ON clears stored OFF only after server acknowledgement',
    () async {
      final storage = SharedSoundFenceStorage();
      await SoundPreferenceFence(
        storage,
        'https://one.example',
        'a',
      ).restrict({'enabled': false}, defaults);
      final reopened = SoundPreferenceFence(
        storage,
        'https://one.example',
        'a',
      );
      final receipt = await reopened.restrict({'enabled': true}, defaults);
      expect((await reopened.apply(defaults))['enabled'], false);
      await reopened.acknowledge(receipt);
      expect((await reopened.apply(defaults))['enabled'], true);
    },
  );

  test('older ON acknowledgement cannot undo a newer OFF', () async {
    final fence = SoundPreferenceFence(
      SharedSoundFenceStorage(),
      'https://one.example',
      'a',
    );
    await fence.restrict({'enabled': false}, defaults);
    final enable = await fence.restrict({'enabled': true}, defaults);
    await fence.restrict({'enabled': false}, defaults);
    await fence.acknowledge(enable);
    expect((await fence.apply(defaults))['enabled'], false);
  });
}
