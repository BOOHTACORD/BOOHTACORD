import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/update_notice.dart';

void main() {
  test('Windows explains an automatic same-source FPS restart', () {
    final notice = screenShareUpdateNotice(TargetPlatform.windows);

    expect(notice, contains('FPS'));
    expect(notice, contains('автоматически'));
    expect(notice, contains('тем же источником'));
    expect(notice, contains('Голос останется подключён'));
    expect(notice, contains('кодирования'));
  });

  test('macOS and Android explain capture restart and platform consent', () {
    final macOS = screenShareUpdateNotice(TargetPlatform.macOS);
    final android = screenShareUpdateNotice(TargetPlatform.android);

    expect(macOS, contains('захвата'));
    expect(macOS, contains('остановите и снова запустите'));
    expect(android, contains('захвата'));
    expect(android, contains('разрешение'));
  });

  test('iOS does not claim that an encoder update restarts capture', () {
    final notice = screenShareUpdateNotice(TargetPlatform.iOS);

    expect(notice, contains('кодирования'));
    expect(notice, isNot(contains('остановите')));
  });
}
