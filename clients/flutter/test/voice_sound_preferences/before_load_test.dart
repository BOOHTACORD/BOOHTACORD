import 'package:boohtacord_desktop/src/features/voice/sound_preferences/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controller_test.dart' show FakeRemote;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'an OFF chosen before loading persists through a later server ON',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedSoundFenceStorage();
      final controller = VoiceSoundController(
        FakeRemote(),
        SoundPreferenceFence(storage, 'https://one.example', 'a'),
        () => true,
      );
      await controller.update({'enabled': false});
      expect(controller.unsynchronised, true);
      await controller.load();
      expect(controller.settings['enabled'], false);
      expect(controller.unsynchronised, true);
    },
  );
}
