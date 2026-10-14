import 'package:family_finance/v3/data/bill_scan.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/phosphor_icons.dart';
import 'package:family_finance/v3/sheets/v3_sheets.dart';
import 'package:family_finance/v3/v3_nav.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repo extends V3Repository {
  _Repo()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  String? get currentUserId => 'me';

  final saved = <({String? categoryId, String? subCategoryId, Map<String, double> shares})>[];

  @override
  Future<TxnRow> addTransaction({
    required String familyId,
    required String title,
    required double amount,
    required String type,
    String method = 'UPI',
    String origin = 'manual',
    String? categoryId,
    String? subCategoryId,
    String? sourceId,
    String? cardId,
    String? forUserId,
    DateTime? occurredAt,
    String? paidBy,
    Map<String, double>? shares,
    String? note,
  }) async {
    saved.add((
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      shares: shares ?? const {},
    ));
    return TxnRow(
      id: 't${saved.length}',
      familyId: familyId,
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      occurredAt: DateTime.now(),
    );
  }
}

const _food = CategoryRow(id: 'c-food', key: 'x_food', name: 'Food', sortOrder: 1);
const _travel = CategoryRow(id: 'c-travel', key: 'x_travel', name: 'Travel', sortOrder: 2);
const _withFam = CategoryRow(
  id: 'c-fam',
  key: 'x_fam',
  name: 'with fam',
  parentId: 'c-food',
  alsoParentIds: ['c-travel'],
  memberIds: ['me', 'sinu'],
);
const _forSinu = CategoryRow(
  id: 'c-sinu',
  key: 'x_sinu',
  name: 'for Sinu',
  parentId: 'c-food',
  memberIds: ['sinu'],
);

V3State _state(_Repo repo) => V3State(repo)
  ..loading = false
  ..family = const FamilyRow(
    id: 'fam',
    name: 'Home',
    kind: 'family',
    inviteCode: 'HOME01',
    ownerId: 'me',
  )
  ..members = const [
    MemberRow(userId: 'me', name: 'Asif', role: 'owner', relationship: 'Self', status: 'active', hue: 289),
    MemberRow(userId: 'sinu', name: 'Sinu', role: 'member', relationship: 'Spouse', status: 'active', hue: 40),
  ]
  ..categories = const [_food, _travel, _withFam, _forSinu];

Future<void> _openSheet(WidgetTester tester, V3State state) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<V3State>.value(value: state),
        ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: V3AddSheet(
                    prefill: (
                      amount: 100,
                      payee: 'Dinner',
                      date: null,
                      income: false,
                      category: null,
                      note: null,
                      ref: null,
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byIcon(PhBold.check).first); // header save
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AI reply: plausible values kept, implausible ones dropped', () {
    final now = DateTime(2026, 10, 14, 12);
    final ok = billFromAi({
      'amount': 81,
      'payee': 'Broadway',
      'date': '2026-10-13T10:51:00',
      'income': false,
      'category': 'dining',
    }, keys: {'dining'}, now: now);
    expect(ok.amount, 81);
    expect(ok.payee, 'Broadway');
    expect(ok.date, DateTime(2026, 10, 13, 10, 51));
    expect(ok.category, 'dining');

    final bad = billFromAi({
      'amount': 0,
      'payee': 'gpay-1126@okbizaxis',
      'date': '2027-01-01T00:00:00',
      'income': true,
      'category': 'made_up',
    }, keys: {'dining'}, now: now);
    expect(bad.amount, isNull);
    expect(bad.payee, isNull);
    expect(bad.date, isNull);
    expect(bad.category, isNull);
    expect(bad.income, isTrue);
  });

  test('links load from JSON; a shared sub is under every main it lists', () {
    final c = CategoryRow.fromJson({
      'id': 'c-fam',
      'key': 'x_fam',
      'name': 'with fam',
      'parent_id': 'c-food',
      'also_parent_ids': ['c-travel', 'c-games'],
      'member_ids': ['me', 'sinu'],
    });
    expect(c.isUnder('c-food'), isTrue);
    expect(c.isUnder('c-games'), isTrue);
    expect(c.isUnder('c-bills'), isFalse);
    expect(c.memberIds, ['me', 'sinu']);

    final state = _state(_Repo());
    expect(state.subcategoriesOf('c-travel').map((x) => x.key), ['x_fam']);
  });

  test('an old entry filed under a sub reads as its main plus that sub', () {
    final t = TxnRow(
      id: 't',
      familyId: 'fam',
      title: 'Lunch',
      amount: 10,
      type: 'expense',
      occurredAt: DateTime(2026),
    ).refiled(_food, 'c-fam');
    expect(t.categoryKey, 'x_food');
    expect(t.categoryId, 'c-food');
    expect(t.subCategoryId, 'c-fam');
  });

  testWidgets('picking a sub fills "For" with its people and saves main + sub',
      (tester) async {
    final repo = _Repo();
    await _openSheet(tester, _state(repo));

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('with fam'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.categoryId, 'c-food');
    expect(repo.saved.single.subCategoryId, 'c-fam');
    expect(repo.saved.single.shares.keys.toSet(), {'me', 'sinu'});
  });

  testWidgets('picking people selects the sub linked to exactly them',
      (tester) async {
    final repo = _Repo();
    await _openSheet(tester, _state(repo));

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    // "You" is selected by default; adding Sinu makes {me, sinu}.
    await tester.tap(find.text('Sinu'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(repo.saved.single.subCategoryId, 'c-fam');
  });

  testWidgets('a sub shared with Travel is offered under Travel too',
      (tester) async {
    await _openSheet(tester, _state(_Repo()));
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(find.text('with fam'), findsOneWidget);
    expect(find.text('for Sinu'), findsNothing);
  });

  testWidgets('the AI read replaces untouched fields once it arrives',
      (tester) async {
    final ai = Completer<BillScan?>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<V3State>.value(value: _state(_Repo())),
          ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: V3AddSheet(
              // The on-phone read took the bold rupee sign for a 7.
              prefill: (
                amount: 781,
                payee: 'Broadway',
                date: null,
                income: false,
                category: null,
                note: null,
                ref: '665280079818',
              ),
              refine: ai.future,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('781', findRichText: true), findsWidgets);
    expect(find.text('Checking the receipt with AI…'), findsOneWidget);

    // The user rewrites the note before the AI answers; that edit stays.
    await tester.enterText(find.text('Broadway (Txn: 665280079818)'), 'Breakfast');
    const BillScan better = (
      amount: 81.0,
      payee: 'Broadway',
      date: null,
      income: false,
      category: 'x_food',
      note: null,
      ref: '665280079818',
    );
    ai.complete(better);
    await tester.pumpAndSettle();

    expect(find.textContaining('781', findRichText: true), findsNothing);
    expect(find.textContaining('81', findRichText: true), findsWidgets);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Checking the receipt with AI…'), findsNothing);
  });
}
