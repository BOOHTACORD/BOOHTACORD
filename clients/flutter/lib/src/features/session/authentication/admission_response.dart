import 'package:http/http.dart' as http;

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

// Authentication admission never retries a password request or expires the
// session. The form owns its transient password until another explicit action.
Future<void> checkAuthenticationResponse(
  ApiTransport transport,
  http.Response response,
) async {
  try {
    await transport.checked(response, reportUnauthorized: false);
  } on ApiFailure catch (failure) {
    if (failure.status != 429) rethrow;
    final value = response.headers['retry-after'] ?? '';
    final seconds = RegExp(r'^\d+$').hasMatch(value)
        ? int.tryParse(value)
        : null;
    final delay = seconds != null && seconds <= 86400
        ? Duration(seconds: seconds)
        : null;
    throw ApiFailure(
      delay == null
          ? 'Слишком много попыток. Подождите и повторите вручную.'
          : 'Слишком много попыток. Повторите вручную через ${delay.inSeconds} с.',
      status: 429,
      code: failure.code,
      retryAfter: delay,
    );
  }
}
