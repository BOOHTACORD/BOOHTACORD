/// macOS 13+ defaults to ScreenCaptureKit; native code handles older systems.
/// The explicit baseline override remains independent of codec preferences.
String macOSCaptureEngine({String? value}) {
  final selected =
      value ??
      const String.fromEnvironment(
        'BOOHTACORD_MACOS_CAPTURE_ENGINE',
        defaultValue: 'screen_capture_kit',
      );
  if (selected != 'baseline' && selected != 'screen_capture_kit') {
    throw ArgumentError.value(selected, 'captureEngine');
  }
  return selected;
}
