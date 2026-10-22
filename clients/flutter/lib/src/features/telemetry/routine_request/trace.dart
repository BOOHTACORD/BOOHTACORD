import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:http/http.dart' as http;

bool routinePresenceRequest(http.BaseRequest request) =>
    {'GET', 'PUT'}.contains(request.method.toUpperCase()) &&
    (RegExp(r'/voice/leases/[^/]+/screen-viewers(?:/[^/]+)?$')
            .hasMatch(request.url.path) ||
        (request.method.toUpperCase() == 'GET' &&
            request.url.path.endsWith('/auth/session')));

// Process-local classification is never exported as a new telemetry field.
// Delay the decision until the outcome is known so errors retain real duration.
final _successfulPolling = Expando<bool>();
void omitSuccessfulPolling(Span span) => _successfulPolling[span] = true;
bool successfulPolling(Span span) => _successfulPolling[span] == true;
