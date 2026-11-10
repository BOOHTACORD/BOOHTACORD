part of 'evaluator.dart';

// This is a presentation decision, not a server authorization check.
bool requiresUpdate(
  LocalUpdateIdentity? local,
  UpdatePolicy policy,
  UpdateEnvironment environment,
) {
  if (!_valid(policy) || policy.state != UpdatePolicyState.published) {
    return false;
  }
  final target = policy.target!;
  final minimum = target.minimumReleaseOrder;
  if (minimum == null) return false;
  if (target.expiresAt != null &&
      !target.expiresAt!.isAfter(environment.now ?? DateTime.now().toUtc())) {
    return false;
  }
  if (local == null || local.releaseId.isEmpty || local.releaseOrder < 1) {
    return true;
  }
  if (evaluateUpdate(local, policy, environment) ==
      UpdateResult.identityConflict) {
    return true;
  }
  return local.releaseOrder < minimum;
}
