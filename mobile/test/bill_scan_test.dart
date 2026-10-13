import 'package:family_finance/v3/data/bill_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12);

  test('GPay style: name on the line after "To", 12-hour time', () {
    final r = parseBillText('''
To RAHUL KUMAR
₹500
Completed
12 Oct 2026, 9:52 pm
UPI transaction ID
628512345678
To: RAHUL KUMAR
rahul@okaxis''', now: now);
    expect(r.amount, 500);
    expect(r.payee, 'Rahul Kumar');
    expect(r.date, DateTime(2026, 10, 12, 21, 52));
    expect(r.income, isFalse);
  });

  test('PhonePe style: label then name, rupee lost by OCR', () {
    final r = parseBillText('''
Transaction Successful
09:15 am on 05 Oct 2026
Paid to
Fresh Mart Supermarket
?1,250.50
UTR: 427812345678''', now: now);
    expect(r.amount, 1250.5);
    expect(r.payee, 'Fresh Mart Supermarket');
    expect(r.date, DateTime(2026, 10, 5, 9, 15));
  });

  test('CRED style: Rs prefix, UPI id skipped for the name', () {
    final r = parseBillText('''
payment successful
paid to swiggy@icici
Swiggy
Rs. 349
Oct 3, 2026''', now: now);
    expect(r.amount, 349);
    expect(r.payee, 'Swiggy');
    expect(r.date, DateTime(2026, 10, 3));
  });

  test('screenshot: status-bar clock and battery, cashback in small print',
      () {
    final r = parseBill([
      (text: '9:52', height: 12), // status bar clock
      (text: '94', height: 12), // battery
      (text: 'Paid to', height: 16),
      (text: 'Anitha Stores', height: 22),
      (text: '₹2,340', height: 60), // headline
      (text: 'You won ₹15 cashback', height: 14),
      (text: '8 Oct 2026', height: 14),
    ], now: now);
    expect(r.amount, 2340);
    expect(r.payee, 'Anitha Stores');
    expect(r.date, DateTime(2026, 10, 8)); // not 9:52 from the status bar
  });

  test('received money is income, payer taken from "from"', () {
    final r = parseBillText('''
Received from
PRIYA S
₹1,000
11 Oct, 7:05 PM''', now: now);
    expect(r.income, isTrue);
    expect(r.payee, 'Priya S');
    expect(r.amount, 1000);
    // No year: this year, as it isn't in the future.
    expect(r.date, DateTime(2026, 10, 11, 19, 5));
  });

  test('dates: no-year in the future means last year; invalid dates skipped',
      () {
    expect(parseBillText('20 Dec', now: now).date, DateTime(2025, 12, 20));
    expect(parseBillText('31 Feb 2026', now: now).date, isNull);
    expect(parseBillText('13/10/2026 10:00', now: now).date,
        DateTime(2026, 10, 13, 10));
    expect(parseBillText('Oct 2026', now: now).date, isNull);
  });

  test('unrelated image gives nothing', () {
    final r = parseBillText('Happy birthday!\nSee you today', now: now);
    expect(r.amount, isNull);
    expect(r.payee, isNull);
    expect(r.date, isNull);
    expect(r.income, isFalse);
  });
}
