import 'result.dart';
import 'target.dart';

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
