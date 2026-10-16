import 'desktop/artifact.dart';

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

class LocalUpdateIdentity {
  const LocalUpdateIdentity({
    required this.releaseId,
    required this.releaseOrder,
    this.platform,
    this.version,
    this.nativeBuild,
    this.installedVersion,
    this.installedBuild,
    this.packageName,
    this.expectedPackageName,
  });
  factory LocalUpdateIdentity.fromJson(Map<String, dynamic> value) =>
      LocalUpdateIdentity(
        releaseId: value['release_id'] as String? ?? '',
        releaseOrder: value['release_order'] as int? ?? 0,
        platform: value['platform'] as String?,
        version: value['version'] as String?,
        nativeBuild: value['native_build'] as String?,
        installedVersion: value['installed_version'] as String?,
        installedBuild: value['installed_build'] as String?,
        packageName: value['package_name'] as String?,
        expectedPackageName: value['expected_package_name'] as String?,
      );
  final String releaseId;
  final int releaseOrder;
  final String? platform;
  final String? version;
  final String? nativeBuild;
  final String? installedVersion;
  final String? installedBuild;
  final String? packageName;
  final String? expectedPackageName;
}

class UpdateEnvironment {
  const UpdateEnvironment({
    required this.osVersion,
    required this.arch,
    this.now,
  });
  factory UpdateEnvironment.fromJson(Map<String, dynamic> value) =>
      UpdateEnvironment(
        osVersion: value['os_version'] as String? ?? '',
        arch: value['arch'] as String? ?? '',
        now: DateTime.tryParse(value['now'] as String? ?? ''),
      );
  final String osVersion;
  final String arch;
  final DateTime? now;
}

class UpdateTarget {
  const UpdateTarget({
    required this.releaseId,
    required this.releaseOrder,
    required this.arches,
    this.version,
    this.nativeBuild,
    this.priority,
    this.summary,
    this.expiresAt,
    this.releaseNotesUrl,
    this.minOsVersion,
    this.actionKind,
    this.actionUrl,
    this.installArtifact,
  });
  factory UpdateTarget.fromJson(Map<String, dynamic> value) {
    final requirements = value['requirements'] is Map<String, dynamic>
        ? value['requirements'] as Map<String, dynamic>
        : <String, dynamic>{};
    final action = value['action'] is Map<String, dynamic>
        ? value['action'] as Map<String, dynamic>
        : <String, dynamic>{};
    return UpdateTarget(
      releaseId: value['release_id'] as String? ?? '',
      releaseOrder: value['release_order'] as int? ?? 0,
      arches: (requirements['supported_arches'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      version: value['version'] as String?,
      nativeBuild: value['native_build'] as String?,
      priority: value['priority'] as String?,
      summary: value['summary'] as String?,
      expiresAt: DateTime.tryParse(value['expires_at'] as String? ?? ''),
      releaseNotesUrl: value['release_notes_url'] as String?,
      minOsVersion: requirements['min_os_version'] as String?,
      actionKind: action['kind'] as String?,
      actionUrl: action['url'] as String?,
      installArtifact: value['install_artifact'] is Map<String, dynamic>
          ? SignedInstallArtifact.fromJson(
              value['install_artifact'] as Map<String, dynamic>,
            )
          : null,
    );
  }
  final SignedInstallArtifact? installArtifact;
  final String releaseId;
  final int releaseOrder;
  final List<String> arches;
  final String? version;
  final String? nativeBuild;
  final String? priority;
  final String? summary;
  final DateTime? expiresAt;
  final String? releaseNotesUrl;
  final String? minOsVersion;
  final String? actionKind;
  final String? actionUrl;
}

class UpdatePolicy {
  const UpdatePolicy({
    this.applicationFamily,
    this.revision,
    this.platform,
    this.distribution,
    this.channel,
    this.arch,
    this.state,
    this.target,
  });
  factory UpdatePolicy.fromJson(Map<String, dynamic> value) => UpdatePolicy(
    applicationFamily: value['application_family'] as String?,
    revision: value['catalog_revision'] as int?,
    platform: value['platform'] as String?,
    distribution: value['distribution'] as String?,
    channel: value['channel'] as String?,
    arch: value['arch'] as String?,
    state: switch (value['state']) {
      'published' => UpdatePolicyState.published,
      'unconfigured' => UpdatePolicyState.unconfigured,
      'disabled' => UpdatePolicyState.disabled,
      _ => null,
    },
    target: value['target'] is Map<String, dynamic>
        ? UpdateTarget.fromJson(value['target'] as Map<String, dynamic>)
        : null,
  );
  final String? applicationFamily;
  final int? revision;
  final String? platform;
  final String? distribution;
  final String? channel;
  final String? arch;
  final UpdatePolicyState? state;
  final UpdateTarget? target;
}

class UpdateSelector {
  const UpdateSelector(
    this.platform,
    this.distribution,
    this.channel,
    this.arch,
  );
  const UpdateSelector.android(String arch)
    : this('android', 'direct', 'stable', arch);
  const UpdateSelector.windows(String arch)
    : this('windows', 'direct', 'stable', arch);
  const UpdateSelector.ios(String arch)
    : this('ios', 'app_store', 'stable', arch);
  const UpdateSelector.macos(String arch)
    : this('macos', 'direct', 'stable', arch);
  final String platform;
  final String distribution;
  final String channel;
  final String arch;
  Map<String, String> get query => {
    'platform': platform,
    'distribution': distribution,
    'channel': channel,
    'arch': arch,
  };
}
