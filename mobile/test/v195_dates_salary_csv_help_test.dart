import 'package:family_finance/v3/data/expense_import.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/screens/import_v3.dart';
import 'package:family_finance/v3/sheets/v3_sheets.dart';
import 'package:family_finance/v3/v3_nav.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestRepo extends V3Repository {
  _TestRepo()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  String? get currentUserId => 'user-asif';

  final List<TxnRow> transactionsList = [];

  @override
  Future<TxnRow> addTransaction({
    required String familyId,
    required String title,
    required double amount,
    required String type,
    String method = 'UPI',
    String origin = 'manual',
    String? categoryId,
    String? sourceId,
    String? cardId,
    String? forUserId,
    DateTime? occurredAt,
    String? paidBy,
    Map<String, double>? shares,
    String? note,
  }) async {
    final row = TxnRow(
      id: 'txn-${transactionsList.length + 1}',
      familyId: familyId,
      userId: forUserId ?? currentUserId,
      paidBy: paidBy ?? currentUserId,
      sourceId: sourceId,
      categoryId: categoryId,
      categoryKey: 'groceries',
      title: title,
      amount: amount,
      type: type,
      method: method,
      origin: origin,
      occurredAt: occurredAt ?? DateTime.now(),
      shares: shares ?? const {},
      note: note,
    );
    transactionsList.add(row);
    return row;
  }

  @override
  Future<int> addTransactionsBulk({
    required String familyId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final r in rows) {
      transactionsList.add(
        TxnRow(
          id: 'txn-bulk-${transactionsList.length + 1}',
          familyId: familyId,
          userId: currentUserId,
          paidBy: currentUserId,
          title: r['title'] as String,
          amount: (r['amount'] as num).toDouble(),
          type: r['type'] as String,
          method: 'Other',
          origin: 'import',
          categoryKey: 'groceries',
          occurredAt: r['occurred_at'] != null
              ? DateTime.parse(r['occurred_at'] as String)
              : DateTime.now(),
        ),
      );
    }
    return rows.length;
  }
}

V3State _buildSeededState(_TestRepo repo) {
  final state = V3State(repo);
  state.loading = false;
  state.family = const FamilyRow(
    id: 'fam-1',
    name: 'Khan Household',
    kind: 'family',
    inviteCode: 'KHAN26',
    ownerId: 'user-asif',
  );
  state.members = const [
    MemberRow(
      userId: 'user-asif',
      name: 'Asif',
      role: 'owner',
      relationship: 'Self',
      status: 'active',
      hue: 289,
    ),
  ];
  return state;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.9.5 — Particular Dates, Salary Default & CSV AI Prompt Guide', () {
    test('V3State defaults srcFilter to Salary source on load and computes balance per source', () async {
      final repo = _TestRepo();
      final state = _buildSeededState(repo);
      state.sources = [
        const SourceRow(
          id: 'src-sal',
          name: 'Salary',
          kind: 'income',
          openingBalance: 50000,
          sortOrder: 0,
        ),
        const SourceRow(
          id: 'src-loan',
          name: 'Loan',
          kind: 'loan',
          openingBalance: 20000,
          sortOrder: 1,
        ),
      ];
      state.txns = [
        TxnRow(
          id: 't-1',
          familyId: 'fam-1',
          userId: 'user-asif',
          title: 'Grocery',
          amount: 5000,
          type: 'expense',
          method: 'UPI',
          origin: 'manual',
          categoryKey: 'groceries',
          sourceId: 'src-sal',
          occurredAt: DateTime.now(),
        ),
        TxnRow(
          id: 't-2',
          familyId: 'fam-1',
          userId: 'user-asif',
          title: 'Loan EMI',
          amount: 2000,
          type: 'expense',
          method: 'Bank',
          origin: 'manual',
          categoryKey: 'other',
          sourceId: 'src-loan',
          occurredAt: DateTime.now(),
        ),
      ];

      // Refresh triggers salary default when _srcFilterChosen is false
      await state.refresh();
      expect(state.srcFilter, equals('src-sal'));
      // Salary balance: 50000 opening - 5000 expense = 45000
      expect(state.balance, equals(45000.0));

      // Switch to Loan source
      state.setSource('src-loan');
      expect(state.srcFilter, equals('src-loan'));
      // Loan balance: 20000 opening - 2000 expense = 18000
      expect(state.balance, equals(18000.0));

      // Toggle again -> clears filter to all sources
      state.setSource('src-loan');
      expect(state.srcFilter, isNull);
      // All sources balance: (50000 + 20000) - (5000 + 2000) = 63000
      expect(state.balance, equals(63000.0));
    });

    test('V3State importExpenses preserves custom dates on imported items', () async {
      final repo = _TestRepo();
      final state = _buildSeededState(repo);
      final customDate = DateTime(2026, 9, 15);

      final imported = [
        ImportedExpense(
          title: 'Flight Ticket',
          amount: 4500,
          date: customDate,
          category: 'Transport',
          selected: true,
        ),
      ];

      final count = await state.importExpenses(imported);
      expect(count, equals(1));
      expect(repo.transactionsList.length, equals(1));
      expect(repo.transactionsList.first.title, equals('Flight Ticket'));
      // The occurrence should match the imported date
      expect(repo.transactionsList.first.occurredAt.toUtc().year, equals(customDate.toUtc().year));
      expect(repo.transactionsList.first.occurredAt.toUtc().month, equals(customDate.toUtc().month));
      expect(repo.transactionsList.first.occurredAt.toUtc().day, equals(customDate.toUtc().day));
    });

    testWidgets('V3AddSheet renders date picker row and explanatory subheaders', (tester) async {
      final repo = _TestRepo();
      final state = _buildSeededState(repo);
      state.sources = [
        const SourceRow(
          id: 'src-sal',
          name: 'Salary',
          kind: 'income',
          openingBalance: 50000,
          sortOrder: 0,
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<V3State>.value(value: state),
            ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: V3AddSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Date selector row with Today / change button
      expect(find.textContaining('Today'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Explanatory headers
      expect(find.textContaining('DEBIT SOURCE'), findsOneWidget);
      expect(find.textContaining('PAYMENT CHANNEL'), findsOneWidget);
    });

    testWidgets('ImportV3 header contains format and AI prompt help button which opens _CsvHelpSheet', (tester) async {
      final repo = _TestRepo();
      final state = _buildSeededState(repo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<V3State>.value(value: state),
            ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
          ],
          child: const MaterialApp(
            home: ImportV3(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Info button present in header
      expect(find.text('Format & AI Prompt'), findsOneWidget);

      // Tap info button -> bottom sheet opens
      await tester.tap(find.text('Format & AI Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('CSV Format & AI Prompt Guide'), findsOneWidget);
      expect(find.text('Prompt to give Gemini / ChatGPT'), findsOneWidget);
      expect(find.text('Copy prompt'), findsOneWidget);
      expect(find.text('Sample CSV Template'), findsOneWidget);
      expect(find.text('Copy sample'), findsOneWidget);
    });
  });
}
