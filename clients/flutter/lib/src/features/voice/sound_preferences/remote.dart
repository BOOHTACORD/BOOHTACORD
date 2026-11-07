import 'schema.dart';

class VoiceSoundPreferenceConflict implements Exception {
  const VoiceSoundPreferenceConflict();
}

abstract interface class VoiceSoundRemote {
  Future<VoiceSoundSnapshot> load();
  Future<VoiceSoundSnapshot> patch(int revision, Map<String, dynamic> change);
}
