import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/message_presentation.dart';

void main() {
  test('TEXT and DM grouping share author, day, reply, delivery and unread boundaries', () {
    final date = DateTime(2026, 10, 21, 10);
    bool grouped({String author = 'a', DateTime? at, bool boundary = false}) =>
        canGroupConversationMessage(
          previousAuthor: 'a',
          author: author,
          previousDate: date,
          date: at ?? date.add(const Duration(minutes: 1)),
          boundary: boundary,
        );
    expect(grouped(), true);
    expect(grouped(author: 'b'), false);
    expect(grouped(at: date.add(const Duration(minutes: 6))), false);
    expect(grouped(at: date.subtract(const Duration(seconds: 1))), false);
    expect(grouped(at: date.add(const Duration(days: 1))), false);
    expect(grouped(boundary: true), false);
  });
}
