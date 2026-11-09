import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import 'stop.dart';
import 'phase.dart';
export 'phase.dart';
export 'retry.dart';
export 'watch.dart';
export 'refresh.dart';
export 'stop.dart';
export 'stale.dart';
export 'socket.dart';

class VoiceRosterController extends ChangeNotifier {
  VoiceRosterController(
    this.scope, {
    required this.isReady,
    required this.hasUser,
    this.staleTimeout = const Duration(seconds: 10),
    this.onSharedRetry,
    Timer Function(Duration, void Function())? schedule,
  }) : schedule = schedule ?? Timer.new;
  final SessionScope scope;
  final bool Function() isReady;
  final bool Function() hasUser;
  final Duration staleTimeout;
  List<VoiceRoomRoster>? voiceRosters;
  String? voiceRosterError;
  DateTime? lastUpdatedAt;
  Timer? staleTimer;
  bool watching = false;
  bool disposed = false;
  int revision = 0;
  final void Function()? onSharedRetry;
  bool sharedOpen = false;
  String? sharedGeneration;
  int sharedRevision = 0;
  SessionTicket? sharedTicket;
  Timer? initialTimer;
  final Timer Function(Duration, void Function()) schedule;
  VoiceRosterPhase phase = VoiceRosterPhase.initialLoading;
  bool get canRetry =>
      !disposed &&
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
