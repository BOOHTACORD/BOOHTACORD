import 'model.dart';

bool updateTargetMatchesIdentity(
  LocalUpdateIdentity local,
  UpdateTarget target,
) =>
    target.releaseOrder == local.releaseOrder &&
    (local.version == null || target.version == local.version) &&
    (local.nativeBuild == null || target.nativeBuild == local.nativeBuild);
