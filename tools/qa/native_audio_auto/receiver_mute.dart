import 'dart:async';

class ReceiverMute<T> {
  ReceiverMute(this.mute);
  final Future<void> Function(T) mute;
  final ready = Completer<void>();
  bool failed = false;

  Future<void> apply(T track) async {
    try {
      await mute(track);
      if (!ready.isCompleted) ready.complete();
    } catch (error, stack) {
      failed = true;
      if (!ready.isCompleted) ready.completeError(error, stack);
    }
  }
}
