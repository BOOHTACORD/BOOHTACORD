import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('captures pending changes before the caller mutates its map', () async {
    SharedPreferences.setMockInitialValues({});
    final fence = SoundPreferenceFence(
      SharedSoundFenceStorage(),
      'https://one.example',
      'a',
    );
    final settings = <String, dynamic>{
      'enabled': true,
      'joined': true,
      'left': true,
      'started': true,
      'stopped': true,
      'allow_custom': true,
      'volume': 50,
    };
    final changes = <String, dynamic>{'enabled': false};
    final pending = fence.restrict(changes, settings);
    changes['enabled'] = true;
    await pending;
    expect((await fence.apply(settings))['enabled'], false);
  });
}
