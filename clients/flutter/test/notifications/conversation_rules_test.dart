import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/notifications/settings/rule_changes.dart';

void main() {
  test('reset selected conversation inherits its base without clearing other rules or account consent', () {
    final settings = <String, dynamic>{
      'enabled': true,
      'overrides': [
        {'kind': 'CHANNEL', 'id': 'a', 'mode': 'none'},
        {'kind': 'DIRECT_MESSAGE', 'id': 'b', 'mode': 'none'},
      ],
    };
    resetConversationNotificationRule(settings, 'CHANNEL', 'a');
    expect((settings['overrides'] as List).single['id'], 'b');
    expect(settings['enabled'], true);
    setConversationNotificationRule(settings, 'CHANNEL', 'a', 'mentions', null);
    expect((settings['overrides'] as List).length, 2);
    expect((settings['overrides'] as List).first['id'], 'b');
  });
}
