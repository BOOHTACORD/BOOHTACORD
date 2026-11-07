import 'dart:async';

import 'package:boohtacord_desktop/src/features/voice/sound_preferences/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/fence.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/remote.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/schema.dart';
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
VoiceSoundSnapshot snapshot(int revision, Map<String, dynamic> settings) =>
    VoiceSoundSnapshot.parse({'revision': revision, 'settings': settings});

class FakeRemote implements VoiceSoundRemote {
  Map<String, dynamic> values = {...defaults};
  int revision = 0;
  bool offline = false;
  Completer<VoiceSoundSnapshot>? response;
  @override
  Future<VoiceSoundSnapshot> load() async => snapshot(revision, values);
  @override
  Future<VoiceSoundSnapshot> patch(
    int expected,
    Map<String, dynamic> change,
  ) async {
    if (offline) throw StateError('offline');
    if (response != null) return response!.future;
    values.addAll(change);
    return snapshot(++revision, values);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offline OFF stays quiet and survives a new controller', () async {
    final storage = SharedSoundFenceStorage();
    final remote = FakeRemote();
    final controller = VoiceSoundController(
      remote,
      SoundPreferenceFence(storage, 'https://one.example', 'a'),
      () => true,
    );
    await controller.load();
    remote.offline = true;
    await controller.update({'enabled': false});
    expect(controller.settings['enabled'], false);
    expect(controller.unsynchronised, true);
    final next = VoiceSoundController(
      remote,
      SoundPreferenceFence(storage, 'https://one.example', 'a'),
      () => true,
    );
    await next.load();
    expect(next.settings['enabled'], false);
  });

  test('old account responses cannot update a replaced session', () async {
    var active = true;
    final remote = FakeRemote()..response = Completer<VoiceSoundSnapshot>();
    final controller = VoiceSoundController(
      remote,
      SoundPreferenceFence(
        SharedSoundFenceStorage(),
        'https://one.example',
        'a',
      ),
      () => active,
    );
    await controller.load();
    final pending = controller.update({'joined': false});
    await Future<void>.delayed(Duration.zero);
    active = false;
    remote.response!.complete(snapshot(1, {...defaults, 'joined': false}));
    await pending;
    expect(controller.unsynchronised, true);
  });
}
