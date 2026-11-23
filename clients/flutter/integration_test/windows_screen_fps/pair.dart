import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class FpsPair {
  FpsPair(this.sender, this.receiver, this.transceiver, this.renderer);
  final rtc.RTCPeerConnection sender, receiver;
  final rtc.RTCRtpTransceiver transceiver;
  final rtc.RTCVideoRenderer renderer;
  static Future<FpsPair> create(
    rtc.MediaStreamTrack track,
    rtc.MediaStream stream,
    rtc.RTCRtpEncoding encoding,
  ) async {
    final sender = await rtc.createPeerConnection({'iceServers': []});
    final receiver = await rtc.createPeerConnection({'iceServers': []});
    final renderer = rtc.RTCVideoRenderer();
    await renderer.initialize();
    receiver.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        renderer.srcObject = event.streams.first;
      }
    };
    final left = <rtc.RTCIceCandidate>[], right = <rtc.RTCIceCandidate>[];
    var leftReady = false, rightReady = false;
    sender.onIceCandidate = (c) {
      if (rightReady) {
        unawaited(receiver.addCandidate(c));
      } else {
        left.add(c);
      }
    };
    receiver.onIceCandidate = (c) {
      if (leftReady) {
        unawaited(sender.addCandidate(c));
      } else {
        right.add(c);
      }
    };
    final transceiver = await sender.addTransceiver(
      track: track,
      init: rtc.RTCRtpTransceiverInit(
        direction: rtc.TransceiverDirection.SendOnly,
        streams: [stream],
        sendEncodings: [encoding],
      ),
    );
    final offer = await sender.createOffer();
    await sender.setLocalDescription(offer);
    await receiver.setRemoteDescription(offer);
    rightReady = true;
    for (final c in left) {
      await receiver.addCandidate(c);
    }
    final answer = await receiver.createAnswer();
    await receiver.setLocalDescription(answer);
    await sender.setRemoteDescription(answer);
    leftReady = true;
    for (final c in right) {
      await sender.addCandidate(c);
    }
    return FpsPair(sender, receiver, transceiver, renderer);
  }

  Future<void> close() async {
    await sender.close();
    await receiver.close();
    await sender.dispose();
    await receiver.dispose();
    await renderer.dispose();
  }
}
