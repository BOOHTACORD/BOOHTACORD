import '../models.dart';

class PresentedMessage {
  const PresentedMessage({
    required this.message,
    required this.showDate,
    required this.dateLabel,
    required this.grouped,
  });

  final ChatMessage message;
  final bool showDate;
  final String dateLabel;
  final bool grouped;
}

class ConversationTimelineEntry {
  const ConversationTimelineEntry.date(this.dateLabel)
    : message = null,
      grouped = false;
  const ConversationTimelineEntry.message(this.message, this.grouped)
    : dateLabel = null;

  final ChatMessage? message;
  final String? dateLabel;
  final bool grouped;
}

const _russianMonths = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String conversationDateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_russianMonths[local.month - 1]} ${local.year}';
}

bool sameConversationDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

bool canGroupConversationMessage({
  required String? previousAuthor,
  required String author,
  required DateTime? previousDate,
  required DateTime date,
  bool boundary = false,
}) {
  if (boundary ||
      previousAuthor != author ||
      previousDate == null ||
      !sameConversationDay(previousDate, date))
    return false;
  final gap = date.difference(previousDate);
  return !gap.isNegative && gap <= const Duration(minutes: 5);
}

List<PresentedMessage> presentMessages(List<ChatMessage> messages) {
  final result = <PresentedMessage>[];
  ChatMessage? previous;
  for (final message in messages) {
    final date = message.createdAt.toLocal();
    final previousDate = previous?.createdAt.toLocal();
    final startsDate =
        previousDate == null ||
        date.year != previousDate.year ||
        date.month != previousDate.month ||
        date.day != previousDate.day;
    final grouped = canGroupConversationMessage(
      previousAuthor: previous?.authorId,
      author: message.authorId,
      previousDate: previous?.createdAt,
      date: message.createdAt,
      boundary:
          previous == null ||
          previous.kind == 'SYSTEM_WELCOME' ||
          message.kind == 'SYSTEM_WELCOME' ||
          previous.replyToId != null ||
          message.replyToId != null ||
          previous.deleted ||
          message.deleted ||
          previous.sendStatus != null ||
          message.sendStatus != null,
    );
    result.add(
      PresentedMessage(
        message: message,
        showDate: startsDate,
        dateLabel: conversationDateLabel(date),
        grouped: grouped,
      ),
    );
    previous = message;
  }
  return result;
}

List<ConversationTimelineEntry> messageTimeline(List<ChatMessage> messages) {
  final entries = <ConversationTimelineEntry>[];
  for (final presented in presentMessages(messages)) {
    if (presented.showDate) {
      entries.add(ConversationTimelineEntry.date(presented.dateLabel));
    }
    entries.add(
      ConversationTimelineEntry.message(presented.message, presented.grouped),
    );
  }
  return entries;
}
