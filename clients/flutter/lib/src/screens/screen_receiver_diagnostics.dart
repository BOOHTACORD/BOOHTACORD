import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/screen_share_metrics.dart';
import '../features/screen/receiver_metrics/models.dart';
import '../features/screen/receiver_metrics/compare.dart';
import '../features/screen/receiver_metrics/read.dart';
import '../features/screen/sender_metadata/descriptor.dart';
import '../features/screen/sender_metadata/latest_writer.dart';
import '../features/screen/sender_metadata/presentation.dart';
import '../features/screen/metrics/stats_poller.dart';
import '../services/screen_receiver_report.dart';
import '../theme.dart';
import 'screen_packet_loss.dart';

export '../features/screen/receiver_metrics/models.dart';
export '../features/screen/receiver_metrics/compare.dart';

class ScreenReceiverDiagnostics extends StatefulWidget {
  const ScreenReceiverDiagnostics({
    super.key,
    required this.track,
    required this.isLocal,
    required this.hasAudio,
    this.selectedStreamId,
    this.reportEnabled = true,
    this.onReport,
    this.sourceTrackName,
    this.senderReport,
    this.senderSampledAt,
    this.senderDescriptorJson,
    this.expectedSenderOrigin,
    this.expectedSenderAccountId,
    this.expectedRoomId,
    this.publicationKey,
    this.senderSelectedProfileId,
    this.senderSelectedMode,
    this.senderConfigurationStatus,
    this.senderConfirmedAt,
    this.senderAppliedAt,
  });

  final RemoteVideoTrack? track;
  final bool isLocal;
  final bool hasAudio;
  final String? selectedStreamId;
  final bool reportEnabled;
  final Future<void> Function(Map<String, Object> report)? onReport;
  final String? sourceTrackName;
  final ScreenShareSenderReport? senderReport;
  final DateTime? senderSampledAt;
  final String? senderDescriptorJson;
  final String? expectedSenderOrigin;
  final String? expectedSenderAccountId;
  final String? expectedRoomId;
  final String? publicationKey, senderSelectedProfileId, senderSelectedMode;
  final ScreenDescriptorWriteStatus? senderConfigurationStatus;
  final DateTime? senderConfirmedAt, senderAppliedAt;

  @override
  State<ScreenReceiverDiagnostics> createState() =>
      _ScreenReceiverDiagnosticsState();
}

