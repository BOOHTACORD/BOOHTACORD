import 'package:boohtacord_desktop/src/features/screen/metrics/report_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps successful reports on the five-second cadence', () {
    final cadence = ScreenShareReportCadence();
    expect(cadence.isDue(0), isTrue);
    cadence.markAttempt(0);
    cadence.markSuccess(0);
    expect(cadence.lastAttemptAtMs, 0);
    expect(cadence.lastSuccessAtMs, 0);
    expect(cadence.isDue(4999), isFalse);
    expect(cadence.isDue(5000), isTrue);
  });

  test('backs off failed reports without losing attempt and success times', () {
    final cadence = ScreenShareReportCadence();
    expect(cadence.isDue(0), isTrue);
    cadence.markAttempt(0);
    cadence.markFailure(0);
    expect(cadence.lastAttemptAtMs, 0);
    expect(cadence.lastSuccessAtMs, isNull);
    expect(cadence.isDue(1999), isFalse);
    expect(cadence.isDue(2000), isTrue);
    cadence.markAttempt(2000);
    cadence.markFailure(2000);
    expect(cadence.isDue(5999), isFalse);
    expect(cadence.isDue(6000), isTrue);
    cadence.markAttempt(6000);
    cadence.markSuccess(6000);
    expect(cadence.lastSuccessAtMs, 6000);
    expect(cadence.isDue(10999), isFalse);
    expect(cadence.isDue(11000), isTrue);
  });

  test('clears report cadence between sharing generations', () {
    final cadence = ScreenShareReportCadence();
    cadence.markAttempt(0);
    cadence.markFailure(0);
    expect(cadence.isDue(2000), isTrue);
    cadence.clear();
    expect(cadence.lastAttemptAtMs, isNull);
    expect(cadence.lastSuccessAtMs, isNull);
    expect(cadence.isDue(0), isTrue);
  });
}
