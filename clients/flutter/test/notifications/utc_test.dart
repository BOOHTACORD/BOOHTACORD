import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/notifications/remote_payload/utc.dart';

void main() {
  test(
    'strict UTC rejects normalized invalid calendar dates and non UTC aliases',
    () {
      expect(notificationUtc('2028-02-29T12:01:02.123456789Z'), isNotNull);
      for (final value in [
        '2026-02-29T12:01:02Z',
        '2026-04-31T12:01:02Z',
        '2026-01-01T25:00:00Z',
        '2026-01-01',
        '2026-01-01T00:00:00+01:00',
        '0000-01-01T00:00:00Z',
      ]) {
        expect(notificationUtc(value), isNull, reason: value);
      }
    },
  );
}
