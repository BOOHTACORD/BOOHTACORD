import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/features/updates/required_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system back cannot dismiss a required update', (tester) async {
    final updates = UpdateController.disabled();
    addTearDown(updates.dispose);
    updates.policy = const UpdatePolicy(
      state: UpdatePolicyState.published,
      target: UpdateTarget(
        releaseId: 'r5',
        releaseOrder: 5,
        minimumReleaseOrder: 4,
        arches: ['x64'],
        actionKind: 'open_download_page',
        actionUrl: '/releases',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RequiredUpdateGuard(
                    updates: updates,
                    appBusy: false,
                    child: const Scaffold(body: Text('underlying route')),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('required-update-gate')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('required-update-gate')), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });
}
