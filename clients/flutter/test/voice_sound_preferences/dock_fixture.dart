import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/remote.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/schema.dart';

class DockSoundRemote implements VoiceSoundRemote {
  int revision = 0;
  final settings = <String, dynamic>{
    for (final key in soundFlags) key: true,
    'volume': 50,
  };
  @override
  Future<VoiceSoundSnapshot> load() async => VoiceSoundSnapshot.parse({
    'revision': revision,
    'settings': Map.of(settings),
  });
  @override
  Future<VoiceSoundSnapshot> patch(
    int expected,
    Map<String, dynamic> change,
  ) async {
    if (expected != revision) throw StateError('stale revision');
    settings.addAll(change);
    revision++;
    return load();
  }
}

class _Storage implements SoundFenceStorage {
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String next) async {
    value = next;
  }
}

Future<DockSoundRemote> installDockSoundPreferences(AppState state) async {
  final remote = DockSoundRemote();
  state.voice.sounds.preferences?.dispose();
  final controller = VoiceSoundController(
    remote,
    SoundPreferenceFence(_Storage(), 'https://qa.invalid', 'account-1'),
    () => true,
  );
  state.voice.sounds.preferences = controller;
  controller.addListener(state.notifyListeners);
  await controller.load();
  return remote;
}
