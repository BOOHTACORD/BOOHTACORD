// SoLoud is process-wide. A cue and the local speaker test must not take over
// or deinitialize one another's engine while native initialization is pending.
class SoundEngineLease {
  static Object? _owner;
  static void Function()? acquire() {
    if (_owner != null) return null;
    final owner = Object();
    _owner = owner;
    return () {
      if (identical(_owner, owner)) _owner = null;
    };
  }
}
