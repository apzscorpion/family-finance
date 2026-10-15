import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

V3State _state() => V3State(V3Repository(SupabaseClient(
      'https://example.supabase.co',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    )));

TxnRow _txn(double amount, String method, {String type = 'expense'}) => TxnRow(
      id: 't-$amount-$method',
      familyId: 'f1',
      sourceId: 'loan',
      title: 'x',
      amount: amount,
      type: type,
      method: method,
      categoryKey: 'groceries',
      occurredAt: DateTime(2026, 10, 1),
    );

void main() {
  test('cash entries move cash, other methods move bank, moves shift both',
      () {
    final s = _state()
      ..sources = [
        const SourceRow(
            id: 'loan',
            name: 'Loan',
            kind: 'loan',
            openingBalance: 100000,
            openingCash: 10000,
            sortOrder: 1),
      ]
      ..openings = const [
        SourceOpeningRow(
            sourceId: 'loan',
            userId: 'user-asif',
            openingBalance: 100000,
            openingCash: 10000),
      ]
      ..txns = [
        _txn(500, 'Cash'),
        _txn(2000, 'UPI'),
        _txn(1000, 'Cash', type: 'income'),
      ]
      ..walletMoves = [
        WalletMoveRow(
            id: 'm1',
            sourceId: 'loan',
            amount: 5000,
            toCash: true,
            occurredAt: DateTime(2026, 10, 2)),
      ];

    final w = s.wallet('loan');
    expect(w.cash, 10000 - 500 + 1000 + 5000);
    expect(w.bank, 90000 - 2000 - 5000);
    // A move never changes the total.
    expect(w.cash + w.bank, 100000 - 500 - 2000 + 1000);
  });
}
