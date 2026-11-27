import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../test_support/app_resume_frames.dart';

class Frames extends Fake implements LiveTestWidgetsFlutterBinding {
  @override
  LiveTestWidgetsFlutterBindingFramePolicy framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
}

void main() {
  test(
    'resume wait renders unsolicited frames and restores caller policy',
    () async {
      final binding = Frames();
      final result = await withResumeFrames(() async {
        expect(
          binding.framePolicy,
          LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
        );
        return 'resumed';
      }, binding: binding);
      expect(result, 'resumed');
      expect(
        binding.framePolicy,
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
      );
    },
  );

  test('failed resume cannot leave the caller in live frame mode', () async {
    final binding = Frames();
    await expectLater(
      withResumeFrames(() async {
        expect(
          binding.framePolicy,
          LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
        );
        throw TimeoutException('No OS resume observed');
      }, binding: binding),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      binding.framePolicy,
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
    );
  });
}
