import 'remote.dart';
import 'schema.dart';

Future<VoiceSoundSnapshot> saveSoundChange(
  VoiceSoundRemote remote,
  int revision,
  Map<String, dynamic> change,
  bool Function() current,
) async {
  try {
    return await remote.patch(revision, change);
  } on VoiceSoundPreferenceConflict {
    if (!current()) rethrow;
    final latest = await remote.load();
    if (!current() || latest.revision < revision)
      throw StateError('Stale preference refresh');
    return remote.patch(latest.revision, change);
  }
}
