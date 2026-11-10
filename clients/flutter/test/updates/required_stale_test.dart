import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/evaluator.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:flutter_test/flutter_test.dart';

class SequenceApi extends UpdateApi {
  SequenceApi(this.policy)
    : super(baseUrl: () => 'https://example.test/api/v1');
  final UpdatePolicy policy;
  int calls = 0;
  @override
  Future<UpdatePolicy> fetch(UpdateSelector selector) async {
    if (calls++ == 0) return policy;
    throw const FormatException('synthetic invalid response');
  }
}

void main() {
  testWidgets('failed recheck retains required policy and marks it stale', (
    tester,
  ) async {
    const policy = UpdatePolicy(
      revision: 1,
      state: UpdatePolicyState.published,
      target: UpdateTarget(
        releaseId: 'r5',
        releaseOrder: 5,
        minimumReleaseOrder: 4,
        arches: ['arm64'],
      ),
    );
    const identity = NativeUpdateIdentity(
      LocalUpdateIdentity(
        releaseId: 'r2',
        releaseOrder: 2,
        platform: 'windows',
      ),
      UpdateSelector.windows('x64'),
      UpdateEnvironment(osVersion: '10', arch: 'x64'),
    );
    final updates = UpdateController(
      api: SequenceApi(policy),
      identity: identity,
    );
    addTearDown(updates.dispose);
    await updates.check();
    expect(
      requiresUpdate(identity.local, updates.policy!, identity.environment),
      isTrue,
    );
    await expectLater(updates.check(), throwsFormatException);
    expect(updates.stale, isTrue);
    expect(updates.policy, same(policy));
    expect(
      requiresUpdate(identity.local, updates.policy!, identity.environment),
      isTrue,
    );
  });
}