class _ScreenReceiverDiagnosticsState extends State<ScreenReceiverDiagnostics>
    with WidgetsBindingObserver {
  static const _popoverViewportInset = 16.0;
  static const _popoverAnchorGap = 8.0;
  static const _preferredPopoverHeight = 520.0;

  final OverlayPortalController _popoverController = OverlayPortalController();
  final LayerLink _summaryLink = LayerLink();
  final GlobalKey _summaryKey = GlobalKey();
  final FocusNode _focusNode = FocusNode(debugLabel: 'Статистика трансляции');
  Timer? _timer;
  Timer? _reportTimer;
  int _samplingGeneration = 0;
  ScreenReceiverSnapshot? _previous;
  ScreenReceiverSnapshot? _current;
  ScreenReceiverMetrics? _metrics;
  final ScreenPacketLossWindow _lossWindow = ScreenPacketLossWindow();
  DateTime? _sampledAt;
  bool _sampling = false;
  bool _reporting = false;
  bool _appVisible = true;
  bool _popoverOpen = false;
  String _sampleStatus = 'Ожидание статистики приёмника';
  ScreenShareSenderDescriptor? _senderDescriptor;
  ScreenShareSenderDescriptor? _publicationFloor;
  bool _floorRequiresNewGeneration = false;
  DateTime? _descriptorReceivedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _senderDescriptor = _parseSenderDescriptor();
    _descriptorReceivedAt = _senderDescriptor == null ? null : DateTime.now();
    _restartSampling();
  }

  @override
  void didUpdateWidget(covariant ScreenReceiverDiagnostics oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedOwner =
        oldWidget.expectedSenderAccountId != widget.expectedSenderAccountId ||
        oldWidget.expectedSenderOrigin != widget.expectedSenderOrigin ||
        oldWidget.expectedRoomId != widget.expectedRoomId ||
        oldWidget.selectedStreamId != widget.selectedStreamId;
    final changedPublication =
        oldWidget.publicationKey != widget.publicationKey ||
        ((oldWidget.publicationKey == null && widget.publicationKey == null) &&
            oldWidget.track != widget.track) ||
        oldWidget.sourceTrackName != widget.sourceTrackName;
    if (widget.isLocal) {
      _senderDescriptor = _parseSenderDescriptor();
    } else if (changedOwner) {
      _publicationFloor = null;
      _floorRequiresNewGeneration = false;
      _senderDescriptor = _parseSenderDescriptor();
      _descriptorReceivedAt = _senderDescriptor == null ? null : DateTime.now();
    } else if (changedPublication ||
        oldWidget.senderDescriptorJson != widget.senderDescriptorJson) {
      if (changedPublication) {
        if (oldWidget.publicationKey != widget.publicationKey ||
            (oldWidget.publicationKey == null &&
                widget.publicationKey == null &&
                oldWidget.track != widget.track)) {
          _floorRequiresNewGeneration = true;
        }
        _publicationFloor = _senderDescriptor ?? _publicationFloor;
        _senderDescriptor = null;
        _descriptorReceivedAt = null;
      }
      final candidate = _parseSenderDescriptor();
      if (candidate == null) {
        _senderDescriptor = null;
      } else if ((_publicationFloor == null ||
              candidate.mediaSessionId != _publicationFloor!.mediaSessionId ||
              candidate.publicationGeneration >
                  _publicationFloor!.publicationGeneration ||
              (!_floorRequiresNewGeneration &&
                  isNewerScreenShareDescriptor(
                    candidate,
                    _publicationFloor!,
                  ))) &&
          (_senderDescriptor == null ||
              isNewerScreenShareDescriptor(candidate, _senderDescriptor!))) {
        _senderDescriptor = candidate;
        _publicationFloor = null;
        _floorRequiresNewGeneration = false;
        _descriptorReceivedAt = DateTime.now();
      }
    }
    if (oldWidget.track != widget.track ||
        oldWidget.isLocal != widget.isLocal ||
        oldWidget.reportEnabled != widget.reportEnabled ||
        oldWidget.selectedStreamId != widget.selectedStreamId) {
      _restartSampling();
    }
  }

  ScreenShareSenderDescriptor? _parseSenderDescriptor() {
    if (widget.isLocal) {
      return parseScreenShareDescriptor(widget.senderDescriptorJson);
    }
    if (widget.expectedSenderOrigin == null ||
        widget.expectedSenderAccountId == null ||
        widget.expectedRoomId == null) {
      return null;
    }
    return parseScreenShareDescriptor(
      widget.senderDescriptorJson,
      expectedOriginId: widget.expectedSenderOrigin,
      expectedAccountId: widget.expectedSenderAccountId,
      expectedRoomId: widget.expectedRoomId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _reportTimer?.cancel();
    final receiver = widget.track?.receiver;
    if (receiver != null) screenStatsPoller(receiver).clear();
    _samplingGeneration++;
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
  }

  void _togglePopover() {
    setState(() => _popoverOpen = !_popoverOpen);
    if (_popoverOpen) {
      _popoverController.show();
      _focusNode.requestFocus();
    } else {
      _popoverController.hide();
    }
  }

  void _closePopover() {
    if (!_popoverOpen) return;
    setState(() => _popoverOpen = false);
    _popoverController.hide();
  }

  void _restartSampling() {
    final receiver = widget.track?.receiver;
    if (receiver != null) screenStatsPoller(receiver).clear();
    final generation = ++_samplingGeneration;
    _timer?.cancel();
    _sampling = false;
    _previous = null;
    _lossWindow.clear();
    _current = null;
    _metrics = null;
    _sampledAt = null;
    _reportTimer?.cancel();
    _reporting = false;
    if (!widget.isLocal && widget.reportEnabled && widget.onReport != null) {
      _reportTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_submitReport()),
      );
    }
    final track = widget.track;
    _sampleStatus = widget.isLocal
        ? 'Ожидание статистики отправителя'
        : track == null
        ? 'Видеоприёмник недоступен'
        : 'Ожидание статистики приёмника';
    if (track == null || widget.isLocal) return;
    unawaited(_sample(track, generation));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_sample(track, generation)),
    );
  }

  Future<void> _submitReport() async {
    final reportCallback = widget.onReport;
    if (_reporting ||
        !mounted ||
        !_appVisible ||
        widget.isLocal ||
        !widget.reportEnabled ||
        reportCallback == null) {
      return;
    }
    final platform = nativeScreenMetricsPlatform(defaultTargetPlatform);
    if (platform == null) return;
    final report = buildScreenReceiverReport(
      platform: platform,
      selected: true,
      hasTrack: widget.track != null,
      current: _current,
      metrics: _metrics,
      sampleAgeMs: _sampledAt == null
          ? null
          : DateTime.now().difference(_sampledAt!).inMilliseconds,
      packetLossWindowMs: _lossWindow.durationMs,
    );
    if (report == null) return;
    _reporting = true;
    try {
      await reportCallback(report);
    } catch (_) {
      // Best-effort diagnostics must not interrupt screen playback.
    } finally {
      _reporting = false;
    }
  }

  Future<void> _sample(RemoteVideoTrack track, int generation) async {
    if (_sampling || generation != _samplingGeneration) return;
    _sampling = true;
    try {
      final stats = await readScreenReceiverSnapshot(track);
      if (!mounted ||
          generation != _samplingGeneration ||
          !identical(track, widget.track)) {
        return;
      }
      if (stats == null) {
        _previous = null;
        _lossWindow.clear();
        setState(() {
          _current = null;
          _metrics = null;
          _sampledAt = null;
          _sampleStatus = 'Приёмник не вернул статистику';
        });
        return;
      }
      final next = stats;
      if (_previous?.timestampMs == next.timestampMs) return;
      if (_previous?.streamId != next.streamId ||
          _previous?.ssrc != next.ssrc) {
        _lossWindow.clear();
      }
      final measured = compareScreenReceiverStats(_previous, next);
      final metrics = ScreenReceiverMetrics(
        statsWindowMs: measured.statsWindowMs,
        collectionState: measured.collectionState,
        decodeMsPerFrame: measured.decodeMsPerFrame,
        jitterBufferMsPerFrame: measured.jitterBufferMsPerFrame,
        nackPerSecond: measured.nackPerSecond,
        pliPerSecond: measured.pliPerSecond,
        firPerSecond: measured.firPerSecond,
        freezeCount: measured.freezeCount,
        freezeDurationMs: measured.freezeDurationMs,
        bitrateKbps: measured.bitrateKbps,
        receivedFps: measured.receivedFps,
        decodedFps: measured.decodedFps,
        presentedFps: measured.presentedFps,
        droppedFrames: measured.droppedFrames,
        jitterMs: measured.jitterMs,
        packetsLost: measured.packetsLost,
        packetLossPercent: _lossWindow.add(
          timestampMs: next.timestampMs,
          packetsReceived: next.packetsReceived,
          packetsLost: next.packetsLost,
        ),
      );
      _previous = next;
      setState(() {
        _current = next;
        _metrics = metrics;
        _sampledAt = DateTime.now();
        _sampleStatus = 'Измерено в ${_formatTime(_sampledAt!)}';
      });
    } catch (_) {
      if (mounted &&
          generation == _samplingGeneration &&
          identical(track, widget.track)) {
        _previous = null;
        _lossWindow.clear();
        setState(() {
          _current = null;
          _metrics = null;
          _sampledAt = null;
          _sampleStatus = 'Не удалось прочитать статистику';
        });
      }
    } finally {
      if (generation == _samplingGeneration) _sampling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampledAt = widget.isLocal ? widget.senderSampledAt : _sampledAt;
    final sampleStatus = widget.isLocal && sampledAt != null
        ? 'Измерено в ${_formatTime(sampledAt)}'
        : _sampleStatus;
    final hasMetrics = widget.isLocal
        ? widget.senderReport != null &&
              widget.senderReport?.state != 'waiting_first_frame'
        : _current != null;
    final compact = MediaQuery.sizeOf(context).width <= 1100;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (_popoverOpen &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePopover();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: OverlayPortal(
        controller: _popoverController,
        overlayChildBuilder: (context) {
          final media = MediaQuery.sizeOf(context);
          final panelWidth = math.min(288.0, media.width - 32);
          final summaryBox =
              _summaryKey.currentContext?.findRenderObject() as RenderBox?;
          final summaryTop = summaryBox?.localToGlobal(Offset.zero).dy ?? 0;
          final summaryBottom = summaryTop + (summaryBox?.size.height ?? 36);
          final spaceBelow =
              media.height -
              summaryBottom -
              _popoverAnchorGap -
              _popoverViewportInset;
          final spaceAbove =
              summaryTop - _popoverAnchorGap - _popoverViewportInset;
          final preferredHeight = math.min(
            _preferredPopoverHeight,
            media.height - 2 * _popoverViewportInset,
          );
          final openAbove =
              spaceBelow < preferredHeight && spaceAbove > spaceBelow;
          final availableHeight = openAbove ? spaceAbove : spaceBelow;
          final maxPopoverHeight = math.max(
            0.0,
            math.min(media.height - 2 * _popoverViewportInset, availableHeight),
          );
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePopover,
                    child: const SizedBox.expand(),
                  ),
                ),
                CompositedTransformFollower(
                  link: _summaryLink,
                  showWhenUnlinked: false,
                  targetAnchor: openAbove
                      ? (compact ? Alignment.topLeft : Alignment.topRight)
                      : (compact
                            ? Alignment.bottomLeft
                            : Alignment.bottomRight),
                  followerAnchor: openAbove
                      ? (compact ? Alignment.bottomLeft : Alignment.bottomRight)
                      : (compact ? Alignment.topLeft : Alignment.topRight),
                  offset: Offset(
                    0,
                    openAbove ? -_popoverAnchorGap : _popoverAnchorGap,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Container(
                      key: const ValueKey(
                        'screen-receiver-diagnostics-popover',
                      ),
                      width: panelWidth,
                      constraints: BoxConstraints(maxHeight: maxPopoverHeight),
                      decoration: BoxDecoration(
                        color: GcColors.raised,
                        border: Border.all(color: GcColors.border),
                        borderRadius: BorderRadius.circular(GcRadii.md),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DiagnosticRow(
                              label: 'Профиль при запуске',
                              value: _screenShareTargetProfile(
                                widget.sourceTrackName,
                              ),
                            ),
                            if (!widget.isLocal) ...[
                              _DiagnosticRow(
                                label: 'Режим отправителя',
                                value: senderModeLabel(_senderDescriptor?.mode),
                              ),
                              _DiagnosticRow(
                                label: 'Выбрано отправителем',
                                value: senderRequestedProfileLabel(
                                  _senderDescriptor?.requestedProfileId,
                                ),
                              ),
                            ],
                            if (!widget.isLocal) ...[
                              for (final entry in senderConfigurationLabels(
                                _senderDescriptor,
                              ).entries)
                                _DiagnosticRow(
                                  label: entry.key,
                                  value: entry.value,
                                ),
                              _DiagnosticRow(
                                label: 'Получение конфигурации',
                                value: senderMetadataReceiptAge(
                                  _descriptorReceivedAt,
                                  DateTime.now(),
                                ),
                              ),
                              const _DiagnosticRow(
                                label: 'Измерено у отправителя',
                                value: 'Нет данных',
                              ),
                            ],
                            if (widget.isLocal) ...[
                              for (final entry
                                  in localSenderConfigurationLabels(
                                    _senderDescriptor,
                                    selectedProfileId:
                                        widget.senderSelectedProfileId,
                                    selectedMode: widget.senderSelectedMode,
                                    writeStatus:
                                        widget.senderConfigurationStatus?.name,
                                    confirmedAt: widget.senderConfirmedAt,
                                  ).entries)
                                _DiagnosticRow(
                                  label: entry.key,
                                  value: entry.value,
                                ),
                              if (widget.senderConfirmedAt case final time?)
                                _DiagnosticRow(
                                  label: 'Подтверждено в SDK',
                                  value: _formatTime(time),
                                ),
                              if (widget.senderAppliedAt case final time?)
                                _DiagnosticRow(
                                  label: 'Записано сервером в',
                                  value: _formatTime(time),
                                ),
                              ..._senderRows(widget.senderReport),
                            ] else ...[
                              _DiagnosticRow(
                                label: 'Сейчас у зрителя',
                                value: _formatResolution(_current),
                              ),
                              _DiagnosticRow(
                                label: 'Получено кадров',
                                value: _formatMetric(
                                  _metrics?.receivedFps,
                                  'FPS',
                                ),
                              ),
                              _DiagnosticRow(
                                label: 'Декодировано',
                                value: _formatMetric(
                                  _metrics?.decodedFps ??
                                      _current?.framesPerSecond,
                                  'FPS',
                                ),
                              ),
                              if (_boundedReceiverDetail(_current?.codec)
                                  case final codec?)
                                _DiagnosticRow(label: 'Кодек', value: codec),
                              if (_boundedReceiverDetail(
                                    _current?.decoderImplementation,
                                  )
                                  case final decoder?)
                                _DiagnosticRow(
                                  label: 'Декодер',
                                  value: decoder,
                                ),
                              _DiagnosticRow(
                                label: 'Показано',
                                value: _formatMetric(
                                  _metrics?.presentedFps,
                                  'FPS',
                                ),
                              ),
                              _DiagnosticRow(
                                label: 'Получено',
                                value: _formatMetric(
                                  _metrics?.bitrateKbps,
                                  'кбит/с',
                                ),
                              ),
                              _DiagnosticRow(
                                label: 'Потери пакетов за 10 с',
                                value: formatScreenPacketLossPercent(
                                  _metrics?.packetLossPercent,
                                ),
                              ),
                              _DiagnosticRow(
                                label: 'Пропущено кадров за интервал',
                                value: _formatMetric(_metrics?.droppedFrames),
                              ),
                              _DiagnosticRow(
                                label: 'Jitter',
                                value: _formatMetric(_metrics?.jitterMs, 'мс'),
                              ),
                              const _DiagnosticRow(
                                label: 'RTT',
                                value: 'Нет данных от приёмника',
                              ),
                            ],
                            _DiagnosticRow(
                              label: 'Аудиодорожка',
                              value: widget.isLocal
                                  ? 'Предпросмотр без звука'
                                  : widget.hasAudio
                                  ? 'Аудиодорожка есть'
                                  : 'Аудиодорожки нет',
                            ),
                            _DiagnosticRow(
                              label: 'Последнее измерение',
                              value: sampledAt == null
                                  ? 'Нет свежих данных'
                                  : _formatTime(sampledAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: CompositedTransformTarget(
            key: _summaryKey,
            link: _summaryLink,
            child: Tooltip(
              message: sampleStatus,
              child: Semantics(
                button: true,
                expanded: _popoverOpen,
                label: 'Статистика',
                hint: _sampleStatus,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _togglePopover,
                    borderRadius: BorderRadius.circular(GcRadii.sm),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: GcColors.border),
                        borderRadius: BorderRadius.circular(GcRadii.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: hasMetrics
                                    ? GcColors.success
                                    : GcColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Статистика',
                            style: TextStyle(
                              color: GcColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _screenShareTargetProfile(String? trackName) {
  final match = RegExp(r'^screenshare-(720|1080|1440)p-(15|30|60)fps$')
      .firstMatch(trackName ?? '');
  return match == null
      ? 'Нет данных от источника'
      : '${match.group(1)}p · ${match.group(2)} FPS';
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: GcColors.muted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: GcColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

List<Widget> _senderRows(ScreenShareSenderReport? report) => [
  _DiagnosticRow(
    label: 'Отправляется',
    value: report?.frameWidth == null || report?.frameHeight == null
        ? 'Нет данных'
        : '${report!.frameWidth} × ${report.frameHeight}',
  ),
  _DiagnosticRow(
    label: 'Кодируется',
    value: _formatMetric(report?.encodedFps, 'FPS'),
  ),
  _DiagnosticRow(
    label: 'Отправлено',
    value: _formatMetric(report?.bitrateKbps, 'кбит/с'),
  ),
  _DiagnosticRow(
    label: 'RTT',
    value: _formatMetric(report?.roundTripTimeMs, 'мс'),
  ),
];

String _formatResolution(ScreenReceiverSnapshot? sample) {
  if (sample == null ||
      !_finiteNonNegative(sample.frameWidth) ||
      !_finiteNonNegative(sample.frameHeight)) {
    return 'Нет данных';
  }
  final fps = _finiteNonNegative(sample.framesPerSecond)
      ? ' · ${sample.framesPerSecond!.round()} FPS'
      : '';
  return '${sample.frameWidth!.round()} × ${sample.frameHeight!.round()}$fps';
}

String _formatMetric(double? value, [String unit = '']) {
  if (!_finiteNonNegative(value)) return 'Нет данных';
  final rendered = value! % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return unit.isEmpty ? rendered : '$rendered $unit';
}

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

String? _boundedReceiverDetail(String? value) {
  final normalized = value?.trim().replaceAll(
    RegExp(r'[\u0000-\u001f\u007f]'),
    '',
  );
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.length <= 64
      ? normalized
      : '${normalized.substring(0, 61)}…';
}

bool _finiteNonNegative(double? value) =>
    value != null && value.isFinite && value >= 0;
