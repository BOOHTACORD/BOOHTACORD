class SoundBurstLimit {
  final List<int> _played = [];
  bool allow(int now) {
    _played.removeWhere((time) => time <= now - 5000);
    if (_played.length >= 3) return false;
    _played.add(now);
    return true;
  }
}
