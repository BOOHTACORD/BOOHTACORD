import 'package:shared_preferences/shared_preferences.dart';

import 'fence.dart';

class SharedSoundFenceStorage implements SoundFenceStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Could not persist sound preference');
    }
  }
}
