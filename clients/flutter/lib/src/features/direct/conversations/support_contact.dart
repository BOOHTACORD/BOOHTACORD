import 'dart:collection';

import '../../../models.dart';
import 'support_presentation.dart';
export 'support_presentation.dart';

class SupportContact {
  const SupportContact({
    this.state = 'not_configured',
    this.revision = 0,
    this.accountId,
    this.productAccountId,
    this.mode = 'local',
    this.noticeVersion = 0,
    this.consentRequired = false,
    this.repositoryPublic = true,
  });
  final String state;
  final int revision;
  final String? accountId, productAccountId;
  final String mode;
  final int noticeVersion;
  final bool consentRequired, repositoryPublic;
  bool get product => mode == 'product';
  bool isProductPeer(String peer) =>
      productAccountId == peer || product && accountId == peer;
  String privacyFor(String peer) => isProductPeer(peer)
      ? productSupportPrivacy(repositoryPublic)
      : privacyNotice;
  String get privacyNotice =>
      product ? productSupportPrivacy(repositoryPublic) : supportPrivacy;
  SupportContact get unavailable => SupportContact(
    state: 'unavailable',
    revision: revision,
    accountId: product ? accountId : null,
    productAccountId: productAccountId,
    mode: mode,
    noticeVersion: noticeVersion,
    consentRequired: consentRequired,
    repositoryPublic: repositoryPublic,
  );
  bool get available => state == 'available' && accountId != null;
  bool matches(String peer) =>
      isProductPeer(peer) || (available && peer == accountId);
  factory SupportContact.fromJson(dynamic raw) {
    if (raw is! Map) return const SupportContact();
    final revision = raw['revision'];
    final state = raw['state'];
    final account = raw['account_id'];
    final rawProduct = raw['product_account_id'];
    final productId =
        rawProduct is String &&
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(rawProduct)
        ? rawProduct
        : null;
    if (revision is! int || revision < 0) {
      return const SupportContact(state: 'unavailable');
    }
    if (raw['mode'] == 'product') {
      final value = raw['notice_version'];
      final notice = value is int && value > 0 ? value : 0;
      final id =
          account is String &&
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ).hasMatch(account)
          ? account
          : null;
      return SupportContact(
        state: state == 'available' && id != null && notice > 0
            ? 'available'
            : 'unavailable',
        revision: revision,
        accountId: id,
        productAccountId: productId,
        mode: 'product',
        noticeVersion: notice,
        repositoryPublic: raw['repository_public'] != false,
        consentRequired: notice == 0 || raw['consent_required'] != false,
      );
    }
    if (state == 'available' &&
        revision > 0 &&
        account is String &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(account)) {
      return SupportContact(
        state: state,
        revision: revision,
        accountId: account,
        productAccountId: productId,
        repositoryPublic: raw['repository_public'] != false,
      );
    }
    if (state == 'self' ||
        state == 'not_configured' ||
        state == 'unavailable') {
      return SupportContact(
        state: state,
        revision: revision,
        productAccountId: productId,
        repositoryPublic: raw['repository_public'] != false,
      );
    }
    return SupportContact(state: 'unavailable', revision: revision);
  }
  String get unavailableMessage => state == 'self'
      ? 'Вы назначены поддержкой этого сервера. Отвечайте пользователям в обычных личных диалогах.'
      : state == 'not_configured'
      ? 'Поддержка этого сервера пока не назначена.'
      : 'Поддержка этого сервера сейчас недоступна. Повторите позже.';
}

class DirectNavigation extends UnmodifiableListView<DirectConversation> {
  DirectNavigation(super.items, {required this.support});
  final SupportContact support;
}
