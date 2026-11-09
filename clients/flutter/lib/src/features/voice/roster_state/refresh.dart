import 'controller.dart';

extension VoiceRosterRefresh on VoiceRosterController {
  Future<void> refreshVoiceRosters() async {
    if (disposed || !scope.capture().isActive || !isReady() || !hasUser()) {
      return;
    }
    onSharedRetry?.call();
  }
}
