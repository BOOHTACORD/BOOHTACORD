import 'package:boohtacord_desktop/src/features/updates/evaluator.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const environment = UpdateEnvironment(osVersion: '15', arch: 'arm64');
  UpdatePolicy policy(int? minimum) => UpdatePolicy(
    state: UpdatePolicyState.published,
    target: UpdateTarget(
      releaseId: 'release-5',
      releaseOrder: 5,
      arches: const ['arm64'],
      minimumReleaseOrder: minimum,
    ),
  );
  LocalUpdateIdentity local(int order) => LocalUpdateIdentity(
    releaseId: 'release-$order',
    releaseOrder: order,
    platform: 'android',
  );
  test(
    'requires a non-snoozable update only below the valid configured minimum',
    () {
      expect(requiresUpdate(local(2), policy(4), environment), isTrue);
      expect(requiresUpdate(local(4), policy(4), environment), isFalse);
      expect(requiresUpdate(local(2), policy(null), environment), isFalse);
      expect(
        evaluateUpdate(local(2), policy(6), environment),
        UpdateResult.checkUnavailable,
      );
      expect(
        evaluateUpdate(local(2), policy(0), environment),
        UpdateResult.checkUnavailable,
      );
    },
  );
  test(
    'unknown identity and incompatible OS cannot silently bypass minimum',
    () {
      expect(requiresUpdate(null, policy(4), environment), isTrue);
      expect(
        requiresUpdate(
          local(2),
          policy(4),
          const UpdateEnvironment(osVersion: '15', arch: 'x64'),
        ),
        isTrue,
      );
    },
  );
  test('parses the optional minimum and rejects wrong types', () {
    final parsed = UpdateTarget.fromJson({
      'release_id': 'release-5',
      'release_order': 5,
      'requirements': {
        'supported_arches': ['arm64'],
      },
      'minimum_release_order': 4,
    });
    expect(parsed.minimumReleaseOrder, 4);
    expect(
      () => UpdateTarget.fromJson({'minimum_release_order': '4'}),
      throwsA(isA<TypeError>()),
    );
  });
}
