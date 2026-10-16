// The real SDK can report its original connection failure before lease cleanup
// replaces the UI notice. Retain categories only, never SDK messages/URLs/SDP.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class AcceptanceVoiceDiagnostics {
  final _codes = <String>{};
  List<String> get codes => List.unmodifiable(_codes);
  int _samples = 0, _localMax = 0, _remoteMax = 0;
  bool _remoteLoopback = false, _localNonloopback = false;
  bool _requests = false, _responses = false, _selected = false;
  final _protocols = <String>{}, _states = <String>{};

  Map<String, Object> get ice => {
    'samples': _samples,
    'local_candidates_max': _localMax,
    'remote_candidates_max': _remoteMax,
    'remote_loopback_seen': _remoteLoopback,
    'local_nonloopback_seen': _localNonloopback,
    'pair_request_seen': _requests,
    'pair_response_seen': _responses,
    'selected_pair_seen': _selected,
    'protocols': _protocols.toList()..sort(),
    'pair_states': _states.toList()..sort(),
  };

  void observeStats(List<List<rtc.StatsReport>> connections) {
    if (_samples >= 1000) return;
    _samples++;
    var local = 0, remote = 0;
    for (final connection in connections) {
      for (final report in connection) {
        final values = report.values;
        if (report.type == 'local-candidate' ||
            report.type == 'remote-candidate') {
          final isLocal = report.type == 'local-candidate';
          if (isLocal) {
            local++;
          } else {
            remote++;
          }
          final protocol = values['protocol'];
          if (protocol == 'tcp' || protocol == 'udp') {
            _protocols.add(protocol as String);
          }
          final rawAddress = values['address'] ?? values['ip'];
          final address = rawAddress is String
              ? InternetAddress.tryParse(rawAddress)
              : null;
          if (address != null) {
            if (isLocal && !address.isLoopback) _localNonloopback = true;
            if (!isLocal && address.isLoopback) _remoteLoopback = true;
          }
        } else if (report.type == 'candidate-pair') {
          final state = values['state'];
          if (const {
            'frozen',
            'waiting',
            'in-progress',
            'failed',
            'succeeded',
          }.contains(state)) {
            _states.add(state as String);
          }
          if (values['requestsSent'] case final num count when count > 0) {
            _requests = true;
          }
          if (values['responsesReceived'] case final num count when count > 0) {
            _responses = true;
          }
          if (values['selected'] == true || values['nominated'] == true) {
            _selected = true;
          }
        }
      }
    }
    if (local > _localMax) _localMax = local;
    if (remote > _remoteMax) _remoteMax = remote;
  }

  void observe(String logger, String message) {
    if (logger != 'livekit') return;
    final text = message.toLowerCase();
    final String? code;
    if (text.contains('[mediaconnectexception]')) {
      code = 'ice_connect';
    } else if (text.contains('[negotiationerror]')) {
      code = 'negotiation';
    } else if (text.contains('[certificatepinningexception]') ||
        text.contains('handshakeexception')) {
      code = 'tls';
    } else if (text.contains('no internet connection')) {
      code = 'offline';
    } else if (text.contains('signaljoinresponseevent')) {
      code = 'signaling_timeout';
    } else if (text.contains('received websocket error')) {
      code = 'signaling_socket';
    } else if (text.contains('could not connect to')) {
      code = 'unclassified';
    } else {
      code = null;
    }
    if (code != null) _codes.add(code);
  }
}
