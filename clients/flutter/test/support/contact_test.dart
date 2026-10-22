import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/support_contact.dart';

void main() {
  test('only server-confirmed active other account receives support alias', () {
    const peer = '22222222-2222-4222-8222-222222222222';
    final contact = SupportContact.fromJson({
      'state': 'available',
      'account_id': peer,
      'revision': 3,
    });
    expect(contact.accountId, peer);
    for (final state in ['self', 'unavailable', 'not_configured']) {
      expect(
        SupportContact.fromJson({
          'state': state,
          'account_id': peer,
          'revision': 3,
        }).accountId,
        isNull,
      );
    }
    expect(
      SupportContact.fromJson({
        'state': 'available',
        'account_id': 'Поддержка',
        'revision': 3,
      }).accountId,
      isNull,
    );
  });
}
