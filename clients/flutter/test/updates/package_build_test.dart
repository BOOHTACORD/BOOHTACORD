import 'package:boohtacord_desktop/src/features/updates/evaluator.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:flutter_test/flutter_test.dart';

LocalUpdateIdentity local(String installed, {String platform = 'android'}) =>
    LocalUpdateIdentity(
      releaseId: '$platform-direct-stable-r44', releaseOrder: 44,
      platform: platform, version: '1.0.30', nativeBuild: '44',
      installedVersion: '1.0.30', installedBuild: installed,
    );

UpdatePolicy policy(int order, {String platform = 'android'}) => UpdatePolicy(
  state: UpdatePolicyState.published,
  target: UpdateTarget(
    releaseId: '$platform-direct-stable-r$order', releaseOrder: order,
    version: '1.0.30', nativeBuild: '$order',
    arches: const ['any'],
  ),
);

void main() {
  // Version codes measured in the actual published 1.0.30 APKs.
  for (final entry in {'armv7': '1044', 'arm64': '2044', 'x64': '4044'}.entries) {
    final environment = UpdateEnvironment(osVersion: '35', arch: entry.key);
    test('published ${entry.key} split APK is up to date', () {
      expect(evaluateUpdate(local(entry.value), policy(44), environment),
          UpdateResult.upToDate);
    });
    test('published ${entry.key} split APK can see the next release', () {
      expect(evaluateUpdate(local(entry.value), policy(45), environment),
          UpdateResult.updateAvailable);
    });
  }
  test('universal Android build preserves exact identity', () {
    expect(evaluateUpdate(local('44'), policy(44),
        const UpdateEnvironment(osVersion: '35', arch: 'arm64')),
        UpdateResult.upToDate);
  });
  for (final installed in ['1044', '4044', '2043', '002044', '', '2044x']) {
    test('arm64 rejects mismatched or malformed build $installed', () {
      expect(evaluateUpdate(local(installed), policy(44),
          const UpdateEnvironment(osVersion: '35', arch: 'arm64')),
          UpdateResult.identityConflict);
    });
  }
  test('unknown Android architecture cannot infer an ABI offset', () {
    expect(evaluateUpdate(local('2044'), policy(44),
        const UpdateEnvironment(osVersion: '35', arch: 'any')),
        UpdateResult.identityConflict);
  });
  test('Windows never strips an Android ABI prefix', () {
    expect(evaluateUpdate(local('2044', platform: 'windows'),
        policy(44, platform: 'windows'),
        const UpdateEnvironment(osVersion: '10', arch: 'x64')),
        UpdateResult.identityConflict);
  });
}
