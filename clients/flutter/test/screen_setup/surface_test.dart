import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('setup surface gives interactive tiles a visible ink surface', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SetupSurface(
            children: [
              SwitchListTile(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
                title: const Text('Screen audio'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
