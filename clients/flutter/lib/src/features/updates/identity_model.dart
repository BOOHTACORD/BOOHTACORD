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
