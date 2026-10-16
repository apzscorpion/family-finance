import 'package:family_finance/v3/data/chat_media.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chatMediaPath', () {
    const a = '0a000000-0000-4000-8000-000000000001';
    const b = 'ff000000-0000-4000-8000-000000000002';

    test('sorts the pair so both sides build the same folder', () {
      final p1 = chatMediaPath(
        familyId: 'fam',
        userA: a,
        userB: b,
        messageId: 'msg',
        fileName: 'bill.pdf',
      );
      final p2 = chatMediaPath(
        familyId: 'fam',
        userA: b,
        userB: a,
        messageId: 'msg',
        fileName: 'bill.pdf',
      );
      expect(p1, 'fam/${a}_$b/msg/bill.pdf');
      expect(p2, p1);
      // Storage policies read folders 1..3; the name must add no folders.
      expect(p1.split('/'), hasLength(4));
    });

    test('file name cannot add folders or odd characters', () {
      final p = chatMediaPath(
        familyId: 'fam',
        userA: a,
        userB: b,
        messageId: 'msg',
        fileName: '../secret/Ration card (1).pdf',
      );
      expect(p.split('/'), hasLength(4));
      expect(p.split('/').last, 'secret_Ration_card_1_.pdf');
    });
  });

  test('safeChatFileName keeps the extension when trimming', () {
    expect(safeChatFileName(''), 'file');
    expect(safeChatFileName('മലയാളം'), 'file');
    final long = safeChatFileName('${'x' * 200}.docx');
    expect(long.length, 80);
    expect(long.endsWith('.docx'), isTrue);
  });

  test('formatChatBytes', () {
    expect(formatChatBytes(512), '512 B');
    expect(formatChatBytes(2048), '2 KB');
    expect(formatChatBytes(5 * 1024 * 1024 + 300000), '5.3 MB');
  });

  test('formatChatDuration', () {
    expect(formatChatDuration(Duration.zero), '0:00');
    expect(formatChatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatChatDuration(const Duration(minutes: 2, seconds: 5)), '2:05');
  });

  test('chatMediaBody', () {
    expect(chatMediaBody(kind: 'voice', name: 'v.m4a'), '🎤 Voice message');
    expect(chatMediaBody(kind: 'image', name: 'a.jpg'), '📷 Photo');
    expect(chatMediaBody(kind: 'image', name: 'a.jpg', caption: ' hi '), 'hi');
    expect(chatMediaBody(kind: 'file', name: 'bill.pdf'), '📎 bill.pdf');
    expect(
      chatMediaBody(kind: 'image', name: 'a.jpg', viewOnce: true, caption: 'x'),
      '👁 View once photo',
    );
  });

  test('chatMimeFor prefers the reported type', () {
    expect(chatMimeFor('a.PDF'), 'application/pdf');
    expect(chatMimeFor('a.pdf', 'application/x-custom'), 'application/x-custom');
    expect(chatMimeFor('noext'), 'application/octet-stream');
  });

  test('DirectMessageRow round-trips media fields; old rows still parse', () {
    final row = DirectMessageRow.fromJson({
      'id': 'm1',
      'family_id': 'f',
      'sender_id': 'a',
      'recipient_id': 'b',
      'body': '📎 bill.pdf',
      'kind': 'file',
      'created_at': '2026-10-16T10:00:00Z',
      'media_path': 'f/a_b/m1/bill.pdf',
      'media_name': 'bill.pdf',
      'media_mime': 'application/pdf',
      'media_size': 1234,
      'media_kind': 'file',
      'view_once': false,
    });
    expect(row.hasMedia, isTrue);
    expect(row.isImage, isFalse);
    final back = DirectMessageRow.fromJson(row.toJson());
    expect(back.mediaPath, row.mediaPath);
    expect(back.mediaSize, 1234);
    expect(back.copyWith(viewedAt: DateTime.now()).mediaPath, row.mediaPath);

    final legacy = DirectMessageRow.fromJson({
      'id': 'm0',
      'body': '📷 Photo',
      'kind': 'image',
      'image_data': 'aGk=',
      'created_at': '2026-10-01T10:00:00Z',
    });
    expect(legacy.isImage, isTrue);
    expect(legacy.hasMedia, isFalse);
    expect(legacy.viewOnce, isFalse);
  });
}
