import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/workspace/load_members/controller.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/members_panel/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';

import 'local_qa_test.dart' show QaTls;
import 'profile_revision/fixture.dart';
import 'profile_revision/delayed_client.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real native profile revisions, protected avatars and account boundaries',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError('Owned QA endpoint and pin required');
      }
      HttpOverrides.global = QaTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final report = <String, Object?>{
        'issue': 276,
        'status': 'RUNNING',
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'build_mode': 'Debug',
        'roles': ['MEMBER', 'MEMBER', 'ADMIN'],
        'mocks': false,
        'controlled_fault': 'hold actual finite HTTP responses, leave streaming transports unchanged',
        'checks': <String, String>{},
      };
      final checks = report['checks'] as Map<String, String>;
      binding.reportData = {...?binding.reportData, 'profile_revision_qa': report};
      var phase = 'real fixture sessions';
      final native = DelayedClient();
      final api = ApiClient(client: native);
      final state = AppState(api);
      final admin = FixtureSession(origin),
          self = FixtureSession(origin),
          peer = FixtureSession(origin),
          anonymous = FixtureSession(origin);
      addTearDown(() {
        state.dispose();
        native.close();
        admin.close();
        self.close();
        peer.close();
        anonymous.close();
      });
      Future<T> real<T>(Future<T> Function() operation) async =>
          (await tester.runAsync<T>(operation)) as T;
      Future<void> waitFor(bool Function() condition, String label) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        expect(condition(), true, reason: label);
        await tester.pump();
      }

      Future<void> signIn(String name) async {
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), name);
        await tester.enterText(fields.at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Войти').last);
        await waitFor(
          () => state.phase == AppPhase.ready && state.profile != null,
          'native authenticated profile ready',
        );
      }

      Future<void> closeNav() async {
        final close = find.byTooltip('Закрыть навигацию').hitTestable();
        if (close.evaluate().isNotEmpty) {
          await tester.tap(close.first);
          await tester.pumpAndSettle();
        }
      }

      Future<void> showProfile() async {
        await closeNav();
        if (state.workspacePanel != WorkspacePanel.profile) {
          state.toggleWorkspacePanel(WorkspacePanel.profile);
        }
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
      }

      String editorName() => tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(ProfileScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.labelText == 'Отображаемое имя',
              ),
            ),
          )
          .controller!
          .text;
      Future<void> capture(String name) async {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      try {
        await real(() => admin.login('qa_admin', password));
        final a = await real(
          () => admin.json(
            'POST',
            '/auth/register',
            body: {'login': 'qa_profile_a', 'password': password},
            status: 201,
          ),
        );
        final b = await real(
          () => admin.json(
            'POST',
            '/auth/register',
            body: {'login': 'qa_profile_b', 'password': password},
            status: 201,
          ),
        );
        final aId = a['id'] as String, bId = b['id'] as String;
        await real(() => self.login('qa_profile_a', password));
        await real(() => peer.login('qa_profile_b', password));
        await real(() => self.rename('Тестовый профиль A'));
        await real(() => peer.rename('Тестовый профиль B'));
        final category = await real(
          () => admin.json(
            'POST',
            '/admin/categories',
            body: {'name': 'QaProfiles'},
            status: 201,
          ),
        );
        await real(
          () => admin.json(
            'POST',
            '/admin/categories/${category['id']}/channels',
            body: {'name': 'QaProfiles', 'kind': 'TEXT'},
            status: 201,
          ),
        );
        await real(
          () => self.json(
            'POST',
            '/direct-messages',
            body: {'participant_id': bId},
            status: 201,
          ),
        );
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('server_url', origin);
        await tester.pumpWidget(BoohtacordApp(state: state));
        await real(state.initialize);
        await tester.pumpAndSettle();
        expect(state.phase, AppPhase.signedOut);
        if (Platform.isAndroid) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        await signIn('qa_profile_a');
        await closeNav();
        await waitFor(
          () =>
              state.members.any((m) => m.id == bId) &&
              state.directMessages.isNotEmpty,
          'real members and DM navigation loaded',
        );
        final channel = state.topology!.categories
            .expand((c) => c.channels)
            .firstWhere((c) => c.name == 'QaProfiles');
        await real(() => state.selectChannel(channel));
        await tester.pumpAndSettle();
        final conversation = state.directMessages.firstWhere(
          (d) => d.participantId == bId,
        );
        await real(() => state.openDirectConversation(conversation));
        await tester.pumpAndSettle();
        phase = 'remote peer rename updates open DM and roster without restart';
        await real(() => peer.rename('Профиль B обновлён'));
        await waitFor(
          () =>
              state.members.any(
                (m) => m.id == bId && m.displayName == 'Профиль B обновлён',
              ) &&
              state.selectedDirectMessage?.displayName ==
                  'Профиль B обновлён',
          'peer hint updates current DM and roster',
        );
        expect(find.text('Профиль B обновлён').evaluate().isNotEmpty, true);
        await capture('peer-renamed-open-dm');
        checks['remote_peer_name_roster_open_DM'] = 'PASS';
        phase = 'own editor refresh and older me response';
        await showProfile();
        final ownHold = native.holdNext((u) => u.path == '/api/v1/me');
        final oldOwn = state.refreshProfile();
        await waitFor(
          () => ownHold.captured.isCompleted,
          'older own profile captured',
        );
        final newOwn = await real(() => self.rename('Профиль A обновлён'));
        await waitFor(
          () =>
              state.profile?.displayName == 'Профиль A обновлён' &&
              state.profileOwner.profileRevision == newOwn['profile_revision'],
          'newer own response accepted before older release',
        );
        ownHold.release.complete();
        await real(() => oldOwn);
        await tester.pumpAndSettle();
        expect(state.profile?.displayName == 'Профиль A обновлён', true);
        expect(editorName() == 'Профиль A обновлён', true);
        expect(
          (state.profileOwner.profileRevision ?? 0) > (ownHold.revision ?? 0),
          true,
        );
        await capture('own-editor-newer-me-retained');
        checks['own_editor_and_out_of_order_me'] = 'PASS';
        phase = 'older member response cannot overwrite newer members page';
        final previousMember = state.members.firstWhere((m) => m.id == bId);
        final oldMemberRevision = memberProfileRevisions.memberRevision(
          previousMember,
        )!;
        final memberHold = native.holdNext(
          (u) => u.path == '/api/v1/members/$bId',
        );
        final oldMember = state.workspace.refreshMemberProfile(
          bId,
          oldMemberRevision + 1,
        );
        await waitFor(
          () => memberHold.captured.isCompleted,
          'older member reply captured',
        );
        final newPeer = await real(() => peer.rename('Профиль B актуальный'));
        await real(state.refreshMembers);
        await waitFor(
          () => state.members.any(
            (m) => m.id == bId && m.displayName == 'Профиль B актуальный',
          ),
          'newer roster metadata accepted',
        );
        memberHold.release.complete();
        await real(() => oldMember);
        await tester.pumpAndSettle();
        final retained = state.members.firstWhere((m) => m.id == bId);
        expect(retained.displayName == 'Профиль B актуальный', true);
        expect(
          memberProfileRevisions.memberRevision(retained) ==
              newPeer['profile_revision'],
          true,
        );
        checks['out_of_order_member_highest_revision'] = 'PASS';
        phase = 'real protected peer avatar upload replace clear';
        state.showChannels();
        await real(() => state.selectChannel(channel));
        await tester.pumpAndSettle();
        final members = find.byTooltip('Открыть участников').hitTestable();
        expect(members.evaluate().isNotEmpty, true);
        await tester.tap(members.first);
        await tester.pumpAndSettle();
        Finder peerAvatar() => find.byWidgetPredicate(
          (w) => w is AuthenticatedAvatar && w.name == 'Профиль B актуальный',
        );
        Future<bool> paintedDigest(String expected) async {
          final images = find
              .descendant(of: peerAvatar(), matching: find.byType(Image))
              .evaluate();
          return images.any(
            (e) =>
                (e.widget as Image).image is MemoryImage &&
                sha256
                        .convert(
                          ((e.widget as Image).image as MemoryImage).bytes,
                        )
                        .toString() ==
                    expected,
          );
        }

        final rosterScroll = find.descendant(of: find.byType(WorkspaceMembersPanel), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(peerAvatar(), 250, scrollable: rosterScroll, maxScrolls: 40);
        await tester.pumpAndSettle();
        Future<void> waitDecodedAvatar(List<int> encoded, String label) async {
          final expected = await real(() async {
            final codec = await ui.instantiateImageCodec(Uint8List.fromList(encoded));
            final frame = await codec.getNextFrame();
            final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
            final digest = sha256.convert(bytes!.buffer.asUint8List()).toString();
            frame.image.dispose(); codec.dispose(); return digest;
          });
          var matches = false;
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!matches && DateTime.now().isBefore(deadline)) {
            await tester.pump();
            final rendered = find.descendant(of: peerAvatar(), matching: find.byType(RawImage)).evaluate();
            for (final element in rendered) {
              final image = (element.widget as RawImage).image;
              if (image == null) continue;
              final actual = await real(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
              if (actual != null && sha256.convert(actual.buffer.asUint8List()).toString() == expected) matches = true;
            }
            if (!matches) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          }
          expect(matches, true, reason: label);
        }
        await real(() => peer.upload(solidAvatar(20, 190, 60)));
        final greenProfile = await real(() => peer.json('GET', '/me'));
        await waitFor(
          () => state.members.any(
            (m) =>
                m.id == bId &&
                memberProfileRevisions.memberRevision(m) ==
                    greenProfile['profile_revision'] &&
                m.avatarUrl != null,
          ),
          'new avatar metadata received',
        );
        final green = await real(
          () => self.request(
            'GET',
            '/members/$bId/avatar?revision=${greenProfile['profile_revision']}',
          ),
        );
        expect(green.statusCode, 200);
        final greenDigest = sha256.convert(green.bodyBytes).toString();
        await tester.ensureVisible(peerAvatar().first);
        await tester.pumpAndSettle();
        for (var i = 0; i < 400 && !await paintedDigest(greenDigest); i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        report['avatar_probe'] = {
          'matching_avatar_widgets': peerAvatar().evaluate().length,
          'image_provider_types': find.descendant(of: peerAvatar(), matching: find.byType(Image)).evaluate().map((e) => (e.widget as Image).image.runtimeType.toString()).toList(),
        };
        if (!await paintedDigest(greenDigest)) {
          await capture('avatar-probe-failure');
        }
        expect(await paintedDigest(greenDigest), true);
        await tester.ensureVisible(peerAvatar().first);
        await waitDecodedAvatar(green.bodyBytes, 'uploaded avatar decoded in native renderer');
        await capture('peer-avatar-uploaded-roster');
        await real(() => peer.upload(solidAvatar(30, 80, 220)));
        final blueProfile = await real(() => peer.json('GET', '/me'));
        await waitFor(
          () => state.members.any(
            (m) =>
                m.id == bId &&
                memberProfileRevisions.memberRevision(m) ==
                    blueProfile['profile_revision'],
          ),
          'replacement revision received',
        );
        final blue = await real(
          () => self.request(
            'GET',
            '/members/$bId/avatar?revision=${blueProfile['profile_revision']}',
          ),
        );
        expect(blue.statusCode, 200);
        final blueDigest = sha256.convert(blue.bodyBytes).toString();
        expect(blueDigest != greenDigest, true);
        for (var i = 0; i < 400 && !await paintedDigest(blueDigest); i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        expect(await paintedDigest(blueDigest), true);
        await waitDecodedAvatar(blue.bodyBytes, 'replacement avatar decoded in native renderer');
        await capture('peer-avatar-replaced-roster');
        final deleted = await real(() => peer.request('DELETE', '/me/avatar'));
        expect([200, 204].contains(deleted.statusCode), true);
        await waitFor(
          () => state.members.any((m) => m.id == bId && m.avatarUrl == null),
          'cleared avatar metadata received',
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: peerAvatar(), matching: find.byType(Image)),
          findsNothing,
        );
        await capture('peer-avatar-cleared-roster');
        checks['remote_avatar_upload_replace_clear_and_render'] = 'PASS';
        final avatarRequests = native.events
            .where(
              (e) =>
                  e['route'] == 'protected_avatar' && e.containsKey('status'),
            )
            .toList();
        expect(
          avatarRequests.isNotEmpty &&
              avatarRequests.every((e) => e['revision_query_present'] == true),
          true,
        );
        checks['authenticated_same_origin_revision_avatar_route'] = 'PASS';
        phase = 'logout clears revision state and delayed protected avatar';
        final closeMembers = find.byTooltip('Закрыть участников').hitTestable();
        if (closeMembers.evaluate().isNotEmpty) {
          await tester.tap(closeMembers.first);
          await tester.pumpAndSettle();
        }
        await real(() => peer.upload(solidAvatar(30, 80, 220)));
        for (var i = 0; i < 6; i++) {
          await real(() => self.rename('Тестовый профиль A ${i + 1}'));
        }
        await real(() => self.upload(solidAvatar(20, 190, 60)));
        final aProfile = await real(() => self.json('GET', '/me'));
        await waitFor(
          () =>
              state.profileOwner.profileRevision ==
                  aProfile['profile_revision'] &&
              state.profile?.avatarUrl != null,
          'highest own metadata observed',
        );
        final oldUrl = state.profile!.avatarUrl!;
        final oldRevision = state.profileOwner.profileRevision!;
        final avatarHold = native.holdNext(
          (u) => u.path == '/api/v1/members/$aId/avatar',
        );
        final oldAvatarAccepted = api
            .avatarBytes(oldUrl)
            .then((_) => true, onError: (Object _) => false);
        await waitFor(
          () => avatarHold.captured.isCompleted,
          'actual protected avatar reply held',
        );
        await real(state.logout);
        await tester.pumpAndSettle();
        expect(state.phase, AppPhase.signedOut);
        expect(
          state.profileOwner.profileRevision == null &&
              state.members.isEmpty &&
              state.directMessages.isEmpty,
          true,
        );
        await capture('logout-cleared');
        await signIn('qa_profile_b');
        await showProfile();
        avatarHold.release.complete();
        expect(await real(() => oldAvatarAccepted), false);
        expect(
          state.profile?.accountId == bId &&
              state.profile?.displayName == 'Профиль B актуальный',
          true,
        );
        expect(
          (state.profileOwner.profileRevision ?? oldRevision) < oldRevision,
          true,
        );
        expect(editorName() == 'Профиль B актуальный', true);
        await capture('new-account-profile-no-old-state');
        checks['logout_account_switch_lower_revision_and_avatar_fence'] =
            'PASS';
        phase = 'real avatar ACL without active membership';
        final before = await real(
          () => self.request('GET', '/members/$bId/avatar'),
        );
        expect(before.statusCode, 200);
        final blocked = await real(
          () => admin.request(
            'PATCH',
            '/admin/accounts/$aId',
            body: {'role': 'MEMBER', 'blocked': true},
          ),
        );
        expect([200, 204].contains(blocked.statusCode), true);
        final denied = await real(
          () => self.request('GET', '/members/$bId/avatar'),
        );
        expect([401, 403, 404].contains(denied.statusCode), true);
        final anon = await real(
          () => anonymous.request('GET', '/members/$bId/avatar'),
        );
        expect([401, 403, 404].contains(anon.statusCode), true);
        report['avatar_acl_statuses'] = {
          'active_member': before.statusCode,
          'blocked_member': denied.statusCode,
          'anonymous': anon.statusCode,
        };
        checks['avatar_denied_without_active_membership'] = 'PASS';
        await real(state.logout);
        await tester.pumpAndSettle();
        report['status'] = 'PASS';
        report['timeline'] = native.events;
      } catch (cause, trace) {
        report['status'] = 'FAIL';
        report['failed_phase'] = phase;
        report['failure_type'] = cause.runtimeType.toString();
        report['failed_source_line'] = RegExp(r'profile_revision_qa_test.dart:(\d+)').firstMatch(trace.toString())?.group(1);
        report['timeline'] = native.events;
        throw StateError('Sanitized #276 native acceptance failure at $phase');
      } finally {
        binding.reportData = {...?binding.reportData, 'profile_revision_qa': report};
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
