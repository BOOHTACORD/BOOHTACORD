import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/legacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unowned device OFF requires a choice for each account and deployment',
    () async {
      SharedPreferences.setMockInitialValues({
        'voice-room-event-sounds:v1': false,
      });
      final review = LegacySoundReview();
      await review.select('https://one.test/api/v1', 'a');
      expect(review.blocked, true);
      await review.acknowledge();
      await review.select('https://one.test/api/v1', 'b');
      expect(review.blocked, true);
      await review.select('https://two.test/api/v1', 'a');
      expect(review.blocked, true);
      await review.select('https://one.test/api/v1', 'a');
      expect(review.blocked, false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'voice-room-event-sounds:v1',
        ),
        false,
      );
    },
  );
}
