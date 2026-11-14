import 'package:livekit_client/livekit_client.dart' as lk;

/// Report identifiers are used only in memory and are never written or logged.
Future<Map<String, int>> inboundPacketReports(lk.Room room) async {
  final result = <String, int>{};
  for (final report in (await room.getPeerConnectionStats()).expand(
    (items) => items,
  )) {
    if (report.type != 'inbound-rtp' ||
        (report.values['kind'] != 'audio' &&
            report.values['mediaType'] != 'audio'))
      continue;
    result[report.id] =
        int.tryParse('${report.values['packetsReceived']}') ?? 0;
  }
  return result;
}
