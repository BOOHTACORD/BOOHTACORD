enum PushPermission { granted, provisional, denied, unavailable }

class PushRegistration {
  const PushRegistration(this.permission, this.targetKind, this.target);
  final PushPermission permission;
  final String targetKind, target;
}

class PushUnavailable implements Exception {
  const PushUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'Push unavailable';
}

abstract interface class MobilePushDriver {
  bool get supported;
  String get platform;
  Stream<Map<String, dynamic>> get messages;
  Stream<Map<String, dynamic>> get taps;
  Stream<String> get targets;
  Future<PushRegistration> register({required bool askPermission});
  Future<void> disable({String? binding});
  Future<void> clearCards({String? binding});
  Future<void> dispose();
}
