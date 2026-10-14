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

  test('real supermoney receipt, OCR lines as read on Android', () {
    // Captured from ML Kit on an emulator: the bold ₹ comes out as "T".
    const raw = 'SUPER|29 // SUper.|56 // móney|78 // Payment Successful|46 // '
        'T81|90 // October 13 at 10:51 AM|40 // To: BROADWAY|34 // '
        'gpay-11265455695@okbizaxis|43 // T Axis Bank|41 // '
        'From: ASIF MUHAMMADN|34 // XXXXXX8311a@superyes|48 // '
        'UPI reference ID: 665280079818|40 // Super.|16 // móney|27 // '
        'LPID/YES BANK|44 // Get assured cashback on UPI spends|39';
    final r = parseBill([
      for (final l in raw.split(' // '))
        (text: l.split('|')[0], height: double.parse(l.split('|')[1])),
    ], now: now);
    expect(r.amount, 81);
    expect(r.payee, 'Broadway');
    expect(r.date, DateTime(2026, 10, 13, 10, 51));
    expect(r.income, isFalse);
    expect(r.ref, '665280079818');
    expect(r.note, isNull);
    expect(billNote(r), 'Broadway (Txn: 665280079818)');
  });

  test('reference numbers: UPI ref, UTR, next-line IDs', () {
    expect(parseBillText('UPI reference ID: 665280079818').ref, '665280079818');
    expect(parseBillText('UTR: 427812345678').ref, '427812345678');
    expect(parseBillText('UPI transaction ID\n628512345678').ref,
        '628512345678');
    expect(parseBillText('Transaction ID T2410131051ABC').ref,
        'T2410131051ABC');
    expect(parseBillText('UPI transaction ID\nCopy').ref, isNull);
  });

  test("the payer's note fills the note field, with the reference", () {
    final r = parseBillText('''
Paid to
Bavarchi Restaurant
₹40
Message: Tea at bavarchi
UPI Ref No: 3544454990448''', now: now);
    expect(r.note, 'Tea at bavarchi');
    expect(billNote(r), 'Tea at bavarchi (Txn: 3544454990448)');
  });

  test('no note: payee name plus reference; nothing: empty', () {
    BillScan b({String? note, String? payee, String? ref}) => (
          amount: null,
          payee: payee,
          date: null,
          income: false,
          category: null,
          note: note,
          ref: ref,
        );
    expect(billNote(b(payee: 'Broadway', ref: '665280079818')),
        'Broadway (Txn: 665280079818)');
    expect(billNote(b(payee: 'Broadway')), 'Broadway');
    expect(billNote(b(ref: '665280079818')), 'Txn: 665280079818');
    expect(billNote(b()), '');
  });

  test('AI reply note and reference', () {
    final r = billFromAi({
      'amount': 40,
      'payee': 'Bavarchi',
      'date': '',
      'income': false,
      'category': '',
      'note': 'Tea at bavarchi',
      'reference': '3544 4549 90448',
    }, keys: const {}, now: now);
    expect(r.note, 'Tea at bavarchi');
    expect(r.ref, '3544454990448');
    expect(billFromAi({'reference': 'not an id!'}, keys: const {}).ref, isNull);
  });

  test('unrelated image gives nothing', () {
    final r = parseBillText('Happy birthday!\nSee you today', now: now);
    expect(r.amount, isNull);
    expect(r.payee, isNull);
    expect(r.date, isNull);
    expect(r.income, isFalse);
  });
}
