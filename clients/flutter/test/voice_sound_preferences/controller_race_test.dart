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
VoiceSoundSnapshot snap(int rev, Map<String, dynamic> settings) =>
    VoiceSoundSnapshot.parse({'revision': rev, 'settings': settings});

class Remote implements VoiceSoundRemote {
  final first = Completer<VoiceSoundSnapshot>();
  final started = Completer<void>();
  final requests = <Map<String, dynamic>>[];
  @override
  Future<VoiceSoundSnapshot> load() async => snap(0, defaults);
  @override
  Future<VoiceSoundSnapshot> patch(int rev, Map<String, dynamic> change) async {
    requests.add({'revision': rev, ...change});
    if (requests.length == 1) {
      started.complete();
      return first.future;
    }
    return snap(2, {...defaults, 'joined': false, 'left': false});
  }
}

class LateLoadRemote extends Remote {
  final lateLoad = Completer<VoiceSoundSnapshot>();
  int loads = 0;
  @override
  Future<VoiceSoundSnapshot> load() async {
    loads++;
    if (loads == 1) return snap(0, defaults);
    return lateLoad.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('serializes rapid updates without unmuting a newer OFF', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = Remote();
    final controller = VoiceSoundController(
      remote,
      SoundPreferenceFence(
        SharedSoundFenceStorage(),
        'https://one.example',
        'a',
      ),
      () => true,
    );
    await controller.load();
    final first = controller.update({'joined': false});
    final second = controller.update({'left': false});
    expect(controller.settings['left'], false);
    await remote.started.future;
    remote.first.complete(snap(1, {...defaults, 'joined': false}));
    await Future.wait([first, second]);
    expect(remote.requests, [
      {'revision': 0, 'joined': false},
      {'revision': 1, 'left': false},
    ]);
    expect(controller.settings['left'], false);
    expect(controller.unsynchronised, false);
  });

  test('ignores a refresh that started before an OFF update', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = LateLoadRemote();
    final controller = VoiceSoundController(
      remote,
      SoundPreferenceFence(
        SharedSoundFenceStorage(),
        'https://one.example',
        'a',
      ),
      () => true,
    );
    await controller.load();
    final refresh = controller.load();
    final pending = controller.update({'joined': false});
    await remote.started.future;
    remote.lateLoad.complete(snap(0, defaults));
    await refresh;
    expect(controller.settings['joined'], false);
    remote.first.complete(snap(1, {...defaults, 'joined': false}));
    await pending;
    expect(controller.settings['joined'], false);
  });
}
