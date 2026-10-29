import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/screen_thumbnail.dart';
import '../../voice/screen_preview/uploader.dart';
import 'sample.dart';

class ScreenThumbnailController {
  ScreenThumbnailController(
    this.scope, {
    required this.readRoom,
    required this.isSharing,
    required this.thumbnails,
    required this.queue,
    required this.changed,
    required this.previewUploader,
    Future<Uint8List> Function(LocalVideoTrack)? capture,
    Future<Uint8List?> Function(Uint8List)? encode,
  }) : capture = capture ?? captureTrack,
       encode = encode ?? encodeFrame;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() isSharing;
  final Map<String, Uint8List> thumbnails;
  final ScreenThumbnailCaptureQueue queue;
  final void Function() changed;
  final LatestScreenPreviewUploader previewUploader;
  final Future<Uint8List> Function(LocalVideoTrack) capture;
  final Future<Uint8List?> Function(Uint8List) encode;
  Timer? timer;
  LocalVideoTrack? track;
  int revision = 0;
  int? busy;
  bool hasCapturedFirstFrame = false;
  int initialCaptureFailureCount = 0;
  ScreenThumbnailCaptureResult? lastLoggedResult;
  String? leaseId;
  Future<void>? cleanup;
  static Future<Uint8List> captureTrack(LocalVideoTrack track) async =>
      (await track.mediaStreamTrack.captureFrame()).asUint8List();
  static Future<Uint8List?> encodeFrame(Uint8List frame) =>
      compute(encodeScreenThumbnail, frame);
  Future<void> start(Room room, LocalVideoTrack track) async {
    final expected = revision + 1;
    final stopped = stop();
    final startRevision = revision;
    if (startRevision != expected) return;
    this.track = track;
    await stopped;
    if (revision != startRevision || !identical(this.track, track)) return;
    hasCapturedFirstFrame = false;
    initialCaptureFailureCount = 0;
    final activeLease = leaseId;
    if (activeLease != null && isSharing()) {
      unawaited(previewUploader.start(activeLease));
    }
    unawaited(sample(room, track));
  }

  Future<void> stop() {
    revision++;
    timer?.cancel();
    timer = null;
    track = null;
    busy = null;
    hasCapturedFirstFrame = false;
    initialCaptureFailureCount = 0;
    lastLoggedResult = null;
    return _invalidatePreview();
  }

  void scheduleNextSample(
    Room room,
    LocalVideoTrack track,
    ScreenThumbnailCaptureResult result,
  ) {
    if (!identical(this.track, track) || !isSharing()) return;
    if (result == ScreenThumbnailCaptureResult.captured) {
      hasCapturedFirstFrame = true;
      initialCaptureFailureCount = 0;
    } else if (!hasCapturedFirstFrame) {
      initialCaptureFailureCount++;
    }
    timer?.cancel();
    timer = Timer(
      screenThumbnailCaptureDelay(
        hasCapturedFirstFrame: hasCapturedFirstFrame,
        initialFailureCount: initialCaptureFailureCount,
      ),
      () => unawaited(sample(room, track)),
    );
  }

  Future<void> changeLease(String? value) async {
    if (leaseId == value) {
      await cleanup;
      return;
    }
    leaseId = value;
    await _invalidatePreview();
    if (value != null && track != null && isSharing()) {
      await previewUploader.start(value);
    }
  }

  Future<void> _invalidatePreview() {
    final existing = cleanup;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = previewUploader.stop().whenComplete(() {
      if (identical(cleanup, operation)) cleanup = null;
    });
    cleanup = operation;
    return operation;
  }
}
