import 'package:family_finance/v3/data/card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads last 4 and the later expiry, ignores non-card numbers', () {
    final r = parseCardText('''
HDFC BANK
Customer care 1800 202 6161
4111 1111 1111 1111
VALID FROM 03/21  VALID THRU 08/2029
ASIF M N''');
    expect(r.last4, '1111');
    expect(r.expiry, '08/29');
  });

  test('nothing card-like gives nulls', () {
    final r = parseCardText('1234 5678 9012 3456\n13/25');
    expect(r.last4, isNull); // fails Luhn
    expect(r.expiry, isNull); // month 13
  });
}
