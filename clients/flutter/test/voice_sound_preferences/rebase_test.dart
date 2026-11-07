import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/rebase.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/remote.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/schema.dart';

import 'controller_test.dart' show FakeRemote;

class ConcurrentRemote extends FakeRemote {
  @override
  Future<VoiceSoundSnapshot> patch(
    int expected,
    Map<String, dynamic> change,
  ) async {
    if (expected != revision) throw const VoiceSoundPreferenceConflict();
    return super.patch(expected, change);
  }
}

void main() {
  test(
    'rebases only the chosen fields and preserves another device volume',
    () async {
      final remote = ConcurrentRemote()..revision = 1;
      remote.values['volume'] = 25;
      final result = await saveSoundChange(remote, 0, {
        'joined': false,
      }, () => true);
      expect(result.settings['volume'], 25);
      expect(result.settings['joined'], false);
      expect(result.revision, 2);
    },
  );
  test(
    'does not refresh or retry a conflict after session replacement',
    () async {
      final remote = ConcurrentRemote()..revision = 1;
      await expectLater(
        saveSoundChange(remote, 0, {'joined': false}, () => false),
        throwsA(isA<VoiceSoundPreferenceConflict>()),
      );
      expect(remote.revision, 1);
      expect(remote.values['joined'], true);
    },
  );
}
