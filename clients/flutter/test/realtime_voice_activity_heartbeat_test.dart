import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/voice_activity_heartbeat.dart';

void main() {
  testWidgets(
    'reports periodically only while the local participant is speaking',
    (tester) async {
      var speaking = false;
      var reports = 0;
      final heartbeat = VoiceActivityHeartbeat(
        isSpeaking: () => speaking,
        reportActivity: () => reports++,
      );
      addTearDown(heartbeat.stop);
      heartbeat.start();

      await tester.pump(const Duration(seconds: 20));
      expect(reports, 0);

      speaking = true;
      await tester.pump(const Duration(seconds: 30));
      expect(reports, 6);

      speaking = false;
      await tester.pump(const Duration(seconds: 20));
      expect(reports, 6);

      heartbeat.stop();
      await tester.pump(const Duration(seconds: 20));
      expect(reports, 6);
    },
  );
}
