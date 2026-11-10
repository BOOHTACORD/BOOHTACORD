import 'controller.dart';

extension VoiceRosterRetry on VoiceRosterController {
  void retryVoiceRosters() {
    if (canRetry) onSharedRetry?.call();
  }
}
