import 'fence.dart';

Map<String, dynamic> mutedSoundSettings() => {
  'enabled': false,
  'joined': false,
  'left': false,
  'started': false,
  'stopped': false,
  'allow_custom': false,
  'volume': 0,
};

Future<void> preserveBeforeLoad(
  SoundPreferenceFence fence,
  Map<String, dynamic> change,
) async {
  try {
    await fence.restrict(change, {'volume': 100});
  } catch (_) {
    // The controller remains muted and marks the change unsynchronised.
  }
}
