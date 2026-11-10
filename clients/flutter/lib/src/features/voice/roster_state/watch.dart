import 'controller.dart';

extension VoiceRosterWatch on VoiceRosterController {
  void start() {
    if (disposed ||
        !scope.capture().isActive ||
        !hasUser() ||
        !isReady() ||
        watching) {
      return;
    }
    watching = true;
    revision++;
  }
}
