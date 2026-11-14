import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_preferences.dart';
import 'native_noise_suppression_state.dart';
import 'native_noise_model_preflight.dart';
import 'native_noise_auto_research.dart';
export 'native_noise_suppression_state.dart';

part 'native_noise_prepare.dart';
part 'native_noise_fallback.dart';
part 'native_noise_state_read.dart';
part 'native_noise_monitor.dart';
part 'native_noise_research_debug.dart';

typedef NativeNoiseInvoker = Future<Object?> Function(
  String method,
  Map<String, Object?>? arguments,
);

/// PCM remains in the hook; Dart exchanges bounded aggregate state only.
abstract class _NativeNoiseCore extends ChangeNotifier {
  _NativeNoiseCore({
    NativeNoiseInvoker? invoke,
    bool? allowExperimentalDeepFilter,
  }) : _invoke = invoke ?? _defaultInvoke,
       _allowDeepFilter = kDebugMode && allowExperimentalDeepFilter != null
           ? allowExperimentalDeepFilter
           : !kIsWeb &&
                 defaultTargetPlatform == TargetPlatform.windows &&
                 const bool.fromEnvironment('BOOHTA_EXPERIMENTAL_DEEPFILTER');
  static const _channel = MethodChannel('FlutterWebRTC.Method');
  static Future<Object?> _defaultInvoke(
    String method,
    Map<String, Object?>? arguments,
  ) => _channel.invokeMethod<Object?>(method, arguments);
  final NativeNoiseInvoker _invoke;
  Future<void> _tail = Future.value();
  int _queued = 0;
  int _generation = 0;
  bool _disposed = false, _fallback = false, _polling = false;
  bool _allowDeepFilter;
  NoiseSuppressionMode _selectedMode = NoiseSuppressionMode.browser;
  NoiseSuppressionMode _debugAutoMode = researchAutoEngine(
    const String.fromEnvironment('BOOHTA_RESEARCH_AUTO_ENGINE'),
    debug: kDebugMode,
    windows: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
  );

  @visibleForTesting
  void debugAllowDeepFilter() {
    assert(() {
      _allowDeepFilter = true;
      return true;
    }());
  }

  Timer? _timer;
  NativeNoiseSuppressionState state = const NativeNoiseSuppressionState();
  Future<void> refresh();
  void _read(Map value);
  Future<T> run<T>(Future<T> Function() operation) {
    final next = _queued++ == 0
        ? Future<T>.sync(operation)
        : _tail.catchError((_) {}).then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next.whenComplete(() => _queued--);
  }

  Future<Object?> _call(String method, [Map<String, Object?>? arguments]) =>
      _invoke(method, arguments).timeout(const Duration(milliseconds: 350));
  void _update(NativeNoiseSuppressionState value) {
    if (!_disposed) {
      state = value;
      notifyListeners();
    }
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _fallback = false;
    _update(NativeNoiseSuppressionState(requestedMode: state.requestedMode));
    unawaited(
      _invoke(
        'resetNoiseSuppression',
        null,
      ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    super.dispose();
  }
}

class NativeNoiseSuppression extends _NativeNoiseCore
    with
        _NativeNoiseStateRead,
        _NativeNoisePrepare,
        _NativeNoiseFallback,
        _NativeNoiseMonitor,
        _NativeNoiseResearchDebug {
  NativeNoiseSuppression({super.invoke, super.allowExperimentalDeepFilter});
}
