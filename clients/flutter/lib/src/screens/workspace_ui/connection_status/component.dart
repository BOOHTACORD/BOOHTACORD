import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/voice/lifecycle/types.dart';
import '../../../features/voice/roster_state/controller.dart';
import '../../../theme.dart';

class WorkspaceConnectionStatus extends StatefulWidget {
  const WorkspaceConnectionStatus({
    super.key,
    required this.chatConnected,
    required this.chatConnecting,
    required this.voicePhase,
    required this.rosterPhase,
    required this.rosterRetained,
    required this.lastUpdatedAt,
    required this.rosterCanRetry,
    required this.onRetryChat,
    required this.onRetryRoster,
  });

  final bool chatConnected;
  final bool chatConnecting;
  final VoicePhase voicePhase;
  final VoiceRosterPhase rosterPhase;
  final bool rosterRetained;
  final DateTime? lastUpdatedAt;
  final bool rosterCanRetry;
  final VoidCallback onRetryChat;
  final VoidCallback onRetryRoster;

  @override
  State<WorkspaceConnectionStatus> createState() =>
      _WorkspaceConnectionStatusState();
}

class _WorkspaceConnectionStatusState extends State<WorkspaceConnectionStatus> {
  Timer? _ageTimer;
  DateTime _now = DateTime.now();

  bool get _visible =>
      !widget.chatConnected ||
      widget.rosterPhase != VoiceRosterPhase.fresh ||
      widget.voicePhase == VoicePhase.joining ||
      widget.voicePhase == VoicePhase.reconnecting ||
      widget.voicePhase == VoicePhase.error;

  @override
  void initState() {
    super.initState();
    _syncAgeTimer();
  }

  @override
  void didUpdateWidget(covariant WorkspaceConnectionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAgeTimer();
  }

  void _syncAgeTimer() {
    final shouldTick = _visible && widget.lastUpdatedAt != null;
    if (shouldTick && _ageTimer == null) {
      _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!shouldTick) {
      _ageTimer?.cancel();
      _ageTimer = null;
    }
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final chatTone = widget.chatConnected
        ? _StatusTone.connected
        : _StatusTone.reconnecting;
    final voiceTone = switch (widget.voicePhase) {
      VoicePhase.connected || VoicePhase.listener => _StatusTone.voice,
      VoicePhase.joining || VoicePhase.reconnecting => _StatusTone.reconnecting,
      VoicePhase.error => _StatusTone.unavailable,
      _ => _StatusTone.inactive,
    };
    final rosterTone = switch (widget.rosterPhase) {
      VoiceRosterPhase.fresh => _StatusTone.connected,
      VoiceRosterPhase.stale when widget.rosterRetained =>
        _StatusTone.reconnecting,
      VoiceRosterPhase.initialLoading => _StatusTone.reconnecting,
      VoiceRosterPhase.sessionExpired => _StatusTone.unavailable,
      _ => _StatusTone.unavailable,
    };

    final rosterLabel = switch (widget.rosterPhase) {
      VoiceRosterPhase.fresh => 'Состав обновлён',
      VoiceRosterPhase.stale when widget.rosterRetained => 'Состав устарел',
      VoiceRosterPhase.initialLoading => 'Загружаем состав',
      VoiceRosterPhase.sessionExpired => 'Сессия завершена',
      _ => 'Состав недоступен',
    };
    final lastUpdatedAt = widget.lastUpdatedAt;
    final age = lastUpdatedAt == null
        ? ''
        : ' · ${_now.difference(lastUpdatedAt).inSeconds.clamp(0, 1 << 31)} с. назад';

    return Container(
      key: const ValueKey('connection-status-card'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GcColors.surface,
        border: Border.all(color: GcColors.borderSubtle),
        borderRadius: BorderRadius.circular(GcRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectionStatusItem(
            key: const ValueKey('connection-status-chat'),
            label: widget.chatConnected ? 'Чат подключён' : 'Чат обновляется',
            tone: chatTone,
            liveRegion: true,
          ),
          const SizedBox(height: 8),
          if (!widget.chatConnected) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _ConnectionStatusAction(
                label: 'Повторить связь чата',
                icon: Icons.refresh_rounded,
                onPressed: widget.chatConnecting ? null : widget.onRetryChat,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _ConnectionStatusItem(
            key: const ValueKey('connection-status-voice'),
            label: switch (widget.voicePhase) {
              VoicePhase.connected || VoicePhase.listener => 'Голос подключён',
              VoicePhase.joining ||
              VoicePhase.reconnecting => 'Голос восстанавливается',
              _ => 'Голос не подключён',
            },
            tone: voiceTone,
            liveRegion: true,
          ),
          const SizedBox(height: 8),
          _ConnectionStatusItem(
            key: const ValueKey('connection-status-roster'),
            label: '$rosterLabel$age',
            tone: rosterTone,
            liveRegion: false,
          ),
          if (widget.rosterPhase == VoiceRosterPhase.stale ||
              widget.rosterPhase == VoiceRosterPhase.unavailable) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _ConnectionStatusAction(
                label: 'Обновить состав',
                icon: Icons.refresh_rounded,
                onPressed: widget.rosterCanRetry ? widget.onRetryRoster : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StatusTone { connected, voice, reconnecting, unavailable, inactive }

class _ConnectionStatusItem extends StatelessWidget {
  const _ConnectionStatusItem({
    super.key,
    required this.label,
    required this.tone,
    required this.liveRegion,
  });

  final String label;
  final _StatusTone tone;
  final bool liveRegion;

  Color get _color => switch (tone) {
    _StatusTone.connected => GcColors.success,
    _StatusTone.voice => GcColors.voice,
    _StatusTone.reconnecting => GcColors.warning,
    _StatusTone.unavailable => GcColors.danger,
    _StatusTone.inactive => GcColors.muted,
  };

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          liveRegion: liveRegion,
          child: Text(
            label,
            softWrap: true,
            style: const TextStyle(
              color: GcColors.textSecondary,
              fontSize: GcTypography.small,
              height: 1.35,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ConnectionStatusAction extends StatelessWidget {
  const _ConnectionStatusAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, softWrap: true),
      style: TextButton.styleFrom(
        foregroundColor: GcColors.text,
        backgroundColor: GcColors.raised,
        disabledForegroundColor: GcColors.disabled,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: GcColors.borderSubtle),
          borderRadius: BorderRadius.circular(GcRadii.sm),
        ),
      ),
    ),
  );
}
