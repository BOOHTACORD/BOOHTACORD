String activityCapabilities(
  String base, {
  required bool isWindows,
  bool initialIdle = false,
}) => isWindows
    ? '$base,confirmed_activity_v1${initialIdle ? ',initial_idle_v1' : ''}'
    : base;

bool initialIdleCapability({required bool? locked, required Duration? idle}) =>
    locked != null && idle != null && idle >= const Duration(minutes: 5);
