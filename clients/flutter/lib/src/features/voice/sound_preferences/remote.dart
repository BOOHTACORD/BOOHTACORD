import 'schema.dart';

abstract interface class VoiceSoundRemote {
  Future<VoiceSoundSnapshot> load();
  Future<VoiceSoundSnapshot> patch(int revision, Map<String, dynamic> change);
}
