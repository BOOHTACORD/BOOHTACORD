enum UpdateResult {
  identityUnknown,
  checkUnavailable,
  noPublishedTarget,
  unsupportedEnvironment,
  identityConflict,
  upToDate,
  updateAvailable,
  currentAhead,
}

enum UpdatePolicyState { published, unconfigured, disabled }

extension UpdateResultWire on UpdateResult {
  String get wireName => switch (this) {
    UpdateResult.identityUnknown => 'identity_unknown',
    UpdateResult.checkUnavailable => 'check_unavailable',
    UpdateResult.noPublishedTarget => 'no_published_target',
    UpdateResult.unsupportedEnvironment => 'unsupported_environment',
    UpdateResult.identityConflict => 'identity_conflict',
    UpdateResult.upToDate => 'up_to_date',
    UpdateResult.updateAvailable => 'update_available',
    UpdateResult.currentAhead => 'current_ahead',
  };
}
