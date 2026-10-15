import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/recovery.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';

import 'package_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final methods = <String>[];
  const channel = MethodChannel('boohtacord/desktop_updates');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'desktop-recovery-retry-',
    );
    methods.clear();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  test(
    'active recovery refusal preserves its plan and never starts a helper',
    () async {
      final root = Directory('${directory.path}/recovery');
      await root.create();
      final plan = File('${root.path}/plan.json');
      await plan.writeAsString('preserve fixture');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            return false;
          });
      final recovery = DesktopRecovery(
        const LocalUpdateIdentity(releaseId: 'old', releaseOrder: 1),
      );
      await expectLater(
        recovery.stage(await testPackage([1], macos: true), directory),
        throwsA(
          isA<ArtifactFailure>().having((e) => e.code, 'code', 'recovery_busy'),
        ),
      );
      expect(await plan.readAsString(), 'preserve fixture');
      expect(methods, ['resetRecovery']);
    },
    skip: !Platform.isMacOS,
  );
  test('a new arm never reuses a queued legacy plan path', () async {
    final root = Directory('${directory.path}/recovery');
    await root.create();
    const transaction = 'e1be6a99-597a-4c52-ab10-90501d13c740';
    String? armed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          armed = (call.arguments as Map)['plan'] as String;
          final plan = jsonDecode(await File(armed!).readAsString()) as Map;
          final launch = jsonDecode(
            await File('${root.path}/launch.json').readAsString(),
          ) as Map;
          expect(launch, {
            'schema_version': 1,
            'transaction': transaction,
            'plan': 'plan-$transaction.json',
          });
          await File('${root.path}/recovery-ready.json')
              .writeAsString(jsonEncode({'transaction': plan['transaction']}));
          return null;
        });
    final recovery = DesktopRecovery(
      const LocalUpdateIdentity(
        releaseId: 'old',
        releaseOrder: 1,
        nativeBuild: '1',
      ),
    );
    await recovery.arm(
      transaction,
      await testPackage([1], macos: true),
      directory,
    );
    expect(armed, endsWith('/plan-$transaction.json'));
    expect(await File('${root.path}/plan.json').exists(), false);
    expect(methods, ['armRecovery']);
  }, skip: !Platform.isMacOS);
}
