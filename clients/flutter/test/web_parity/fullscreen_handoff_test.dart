import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/screen_fullscreen_route.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/widgets/screen_video_renderer_slot.dart';

class _Room extends Room {
  final members = <String, RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(members);
}

class _State extends AppState {
  _State(this.testRoom) : super(ApiClient());
  final Room testRoom;
  @override
  Room get room => testRoom;
}

int _active = 0, _peak = 0;

class _Renderer extends StatefulWidget {
  const _Renderer(this.label);
  final String label;
  @override
  State<_Renderer> createState() => _RendererState();
}

class _RendererState extends State<_Renderer> {
  @override
  void initState() {
    super.initState();
    _active++;
    if (_active > _peak) _peak = _active;
  }

  @override
  void dispose() {
    _active--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  for (final ended in [false, true]) {
    testWidgets(
      'mini fullscreen renderer handoff, ${ended ? 'publication ended' : 'user close'}',
      (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        _active = _peak = 0;
        final room = _Room();
        // ignore: invalid_use_of_internal_member
        final created = await RemoteParticipant.createFromInfo(
          room: room,
          info: lk.ParticipantInfo(
            sid: 'remote-sid',
            identity: 'remote',
            tracks: [
              lk.TrackInfo(
                sid: 'screen',
                type: lk.TrackType.VIDEO,
                source: lk.TrackSource.SCREEN_SHARE,
                muted: false,
              ),
            ],
          ),
        );
        room.members['remote'] = created.participant;
        final app = _State(room);
        Object? selected;
        Future<void>? presentation;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => Column(
                  children: [
                    if (selected == null) const _Renderer('mini'),
                    TextButton(
                      onPressed: () {
                        presentation = presentScreenFullscreen(
                          context: context,
                          state: app,
                          publisherIdentity: 'remote',
                          generation: const ScreenViewerPublicationGeneration(
                            participantIdentity: 'remote',
                            publicationSid: 'screen',
                          ),
                          onSelectionChanged: (value) =>
                              update(() => selected = value),
                          content: (lease, target) => Material(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: ScreenFullscreenRendererGate(
                                    lease: lease,
                                    child: const _Renderer('fullscreen'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(target),
                                  child: const Text('close'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text('expand'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('expand'));
        await t.pumpAndSettle();
        expect(find.text('fullscreen'), findsOneWidget);
        expect(find.text('mini'), findsNothing);
        expect(_active, 1);
        expect(_peak, 1);
        if (ended) {
          room.members.clear();
          app.notifyListeners();
        } else {
          await t.tap(find.text('close'));
        }
        await t.pumpAndSettle();
        await presentation;
        expect(selected, isNull);
        expect(find.text('fullscreen'), findsNothing);
        expect(_active, 1);
        expect(_peak, 1);
        await t.pumpWidget(const SizedBox.shrink());
        expect(_active, 0);
        app.dispose();
        await t.runAsync(room.dispose);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
