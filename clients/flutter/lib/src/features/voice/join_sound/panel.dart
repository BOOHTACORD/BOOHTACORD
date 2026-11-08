import 'package:flutter/material.dart';

import '../sound_playback/runtime.dart';
import 'controls.dart';
import 'selection.dart';
import '../sound_preferences/legacy_panel.dart';

class JoinSoundPanel extends StatefulWidget {
  const JoinSoundPanel({super.key, required this.runtime});
  final VoiceSoundRuntime runtime;
  @override
  State<JoinSoundPanel> createState() => _JoinSoundPanelState();
}

class _JoinSoundPanelState extends State<JoinSoundPanel> {
  Map<String, dynamic>? _sound;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _run(() => widget.runtime.api!.current());
  }

  Future<void> _run(Future<Map<String, dynamic>?> Function() action) async {
    final api = widget.runtime.api;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (mounted &&
          identical(api, widget.runtime.api) &&
          widget.runtime.active) {
        setState(() => _sound = result);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Мелодия недоступна. Нужен MP3, WAV или OGG, 0,3–3 секунды и до 2 МиБ. Повторная загрузка — через 10 секунд.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final api = widget.runtime.api;
    await _run(() async {
      final bytes = await chooseJoinSoundFile();
      if (bytes == null ||
          !mounted ||
          !identical(api, widget.runtime.api) ||
          !widget.runtime.active)
        return _sound;
      return api!.upload(bytes);
    });
  }

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.runtime.preview(_sound!['id'] as String);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось воспроизвести мелодию. Проверьте выбранный аудиовыход.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.runtime.silence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime,
    builder: (context, _) => Column(
      children: [
        LegacySoundReviewPanel(runtime: widget.runtime),
        JoinSoundControls(
          sound: _sound,
          busy: _busy,
          error: _error,
          audible: widget.runtime.allows('joined'),
          upload: _upload,
          preview: _preview,
          enable: (value) => _run(() => widget.runtime.api!.enable(value)),
          remove: () => _run(() => widget.runtime.api!.remove()),
        ),
      ],
    ),
  );
}
