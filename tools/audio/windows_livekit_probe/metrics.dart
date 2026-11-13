import 'package:livekit_client/livekit_client.dart' as lk;

Future<Map<String, int>> inboundCounters(lk.Room room) async {
  final reports = (await room.getPeerConnectionStats())
      .expand((list) => list)
      .where(
        (item) =>
            item.type == 'inbound-rtp' &&
            (item.values['kind'] == 'audio' ||
                item.values['mediaType'] == 'audio'),
      );
  int count(String key) => reports.fold(
    0,
    (total, item) => total + (int.tryParse('${item.values[key]}') ?? 0),
  );
  return {
    'receivedPackets': count('packetsReceived'),
    'receivedBytes': count('bytesReceived'),
  };
}
