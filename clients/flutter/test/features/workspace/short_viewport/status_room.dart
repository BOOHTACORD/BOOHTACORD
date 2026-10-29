import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

class StatusRoom extends Fake implements Room {
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(const {});
  @override
  LocalParticipant? get localParticipant => null;
  @override
  Future<void> disconnect() async {}
}
