import 'dart:convert';

import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'captures validated changes before asynchronous request preparation',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      late Map<String, dynamic> sent;
      final transport = ApiTransport(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'revision': 1,
              'settings': {
                'enabled': true,
                'joined': false,
                'left': true,
                'started': true,
                'stopped': true,
                'allow_custom': true,
                'volume': 50,
              },
            }),
            200,
          );
        }),
      );
      final changes = <String, dynamic>{'joined': false};
      final save = VoiceSoundPreferencesApi(
        transport,
        'account-a',
      ).patch(0, changes);
      changes['joined'] = true;
      await save;
      expect(sent, {'expected_revision': 0, 'joined': false});
    },
  );
}
