import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'public_support_fixture.dart';

class OwnedTls extends HttpOverrides {
  OwnedTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4810 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native assigned support ordinary DM text file and real operator reply',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      expect(origin, 'https://localhost:4810/api/v1');
      expect(pin.length, 64);
      expect(password, isNotEmpty);
      HttpOverrides.global = OwnedTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final preferences = await SharedPreferences.getInstance();
      expect(await preferences.setString('server_url', origin), isTrue);
      final api = ApiClient();
      final state = AppState(api);
      addTearDown(state.dispose);
      await tester.pumpWidget(BoohtacordApp(state: state));
      await tester.runAsync(state.initialize);
      debugPrint('support_qa_phase=initialized');
      await tester.pump(const Duration(milliseconds: 500));
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(milliseconds: 500));
      }
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'qa_support_a');
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      for (var i = 0; i < 120 && state.phase != AppPhase.ready; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(state.phase, AppPhase.ready);
      debugPrint('support_qa_phase=authenticated');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Помощь и обратная связь'));
      for (
        var i = 0;
        i < 120 &&
            (state.supportOpening || state.selectedDirectMessage == null);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.supportAvailable, isTrue);
      debugPrint('support_qa_phase=contact_ready');
      final pair = state.selectedDirectMessage!;
      expect(state.isSupportConversation(pair), isTrue);
      expect(find.text('Поддержка').hitTestable(), findsOneWidget);
      final composer = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Написать сообщение…',
      );
      if (const bool.fromEnvironment('QA_PRODUCT_SUPPORT')) {
        expect(state.supportContact.product, isTrue);
        expect(state.supportContact.consentRequired, isTrue);
        expect(composer, findsNothing);
        expect(find.textContaining('общедоступны'), findsOneWidget);
        await binding.takeScreenshot('native-public-support-consent');
        await tester.tap(find.text('Согласен на публикацию'));
        for (var i = 0; i < 120 && state.supportContact.consentRequired; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(state.supportContact.consentRequired, isFalse);
        expect(composer, findsOneWidget);
        expect(find.textContaining('общедоступны'), findsOneWidget);
        await binding.takeScreenshot('native-public-support-consented');
        const marker = String.fromEnvironment('QA_PUBLIC_MARKER');
        if (marker.isNotEmpty) {
          await verifyPublicSupportBridge(
            tester,
            binding,
            state,
            api,
            pair.id,
            marker,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(state.logout);
        await tester.pump(const Duration(milliseconds: 500));
        return;
      }
      await binding.takeScreenshot('native-support-pair-empty');
      await tester.enterText(composer, 'Synthetic native request');
      await tester.pump();
      await tester.tap(find.byTooltip('Отправить личное сообщение'));
      for (
        var i = 0;
        i < 120 &&
            !state.directMessageHistory.any(
              (m) => m.body == 'Synthetic native request',
            );
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        state.directMessageHistory.any(
          (m) => m.body == 'Synthetic native request',
        ),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('native-support-pair-sent');
      await tester.runAsync(() async {
        final file = await api.uploadDirectMessageAttachment(
          pair.id,
          'synthetic-native.txt',
          Uint8List.fromList(utf8.encode('synthetic fixture')),
        );
        await api.sendDirectMessage(
          pair.id,
          '55555555-5555-4555-8555-555555555555',
          'Synthetic native file',
          attachmentIds: [file.id],
        );
        await state.openDirectConversation(pair);
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('synthetic-native.txt'), findsOneWidget);
      final operator = HttpClient();
      addTearDown(() => operator.close(force: true));
      await tester.runAsync(() async {
        final login = await operator.postUrl(Uri.parse('$origin/auth/login'));
        login.headers.set('origin', 'https://localhost:4810');
        login.headers.contentType = ContentType.json;
        login.write(
          jsonEncode({'login': 'qa_support_s', 'password': password}),
        );
        final signed = await login.close();
        expect(signed.statusCode, 204);
        final cookies = signed.cookies;
        await signed.drain<void>();
        final reply = await operator.postUrl(
          Uri.parse('$origin/direct-messages/${pair.id}/messages'),
        );
        reply.headers.set('origin', 'https://localhost:4810');
        reply.cookies.addAll(cookies);
        reply.headers.contentType = ContentType.json;
        reply.write(
          jsonEncode({
            'client_message_id': '66666666-6666-4666-8666-666666666666',
            'body': 'Synthetic native operator reply',
          }),
        );
        final sent = await reply.close();
        expect(sent.statusCode, 201);
        await sent.drain<void>();
      });
      for (
        var i = 0;
        i < 120 &&
            !state.directMessageHistory.any(
              (m) => m.body == 'Synthetic native operator reply',
            );
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        state.directMessageHistory.any(
          (m) => m.body == 'Synthetic native operator reply',
        ),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('native-support-pair-replied');
      final same = await tester.runAsync(state.openSupport);
      expect(same, isTrue);
      expect(state.selectedDirectMessage?.id, pair.id);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Открыть навигацию'));
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('native-support-pair-pinned');
      expect(tester.takeException(), isNull);
      await tester.runAsync(state.logout);
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.phase, AppPhase.signedOut);
    },
  );
}
