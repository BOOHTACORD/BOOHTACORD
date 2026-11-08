import 'package:boohtacord_desktop/src/features/session/authentication/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration and reset follow the server Unicode length bounds', () {
    const message = 'Пароль должен содержать от 12 до 128 символов.';
    expect(newPasswordError('a' * 11), message);
    expect(newPasswordError('a' * 12), isNull);
    expect(newPasswordError('😀' * 128), isNull);
    expect(newPasswordError('😀' * 129), message);
    expect(newPasswordError(' ' * 12), isNull);
  });
}
