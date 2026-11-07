import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/http/transport.dart';
import '../../../core/session/scope.dart';
import '../join_sound/api.dart';
import '../sound_preferences/api.dart';
import '../sound_preferences/controller.dart';
import '../sound_preferences/fence.dart';
import '../sound_preferences/storage.dart';
import '../sound_preferences/legacy.dart';
import 'native.dart';
import 'queue.dart';

class VoiceSoundRuntime extends ChangeNotifier {
  VoiceSoundRuntime(
    this.transport,
    this.scope,
    this.deafened,
    this.output,
    this.outputLabel,
  );
  final ApiTransport transport;
  final SessionScope scope;
  final bool Function() deafened;
  final String? Function() output, outputLabel;
  final player = NativeSoundPlayer();
  LegacySoundReview legacy = LegacySoundReview();

  VoiceSoundController? preferences;
  JoinSoundApi? api;
  SessionTicket? _ticket;
  int _generation = 0;
  Timer? _refresh;
  late final queue = NativeSoundQueue(
    allows,
    (id) => api!.download(id),
    (kind, bytes, current) => player.play(
      kind,
      bytes,
      preferences!.settings['volume'] as int,
      output(),
      outputLabel(),
      current,
    ),
    player.stop,
  );
  bool get active => _ticket?.isActive == true;
  Future<void> bind(String account) async {
    clear();
    final generation = _generation;
    _ticket = scope.capture();
    final currentLegacy = legacy = LegacySoundReview();
    await currentLegacy.select(transport.session.baseUrl, account);
    if (!active || generation != _generation) return;
    api = JoinSoundApi(transport, account);
    preferences = VoiceSoundController(
      VoiceSoundPreferencesApi(transport, account),
      SoundPreferenceFence(
        SharedSoundFenceStorage(),
        transport.session.baseUrl,
        account,
      ),
      () => active && generation == _generation,
    );
    preferences!.addListener(_changed);
    await preferences!.load();
    if (active && generation == _generation) {
      _refresh = Timer.periodic(
        const Duration(seconds: 15),
        (_) => preferences?.load(),
      );
    }
  }

  void _changed() {
    queue.clear();
    notifyListeners();
  }

  void clear() {
    _refresh?.cancel();
    _refresh = null;
    _generation++;
    _ticket = null;
    queue.clear();
    preferences?.removeListener(_changed);
    preferences?.dispose();
    preferences = null;
    api = null;
  }

  bool allows(String kind) =>
      active &&
      !legacy.blocked &&
      !deafened() &&
      preferences?.settings['enabled'] == true &&
      preferences?.settings[kind] == true;
  void silence() => queue.clear();
  void submit(String kind, {String? custom}) => queue.submit(
    kind,
    custom: preferences?.settings['allow_custom'] == true ? custom : null,
  );
  Future<void> preview(String id) => queue.preview(id);
  Future<void> reviewLegacy(bool quiet) async {
    final current = legacy;
    if (await current.review(preferences, quiet) &&
        identical(current, legacy) &&
        active) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
