import 'package:family_finance/v3/data/v3_models.dart';
import 'package:flutter_test/flutter_test.dart';

DirectMessageRow _m(Map<String, dynamic> extra) => DirectMessageRow.fromJson({
      'id': '1',
      'family_id': 'f',
      'sender_id': 'a',
      'recipient_id': 'b',
      'body': 'hi',
      'created_at': '2026-10-16T10:00:00Z',
      ...extra,
    });

void main() {
  test('sent, delivered, read like WhatsApp', () {
    final sent = _m({});
    expect(sent.isDelivered, isFalse);
    expect(sent.isRead, isFalse);
    final delivered = _m({'delivered_at': '2026-10-16T10:00:01Z'});
    expect(delivered.isDelivered, isTrue);
    expect(delivered.isRead, isFalse);
    // Read implies delivered, even for rows from before delivered_at existed.
    final read = _m({'read_at': '2026-10-16T10:00:05Z'});
    expect(read.isDelivered, isTrue);
    expect(read.isRead, isTrue);
    expect(sent.copyWith(deliveredAt: DateTime(2026)).isDelivered, isTrue);
  });
}
