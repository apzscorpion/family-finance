import 'package:family_finance/v3/sheets/v3_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shares = V3AddSheet.computeShares;

  test('just the payer: nobody owes anything', () {
    expect(shares(amount: 100, payer: 'me', selected: {'me'}), isNull);
  });

  test('one other person owes the full amount', () {
    expect(shares(amount: 100, payer: 'me', selected: {'wife'}),
        {'wife': 100});
  });

  test('full split is equal across everyone selected', () {
    expect(shares(amount: 300, payer: 'me', selected: {'me', 'a', 'b'}),
        {'me': 100, 'a': 100, 'b': 100});
  });

  test('partial in rupees: my part comes off, others split the rest', () {
    expect(
      shares(
          amount: 100,
          payer: 'me',
          selected: {'me', 'a', 'b'},
          partial: true,
          myPart: 10),
      {'a': 45, 'b': 45, 'me': 10},
    );
  });

  test('partial in percent, payer not selected', () {
    expect(
      shares(
          amount: 200,
          payer: 'me',
          selected: {'a', 'b'},
          partial: true,
          myPart: 10,
          myPartIsPct: true),
      {'a': 90, 'b': 90},
    );
  });

  test('my part larger than the bill is capped', () {
    expect(
      shares(
          amount: 50,
          payer: 'me',
          selected: {'me', 'a'},
          partial: true,
          myPart: 80),
      {'a': 0, 'me': 50},
    );
  });
}
