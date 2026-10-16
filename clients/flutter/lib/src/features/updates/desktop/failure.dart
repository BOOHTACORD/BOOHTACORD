import 'package:flutter/services.dart';

import 'artifact.dart';

// Only fixed support codes may leave native exceptions; never paths or details.
const _reasons = <String>{
  'apply',
  'apply_busy',
  'archive_alias',
  'archive_count',
  'archive_directory',
  'archive_extra',
  'archive_link',
  'archive_link_cycle',
  'archive_link_escape',
  'archive_parent_file',
  'archive_path',
  'archive_size',
  'archive_windows_path',
  'bootstrap_identity',
  'bundle_signature',
  'cancelled',
  'compatibility_changed',
  'digest',
  'disk_space',
  'envelope',
  'expired',
  'extraction',
  'http',
  'identity',
  'installation_location',
  'local_transport',
  'malformed',
  'manual_recovery',
  'native_apply',
  'native_channel',
  'native_signature',
  'native_stage',
  'native_start',
  'native_target',
  'network',
  'no_install_artifact',
  'other',
  'package_arch',
  'package_identity',
  'payload',
  'prepare',
  'publisher',
  'range',
  'recovery_busy',
  'recovery_copy',
  'recovery_identity',
  'recovery_link',
  'recovery_missing',
  'recovery_path',
  'recovery_size',
  'recovery_start',
  'redirect',
  'redirect_limit',
  'release_path',
  'scope_changed',
  'signature',
  'size',
  'source',
  'staging_link',
  'staging_path',
  'timeout',
  'truncated',
  'update_busy',
};

String desktopUpdateFailureCode(String? reason) =>
    _reasons.contains(reason) ? reason! : 'other';

String desktopUpdateFailureReason(Object error, {required String fallback}) {
  final reason = switch (error) {
    ArtifactFailure failure => failure.code,
    PlatformException failure => failure.code,
    FormatException failure => failure.message,
    _ => null,
  };
  return _reasons.contains(reason) ? reason! : fallback;
}
