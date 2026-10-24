import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import 'stop.dart';
import 'phase.dart';
export 'phase.dart';
export 'retry.dart';
export 'events.dart';
export 'watch.dart';
export 'refresh.dart';
export 'stop.dart';
export 'stale.dart';
export '../../../services/api_client.dart' show ApiFailure;

class VoiceRosterController extends ChangeNotifier {
  VoiceRosterController(
    this.api,
    this.scope, {
    required this.isReady,
    required this.hasUser,
    required this.message,
    this.retryDelay = const Duration(seconds: 2),
    this.staleTimeout = const Duration(seconds: 10),
    this.retryBudget = 6,
    Timer Function(Duration, void Function())? schedule,
    double Function()? jitter,
  }) : schedule = schedule ?? Timer.new,
       jitter = jitter ?? Random().nextDouble;
  final ApiClient api;
  final SessionScope scope;
  final bool Function() isReady;
  final bool Function() hasUser;
  final String Function(Object) message;
  final Duration retryDelay;
  final Duration staleTimeout;
  List<VoiceRoomRoster>? voiceRosters;
  String? voiceRosterError;
  DateTime? lastUpdatedAt;
  StreamSubscription<String>? subscription;
  Completer<void>? streamDone;
  Timer? retryTimer;
  Timer? staleTimer;
  Completer<void>? retryDone;
  bool watching = false;
  bool loading = false;
  bool disposed = false;
  int revision = 0;
  int refreshRevision = 0;
  int retryAttempt = 0;
  bool opening = false;
  final int retryBudget;
  final Timer Function(Duration, void Function()) schedule;
  final double Function() jitter;
  VoiceRosterPhase phase = VoiceRosterPhase.initialLoading;
  bool get canRetry =>
      !disposed &&
      !opening &&
      hasUser() &&
      isReady() &&
      scope.capture().isActive &&
      (phase == VoiceRosterPhase.stale ||
          phase == VoiceRosterPhase.unavailable);
  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    stop();
    super.dispose();
  }
}
