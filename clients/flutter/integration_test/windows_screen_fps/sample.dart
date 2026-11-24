import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'pair.dart';

Future<Map<String, dynamic>> counters(rtc.RTCPeerConnection pc) async {
  return reportCounters(await pc.getStats());
}

Map<String, dynamic> reportCounters(List<rtc.StatsReport> reports) {
  final result = <String, dynamic>{};
  for (final report in reports) {
    if (!{
      'outbound-rtp',
      'inbound-rtp',
      'media-source',
    }.contains(report.type)) {
      continue;
    }
    final v = report.values;
    if ((v['kind'] ?? v['mediaType']) != 'video') continue;
    for (final key in [
      'framesEncoded',
      'framesReceived',
      'framesDecoded',
      'framesPerSecond',
      'frames',
      'totalEncodeTime',
      'qualityLimitationReason',
      'frameWidth',
      'frameHeight',
    ]) {
      if (v.containsKey(key)) result['${report.type}.$key'] = v[key];
    }
  }
  return result;
}

Future<Map<String, dynamic>> measure(FpsPair pair, int requested) async {
  return measureReaders(
    () => counters(pair.sender),
    () => counters(pair.receiver),
    requested,
  );
}

Future<Map<String, dynamic>> measureReaders(
  Future<Map<String, dynamic>> Function() sender,
  Future<Map<String, dynamic>> Function() receiver,
  int requested,
) async {
  await Future<void>.delayed(const Duration(seconds: 3));
  final before = await sender();
  final remoteBefore = await receiver();
  final watch = Stopwatch()..start();
  await Future<void>.delayed(const Duration(seconds: 8));
  final after = await sender();
  final remoteAfter = await receiver();
  final seconds = watch.elapsedMilliseconds / 1000;
  double? rate(
    Map<String, dynamic> first,
    Map<String, dynamic> last,
    String key,
  ) => first[key] is num && last[key] is num
      ? ((last[key] as num) - (first[key] as num)) / seconds
      : null;
  return {
    'requested_fps': requested,
    'seconds': seconds,
    'encoded_fps': rate(before, after, 'outbound-rtp.framesEncoded'),
    'decoded_fps': rate(remoteBefore, remoteAfter, 'inbound-rtp.framesDecoded'),
    'sender': after,
    'receiver': remoteAfter,
  };
}
