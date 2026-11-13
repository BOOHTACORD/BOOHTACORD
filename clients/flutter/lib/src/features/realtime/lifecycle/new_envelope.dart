import 'event.dart';
import 'roster_payload.dart';

final _id = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool validNewRealtimeEnvelope(Map<String, dynamic> source) {
  final hasTelemetry = source.containsKey('telemetry');
  final names = <String>['event_id', 'kind', 'occurred_at', 'payload'];
  if (hasTelemetry) names.add('telemetry');
  if (source.length != names.length || !names.every(source.containsKey)) {
    return false;
  }
  final id = source['event_id'];
  if (id is! String ||
      !_id.hasMatch(id) ||
      !validRealtimeTimestamp(source['occurred_at']) ||
      source['payload'] is! Map<String, dynamic>) {
    return false;
  }
  if (!hasTelemetry) return true;
  final metadata = source['telemetry'];
  return metadata is Map<String, dynamic> &&
      metadata.length == 3 &&
      metadata.keys.toSet().containsAll({'reference', 'trace_id', 'span_id'}) &&
      RealtimeTelemetry.parse(metadata) != null;
}
