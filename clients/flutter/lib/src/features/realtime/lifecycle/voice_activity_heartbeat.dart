import 'dart:async';

class VoiceActivityHeartbeat {
  VoiceActivityHeartbeat({
    required this.isSpeaking,
    required this.reportActivity,
    this.interval = const Duration(seconds: 5),
  });

  final bool Function() isSpeaking;
  final void Function() reportActivity;
  final Duration interval;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(interval, (_) {
      if (isSpeaking()) reportActivity();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
