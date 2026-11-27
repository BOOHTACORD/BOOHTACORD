import 'package:flutter_test/flutter_test.dart';

Future<T> withResumeFrames<T>(
  Future<T> Function() action, {
  LiveTestWidgetsFlutterBinding? binding,
}) async {
  final current = binding ?? TestWidgetsFlutterBinding.ensureInitialized();
  if (current is! LiveTestWidgetsFlutterBinding) return action();
  final previous = current.framePolicy;
  // Android can withhold window focus until the resumed surface draws. The
  // default test policy drops that frame while runAsync waits for OS resume.
  current.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  try {
    return await action();
  } finally {
    current.framePolicy = previous;
  }
}
