import 'desktop/artifact.dart';

class UpdateTarget {
  const UpdateTarget({
    required this.releaseId,
    required this.releaseOrder,
    this.minimumReleaseOrder,
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
      minimumReleaseOrder: value['minimum_release_order'] as int?,
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
  final int? minimumReleaseOrder;
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
