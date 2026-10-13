/// Independent capture rollout; codec preferences are not part of this flag.
String macOSCaptureEngine({String? value}) {
  final selected =
      value ??
      const String.fromEnvironment(
        'BOOHTACORD_MACOS_CAPTURE_ENGINE',
        defaultValue: 'baseline',
      );
  if (selected != 'baseline' && selected != 'screen_capture_kit') {
    throw ArgumentError.value(selected, 'captureEngine');
  }
  return selected;
}
