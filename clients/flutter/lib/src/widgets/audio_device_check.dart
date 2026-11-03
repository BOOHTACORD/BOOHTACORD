import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_device_check.dart';
import '../theme.dart';

class AudioDeviceCheck extends StatefulWidget {
  const AudioDeviceCheck({
    super.key,
    required this.inputDeviceId,
    required this.inputDeviceLabel,
    required this.outputDeviceId,
    required this.outputDeviceLabel,
    this.serviceFactory,
  });

  final String? inputDeviceId;
  final String? inputDeviceLabel;
  final String? outputDeviceId;
  final String? outputDeviceLabel;
  final AudioDeviceCheckService Function()? serviceFactory;

  @override
  State<AudioDeviceCheck> createState() => _AudioDeviceCheckState();
}

class _AudioDeviceCheckState extends State<AudioDeviceCheck> {
  late final AudioDeviceCheckService _service;
  StreamSubscription<double>? _levelSubscription;
  double _level = 0;
  bool _inputActive = false;
  bool _inputBusy = false;
  bool _outputBusy = false;
  String? _inputState;
  String? _outputState;
  int _inputGeneration = 0;
  int _outputGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceFactory?.call() ?? NativeAudioDeviceCheckService();
  }

  @override
  void didUpdateWidget(covariant AudioDeviceCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inputDeviceId != widget.inputDeviceId ||
        oldWidget.inputDeviceLabel != widget.inputDeviceLabel) {
      unawaited(_stopMicrophone());
    }
    if (oldWidget.outputDeviceId != widget.outputDeviceId ||
        oldWidget.outputDeviceLabel != widget.outputDeviceLabel) {
      _outputGeneration++;
      _outputState = null;
    }
  }

  @override
  void dispose() {
    _inputGeneration++;
    unawaited(_disposeService());
    super.dispose();
  }

  Future<void> _disposeService() async {
    await _levelSubscription?.cancel();
    await _service.dispose();
  }

  Future<void> _toggleMicrophone() async {
    if (_inputBusy) return;
    if (_inputActive) {
      await _stopMicrophone();
      return;
    }
    final generation = ++_inputGeneration;
    setState(() {
      _inputBusy = true;
      _inputState = 'Запрашиваем доступ к микрофону…';
    });
    try {
      final levels = await _service.startMicrophone(
        deviceId: widget.inputDeviceId,
        deviceLabel: widget.inputDeviceLabel,
      );
      if (!mounted || generation != _inputGeneration) {
        await _service.stopMicrophone();
        return;
      }
      _levelSubscription = levels.listen(
        (level) {
          if (!mounted || generation != _inputGeneration) return;
          setState(() => _level = level.clamp(0, 1).toDouble());
        },
        onError: (_) {
          if (!mounted || generation != _inputGeneration) return;
          setState(() {
            _inputActive = false;
            _level = 0;
            _inputState = 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.';
          });
          unawaited(_service.stopMicrophone());
        },
        onDone: () {
          if (!mounted || generation != _inputGeneration) return;
          setState(() {
            _inputActive = false;
            _level = 0;
            _inputState = 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.';
          });
          _levelSubscription = null;
          unawaited(_service.stopMicrophone());
        },
      );
      setState(() {
        _inputActive = true;
        _level = 0;
        _inputState = 'Говорите, чтобы увидеть уровень микрофона.';
      });
    } catch (cause) {
      if (generation == _inputGeneration) {
        final message = cause is AudioDeviceCheckFailure
            ? cause.message
            : 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.';
        setState(() {
          _inputActive = false;
          _level = 0;
          _inputState = message;
        });
      }
      await _service.stopMicrophone();
    } finally {
      if (mounted && generation == _inputGeneration) {
        setState(() => _inputBusy = false);
      }
    }
  }

  Future<void> _stopMicrophone() async {
    final generation = ++_inputGeneration;
    if (mounted) {
      setState(() {
        _inputBusy = true;
        _inputActive = false;
        _level = 0;
        _inputState = null;
      });
    }
    try {
      await _levelSubscription?.cancel();
    } catch (_) {}
    _levelSubscription = null;
    try {
      await _service.stopMicrophone();
    } catch (_) {}
    if (mounted && generation == _inputGeneration) {
      setState(() => _inputBusy = false);
    }
  }

  Future<void> _checkSpeaker() async {
    if (_outputBusy) return;
    final generation = ++_outputGeneration;
    setState(() {
      _outputBusy = true;
      _outputState = 'Воспроизводим короткий сигнал…';
    });
    try {
      await _service.playSpeaker(
        deviceId: widget.outputDeviceId,
        deviceLabel: widget.outputDeviceLabel,
      );
      if (!mounted || generation != _outputGeneration) return;
      setState(
        () => _outputState = 'Сигнал воспроизведён. Если его не слышно, проверьте громкость динамика.',
      );
    } catch (cause) {
      if (!mounted || generation != _outputGeneration) return;
      setState(
        () => _outputState = cause is AudioDeviceCheckFailure
            ? cause.message
            : 'Не удалось воспроизвести сигнал.',
      );
    } finally {
      if (mounted) setState(() => _outputBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Проверка звука на этом устройстве',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _inputBusy ? null : _toggleMicrophone,
              icon: Icon(_inputActive ? Icons.stop : Icons.mic_none),
              label: Text(
                _inputActive
                    ? 'Остановить проверку микрофона'
                    : 'Проверить микрофон',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _outputBusy ? null : _checkSpeaker,
              icon: _outputBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up_outlined),
              label: const Text('Тестовый звук'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_inputState != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _inputState!,
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Semantics(
          label: 'Уровень микрофона',
          value: '${(_level * 100).round()}%',
          child: LinearProgressIndicator(
            value: _level,
            minHeight: 7,
            backgroundColor: GcColors.content,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        if (_outputState != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _outputState!,
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            title: const Text('О проверке устройств'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: const [
              Text(
                'Проверка локальная: она не подтверждает слышимость у другого участника.',
                style: TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
