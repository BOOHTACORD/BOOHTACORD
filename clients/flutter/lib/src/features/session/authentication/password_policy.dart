/// Match the server's Unicode code-point bounds without trimming the password.
String? newPasswordError(String value) {
  final count = value.runes.length;
  return count < 12 || count > 128
      ? 'Пароль должен содержать от 12 до 128 символов.'
      : null;
}
