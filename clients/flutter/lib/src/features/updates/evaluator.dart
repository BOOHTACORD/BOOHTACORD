import 'model.dart';
import 'package_identity/build_number.dart';

part 'required_policy.dart';

List<int>? _parts(String value) {
  if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(value)) return null;
  return value.split('.').map(int.parse).toList();
}

bool _below(String current, String minimum) {
  final left = _parts(current);
  final right = _parts(minimum);
  if (left == null || right == null) return true;
  for (
    var index = 0;
    index < (left.length > right.length ? left.length : right.length);
    index++
  ) {
    final difference =
        (index < left.length ? left[index] : 0) -
        (index < right.length ? right[index] : 0);
    if (difference != 0) return difference < 0;
  }
  return false;
}

bool _valid(UpdatePolicy policy) {
  final state = policy.state;
  if (state == null) return false;
  if (state != UpdatePolicyState.published) return policy.target == null;
  final target = policy.target;
  final minimum = target?.minimumReleaseOrder;
  if (minimum != null &&
      (minimum < 1 || minimum > 2147483647 || minimum > target!.releaseOrder)) {
    return false;
  }
  return target != null &&
      RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(target.releaseId) &&
      target.releaseOrder > 0 &&
      target.arches.isNotEmpty;
}

UpdateResult evaluateUpdate(
  LocalUpdateIdentity? local,
  UpdatePolicy policy,
  UpdateEnvironment environment,
) {
  if (local == null || local.releaseId.isEmpty || local.releaseOrder < 1) {
    return UpdateResult.identityUnknown;
  }
  if (!_valid(policy)) return UpdateResult.checkUnavailable;
  if (policy.state != UpdatePolicyState.published || policy.target == null) {
    return UpdateResult.noPublishedTarget;
  }
  final target = policy.target!;
  if (target.expiresAt != null &&
      !target.expiresAt!.isAfter(environment.now ?? DateTime.now().toUtc())) {
    return UpdateResult.noPublishedTarget;
  }
  if (!target.arches.contains('any') &&
      !target.arches.contains(environment.arch)) {
    return UpdateResult.unsupportedEnvironment;
  }
  if (target.minOsVersion != null &&
      _below(environment.osVersion, target.minOsVersion!)) {
    return UpdateResult.unsupportedEnvironment;
  }
  if (local.installedVersion != null &&
      local.version != null &&
      local.installedVersion != local.version) {
    return UpdateResult.identityConflict;
  }
  if (!packageBuildMatches(
    platform: local.platform,
    arch: environment.arch,
    declared: local.nativeBuild,
    installed: local.installedBuild,
  )) {
    return UpdateResult.identityConflict;
  }
  if (local.packageName != null &&
      local.expectedPackageName != null &&
      local.packageName != local.expectedPackageName) {
    return UpdateResult.identityConflict;
  }
  if (target.releaseId == local.releaseId) return UpdateResult.upToDate;
  if (target.releaseOrder > local.releaseOrder) {
    return UpdateResult.updateAvailable;
  }
  if (target.releaseOrder < local.releaseOrder) {
    return UpdateResult.currentAhead;
  }
  return UpdateResult.identityConflict;
}
