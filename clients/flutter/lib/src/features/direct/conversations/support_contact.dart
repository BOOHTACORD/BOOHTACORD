import 'dart:collection';

import '../../../models.dart';

class SupportContact {
  const SupportContact({
    this.state = 'not_configured',
    this.revision = 0,
    this.accountId,
  });
  final String state;
  final int revision;
  final String? accountId;
  bool get available => state == 'available' && accountId != null;
  bool matches(String peer) => available && peer == accountId;
  factory SupportContact.fromJson(dynamic raw) {
    if (raw is! Map) return const SupportContact();
    final revision = raw['revision'];
    final state = raw['state'];
    final account = raw['account_id'];
    if (revision is! int || revision < 0) {
      return const SupportContact(state: 'unavailable');
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
      );
    }
    if (state == 'self' ||
        state == 'not_configured' ||
        state == 'unavailable') {
      return SupportContact(state: state, revision: revision);
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

const supportPrompt =
    'Опишите проблему или предложение. Можно прикрепить скриншот';
const supportPrivacy =
    'Сообщения видит назначенная поддержка этого сервера. Для исправления ошибок команда может создать публичную техническую задачу без вашего текста и файлов.';
