import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Local-only peer pair. No SDP, candidates or audio samples are logged.
class LocalAudioLoopback {
  RTCPeerConnection? sender;
  RTCPeerConnection? receiver;
  bool receivedTrack = false;

  Future<void> connect(MediaStream stream) async {
    sender = await createPeerConnection({'iceServers': []});
    receiver = await createPeerConnection({'iceServers': []});
    final local = <RTCIceCandidate>[], remote = <RTCIceCandidate>[];
    var ready = false;
    sender!.onIceCandidate = (candidate) {
      if (candidate.candidate?.isNotEmpty != true) return;
      if (ready) {
        unawaited(receiver!.addCandidate(candidate));
      } else {
        local.add(candidate);
      }
    };
    receiver!.onIceCandidate = (candidate) {
      if (candidate.candidate?.isNotEmpty != true) return;
      if (ready) {
        unawaited(sender!.addCandidate(candidate));
      } else {
        remote.add(candidate);
      }
    };
    receiver!.onTrack = (event) {
      if (event.track.kind == 'audio') receivedTrack = true;
    };
    await sender!.addTrack(stream.getAudioTracks().single, stream);
    final offer = await sender!.createOffer();
    await sender!.setLocalDescription(offer);
    await receiver!.setRemoteDescription(offer);
    final answer = await receiver!.createAnswer();
    await receiver!.setLocalDescription(answer);
    await sender!.setRemoteDescription(answer);
    ready = true;
    for (final candidate in local) {
      await receiver!.addCandidate(candidate);
    }
    for (final candidate in remote) {
      await sender!.addCandidate(candidate);
    }
  }

  Future<Map<String, int>> counters() async {
    final inbound = (await receiver!.getStats()).where(
      (item) =>
          item.type == 'inbound-rtp' &&
          (item.values['kind'] == 'audio' ||
              item.values['mediaType'] == 'audio'),
    );
    int count(String key) => inbound.fold(
      0,
      (total, item) => total + (int.tryParse('${item.values[key]}') ?? 0),
    );
    return {
      'receivedPackets': count('packetsReceived'),
      'receivedBytes': count('bytesReceived'),
    };
  }

  Future<void> close() async {
    await sender?.close();
    await receiver?.close();
  }
}
