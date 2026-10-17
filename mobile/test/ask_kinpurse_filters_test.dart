import 'package:family_finance/v3/data/ai/ask_kinpurse_engine.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:flutter_test/flutter_test.dart';

TxnRow _t(String id, double amount, {String src = 'sal', Map<String, double> shares = const {}}) =>
    TxnRow(
      id: id,
      familyId: 'f',
      userId: 'me',
      paidBy: 'me',
      sourceId: src,
      title: id,
      amount: amount,
      type: 'expense',
      shares: shares,
      occurredAt: DateTime(2026, 10, 10),
    );

void main() {
  final txns = [
    _t('solo', 100),
    _t('tea with sinu', 20, shares: {'me': 10, 'sinu': 10}),
    _t('loan shared', 500, src: 'loan', shares: {'sinu': 500}),
  ];
  const sources = [
    SourceRow(id: 'sal', name: 'Salary', kind: 'income', openingBalance: 0, sortOrder: 0),
    SourceRow(id: 'loan', name: 'Loan', kind: 'loan', openingBalance: 0, sortOrder: 1),
  ];

  AskKinPurseResult run(Map<String, dynamic> q) => AskKinPurseEngine.executeLocally(
        AskKinPurseQuery.fromJson({'intent': 'sum', 'explanation': 'x', ...q}),
        txns,
        const [],
        const [],
        sources: sources,
      );

  test('"for or with others" counts only shared entries', () {
    expect(run({'shared_with_others': true}).primaryAmount, 520);
  });

  test('"exclude loan account" leaves the Loan account out', () {
    expect(run({'shared_with_others': true, 'exclude_account': 'loan'}).primaryAmount, 20);
    expect(run({'account': 'Salary'}).primaryAmount, 120);
  });

  test('help answers keep only actions the app knows', () {
    final q = AskKinPurseQuery.fromJson({
      'intent': 'help',
      'explanation': 'x',
      'setting': 'app_lock',
      'turn_on': false,
      'open': 'nowhere',
      'theme': 'pink',
      'text_size': 'large',
    });
    expect(q.setting, 'app_lock');
    expect(q.turnOn, false);
    expect(q.open, isNull);
    expect(q.theme, isNull);
    expect(q.textSize, 'large');
  });
}
