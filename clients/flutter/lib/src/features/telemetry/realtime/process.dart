import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../action_scope/action.dart';
import '../action_scope/session.dart';
import '../observe_render/messages.dart';
import '../../realtime/lifecycle/event.dart';
import '../../../services/client_telemetry.dart';
import '../observe_render/workspace.dart';

ActionScope receivedFlow(RealtimeEvent event, TelemetrySession session) {
  final metadata = event.telemetry;
  final links = ClientTelemetry.enabled && metadata != null
      ? [
          OTel.spanLink(
            OTel.spanContext(
              traceId: OTel.traceIdFrom(metadata.traceId),
              spanId: OTel.spanIdFrom(metadata.spanId),
              isRemote: true,
            ),
            attributes: OTel.attributesFromMap({
              'app.causal.ref': metadata.reference,
            }),
          ),
        ]
      : <SpanLink>[];
  return ActionScope(
    'realtime.process',
    session,
    enabled: ClientTelemetry.enabled,
    links: links,
  )..step('refresh');
}

Future<void> refreshReceived(
  RealtimeEvent event,
  TelemetrySession session,
  Future<void> Function() refresh,
  List<({String id, Object value})> Function() messages,
) async {
  final scope = receivedFlow(event, session);
  try {
    await scope.run(refresh);
    if (scope.complete) return;
    if (!session.current(scope.snapshot)) {
      scope.finish('superseded');
      return;
    }
    final target = messages()
        .where((m) => m.id == event.payload['message_id'])
        .firstOrNull;
    if (target != null) awaitMessageRender(target.value, scope);
    // Missing or hidden messages stay incomplete; REST success is not UI success.
  } catch (_) {
    scope.finish('failed', reason: 'dependency');
    rethrow;
  }
}

Future<void> processEffect(
  RealtimeEvent event,
  TelemetrySession session,
  Future<void> Function() effect,
) async {
  final action = receivedFlow(event, session);
  try {
    await action.run(effect);
    if (!action.complete) {
      observeWorkspaceReady(action, () => session.current(action.snapshot));
    }
  } catch (_) {
    action.finish('failed', reason: 'dependency');
    rethrow;
  }
}
