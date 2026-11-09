part of '../../app_state_test.dart';

mixin _FakeIdentity on _FakeApiState {
  @override
  bool get realtimeEnabled => false;

  @override
  Future<PermissionSnapshot> loadPermissions() async => PermissionSnapshot(
    accountId: 'account-1',
    role: GuildRole.member,
    revision: 1,
    values: {for (final permission in GuildPermission.values) permission: true},
  );

  @override
  Future<void> initialize() async => initializationGate?.future;

  @override
  Future<SessionUser?> currentSession() async {
    final failure = sessionFailure;
    if (failure != null) throw failure;
    final gate = sessionGate;
    if (gate != null) return gate.future;
    return const SessionUser(accountId: 'account-1', role: 'MEMBER');
  }

  @override
  Future<OwnProfile> ownProfile() async {
    final failure = profileFailure;
    if (failure != null) throw failure;
    return const OwnProfile(
      accountId: 'account-1',
      login: 'member',
      displayName: 'Участник',
      role: 'MEMBER',
    );
  }

  @override
  Future<OwnProfile> updateOwnProfile(String displayName) async {
    updatedDisplayName = displayName;
    return OwnProfile(
      accountId: 'account-1',
      login: 'member',
      displayName: displayName,
      role: 'MEMBER',
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    passwordChangeRequests++;
  }

  @override
  Future<void> completePasswordReset(String token, String password) async {
    passwordResetCompleted = token.length == 43 && password.isNotEmpty;
  }
}
