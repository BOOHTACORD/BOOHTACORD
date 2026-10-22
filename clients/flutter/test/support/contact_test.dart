import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/support_contact.dart';

void main() {
  test(
    'old product history retains its public warning after a local override',
    () {
      const peer = '22222222-2222-4222-8222-222222222222';
      final contact = SupportContact.fromJson({
        'state': 'available',
        'revision': 3,
        'account_id': '33333333-3333-4333-8333-333333333333',
        'product_account_id': peer,
        'mode': 'local',
        'repository_public': true,
      });
      expect(contact.isProductPeer(peer), isTrue);
      expect(contact.privacyFor(peer), contains('общедоступны'));
    },
  );
  test(
    'product support fails closed and keeps its public notice during outages',
    () {
      const peer = '22222222-2222-4222-8222-222222222222';
      final contact = SupportContact.fromJson({
        'state': 'unavailable',
        'revision': 2,
        'account_id': peer,
        'mode': 'product',
        'notice_version': 1,
        'repository_public': true,
        'consent_required': true,
      });
      expect(contact.product, isTrue);
      expect(contact.consentRequired, isTrue);
      expect(contact.matches(peer), isTrue);
      expect(contact.privacyNotice, contains('общедоступны'));
      expect(
        SupportContact.fromJson({
          'state': 'available',
          'revision': 2,
          'account_id': peer,
          'mode': 'product',
          'notice_version': 0,
          'consent_required': false,
        }).consentRequired,
        isTrue,
      );
    },
  );
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
