import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Selected publisher ICE path from the same sender getStats collection.
/// Contains no addresses, candidate identifiers, ports or SDP fragments.
class ScreenSenderTransportSnapshot {
  const ScreenSenderTransportSnapshot({
    this.candidateProtocol,
    this.localCandidateType,
    this.remoteCandidateType,
    this.relayProtocol,
    this.roundTripTimeSeconds,
    this.availableOutgoingBitrate,
    this.availableIncomingBitrate,
    this.statsTimestampMs,
  });
  final String? candidateProtocol,
      localCandidateType,
      remoteCandidateType,
      relayProtocol;
  final double? roundTripTimeSeconds,
      availableOutgoingBitrate,
      availableIncomingBitrate,
      statsTimestampMs;
  Map<String, Object?> toPublicJson() => {
    'candidate_protocol': candidateProtocol,
    'local_candidate_type': localCandidateType,
    'remote_candidate_type': remoteCandidateType,
    'relay_protocol': relayProtocol,
    'round_trip_time_seconds': roundTripTimeSeconds,
    'available_outgoing_bitrate_estimate': availableOutgoingBitrate,
    'available_incoming_bitrate_estimate': availableIncomingBitrate,
    'stats_timestamp_ms': statsTimestampMs,
    'stats_timestamp_provenance':
        'RTC report timestamp, not host monotonic clock',
    'bandwidth_provenance': 'candidate_pair_estimate_not_SFU_truth',
  };
}

ScreenSenderTransportSnapshot? screenSenderTransportFromReports(
  rtc.StatsReport outbound,
  List<rtc.StatsReport> reports,
) {
  String? link(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
  rtc.StatsReport? find(String type, String? id) {
    if (id == null) return null;
    final matches = reports
        .where((row) => row.type == type && row.id == id)
        .take(2)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  final transport = find('transport', link(outbound.values['transportId']));
  final pair = find(
    'candidate-pair',
    link(transport?.values['selectedCandidatePairId']),
  );
  if (pair == null || pair.values['state'] != 'succeeded') return null;
  final local = find('local-candidate', link(pair.values['localCandidateId'])),
      remote = find('remote-candidate', link(pair.values['remoteCandidateId']));
  if (local == null || remote == null) return null;
  const protocols = {'udp', 'tcp'},
      types = {'host', 'prflx', 'srflx', 'relay'},
      relayProtocols = {'udp', 'tcp', 'tls'};
  final localProtocol = local.values['protocol'],
      remoteProtocol = remote.values['protocol'];
  String? allowed(Object? value, Set<String> values) =>
      value is String && values.contains(value) ? value : null;
  double? number(String name, double max) {
    final value = pair.values[name];
    return value is num && value.isFinite && value >= 0 && value <= max
        ? value.toDouble()
        : null;
  }

  return ScreenSenderTransportSnapshot(
    candidateProtocol: localProtocol == remoteProtocol
        ? allowed(localProtocol, protocols)
        : null,
    localCandidateType: allowed(local.values['candidateType'], types),
    remoteCandidateType: allowed(remote.values['candidateType'], types),
    relayProtocol:
        allowed(local.values['relayProtocol'], relayProtocols) ??
        allowed(remote.values['relayProtocol'], relayProtocols),
    roundTripTimeSeconds: number('currentRoundTripTime', 60),
    availableOutgoingBitrate: number('availableOutgoingBitrate', 1000000000000),
    availableIncomingBitrate: number('availableIncomingBitrate', 1000000000000),
    statsTimestampMs: pair.timestamp.isFinite && pair.timestamp >= 0
        ? pair.timestamp / 1000
        : null,
  );
}
