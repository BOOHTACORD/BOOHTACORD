import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/features/updates/required_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('required update blocks input without discarding mounted draft', (
    tester,
  ) async {
    final updates = UpdateController.disabled();
    addTearDown(updates.dispose);
    var taps = 0;
    Widget app() => MaterialApp(
      home: RequiredUpdateGuard(
        updates: updates,
        appBusy: false,
        child: Scaffold(
          body: Column(
            children: [
              const TextField(key: ValueKey('draft')),
              ElevatedButton(
                key: const ValueKey('underlying'),
                onPressed: () => taps++,
                child: const Text('Отправить'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byKey(const ValueKey('draft')),
      'synthetic draft',
    );
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
    await tester.pumpWidget(app());
    expect(find.byKey(const ValueKey('required-update-gate')), findsOneWidget);
    expect(find.text('Требуется обновление'), findsOneWidget);
    expect(find.text('Позже'), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('underlying')).hitTestable(),
      findsNothing,
    );
    expect(taps, 0);
    updates.policy = null;
    await tester.pumpWidget(app());
    expect(find.byKey(const ValueKey('required-update-gate')), findsNothing);
    expect(find.text('synthetic draft'), findsOneWidget);
  });
}
