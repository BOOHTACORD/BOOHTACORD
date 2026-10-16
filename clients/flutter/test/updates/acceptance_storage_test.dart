// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import '../../integration_test/desktop_updates/scoped_storage.dart';

class NativeDelegate extends FlutterSecureStoragePlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError("Unexpected native storage call");
  String? observedKey;
  Map<String, String>? observedOptions;
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    observedKey = key;
    observedOptions = options;
    return 'synthetic-only';
  }
}

void main() {
  test(
    'acceptance storage preserves native backend and isolates service and key',
    () async {
      final native = NativeDelegate();
      final scoped = AcceptanceStorage(
        native,
        'ru.boohtacord.qa337.0123456789abcdef',
      );
      expect(
        await scoped.read(
          key: 'session',
          options: {
            'accountName': 'production',
            'usesDataProtectionKeychain': 'false',
          },
        ),
        'synthetic-only',
      );
      expect(
        native.observedKey,
        'ru.boohtacord.qa337.0123456789abcdef:session',
      );
      expect(native.observedOptions, {
        'accountName': 'ru.boohtacord.qa337.0123456789abcdef',
        'usesDataProtectionKeychain': 'false',
      });
    },
  );
  test('rejects production and unbounded namespaces', () {
    for (final namespace in ['', 'production', 'ru.boohtacord.qa337.bad']) {
      expect(
        () => AcceptanceStorage(NativeDelegate(), namespace),
        throwsArgumentError,
      );
    }
  });
  test('cannot enumerate or erase other native storage', () {
    final scoped = AcceptanceStorage(
      NativeDelegate(),
      'ru.boohtacord.qa337.0123456789abcdef',
    );
    expect(() => scoped.readAll(options: {}), throwsStateError);
    expect(() => scoped.deleteAll(options: {}), throwsStateError);
  });
}
