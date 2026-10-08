import 'package:family_finance/theme/nocturne.dart';
import 'package:family_finance/v3/data/ai/ai_config.dart';
import 'package:family_finance/v3/data/note_blocks.dart';
import 'package:family_finance/v3/data/notes_presence.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/screens/ai_settings_v3.dart';
import 'package:family_finance/v3/screens/note_editor_v3.dart';
import 'package:family_finance/v3/sheets/recurring_sheet_v3.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepo extends V3Repository {
  _FakeRepo()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  String? get currentUserId => 'user-asif';

  Map<String, dynamic>? lastUpdatedPatch;
  String? lastUpdatedId;
  String? lastAddedOwnerId;

  @override
  Future<RecurringRow> addRecurring({
    required String familyId,
    required String title,
    required double amount,
    required String cadence,
    required DateTime nextDue,
    String type = 'expense',
    String? categoryId,
    String? categoryKey,
    String? sourceId,
    String? ownerUserId,
    int remindDays = 2,
    bool autoPost = true,
  }) async {
    lastAddedOwnerId = ownerUserId ?? currentUserId;
    return RecurringRow(
      id: 'rec-new',
      title: title,
      amount: amount,
      cadence: cadence,
      nextDue: nextDue,
      type: type,
      categoryKey: categoryKey ?? 'bills',
      sourceId: sourceId,
      ownerUserId: lastAddedOwnerId,
      remindDays: remindDays,
      autoPost: autoPost,
    );
  }

  @override
  Future<void> updateRecurring(String id, Map<String, dynamic> patch) async {
    lastUpdatedId = id;
    lastUpdatedPatch = patch;
  }

  @override
  Future<List<RecurringRow>> recurring(String familyId) async => [];
}

class _FakePresence extends NotesPresenceService {
  _FakePresence()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<void> setActiveNote(
    String? noteId, {
    String? title,
    String? blockId,
  }) async {}

  @override
  Future<void> setFocusedBlock(String? blockId) async {}

  @override
  void sendTyping(String noteId, {String? blockId}) {}

  @override
  void sendBlockDelta({
    required String noteId,
    required String blockId,
    NoteBlock? block,
    bool deleted = false,
    String? title,
  }) {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Task #1 — Recurring owner picker & attribution (§5.1)', () {
    test('RecurringRow.fromJson parses owner_user_id and type', () {
      final row = RecurringRow.fromJson({
        'id': 'rec-1',
        'title': 'Monthly Salary',
        'amount': 85000,
        'cadence': 'monthly',
        'next_due': '2026-11-01',
        'type': 'income',
        'category_key': 'salary',
        'owner_user_id': 'user-asif',
        'auto_post': true,
      });

      expect(row.ownerUserId, 'user-asif');
      expect(row.isIncome, isTrue);
      expect(row.type, 'income');
    });

    testWidgets(
      'V3RecurringSheet shows unowned warning banner and lets user assign owner',
      (tester) async {
        final repo = _FakeRepo();
        final state = V3State(repo)
          ..loading = false
          ..family = const FamilyRow(
            id: 'fam-1',
            name: 'Home',
            kind: 'family',
            inviteCode: 'ABCD',
            ownerId: 'user-asif',
          )
          ..members = const [
            MemberRow(
              userId: 'user-asif',
              name: 'Asif',
              role: 'owner',
              relationship: 'Self',
              status: 'active',
              hue: 289,
            ),
            MemberRow(
              userId: 'user-sara',
              name: 'Sara',
              role: 'member',
              relationship: 'Spouse',
              status: 'active',
              hue: 160,
            ),
          ]
          ..recurring = [
            RecurringRow(
              id: 'rec-unowned',
              title: 'Salary',
              amount: 90000,
              cadence: 'monthly',
              nextDue: DateTime(2026, 11, 1),
              type: 'income',
              categoryKey: 'salary',
              ownerUserId: null,
            ),
          ];

        await tester.pumpWidget(
          ChangeNotifierProvider<V3State>.value(
            value: state,
            child: const MaterialApp(
              home: Scaffold(body: V3RecurringSheet()),
            ),
          ),
        );

        // Unowned recurring row warning banner & badge are visible
        expect(find.textContaining('has no owner'), findsOneWidget);
        expect(find.text('No owner'), findsOneWidget);

        // Tap the unowned row to open the edit dialog
        await tester.tap(find.text('Salary'));
        await tester.pumpAndSettle();

        expect(find.text('Edit recurring'), findsOneWidget);
        expect(find.text('For'), findsOneWidget);
        expect(find.text('Sara'), findsOneWidget);

        // Pick Sara as the owner and tap the save checkmark button
        await tester.tap(find.text('Sara'));
        await tester.pump();
        final saveIcon = find.byWidgetPredicate(
          (w) => w is Icon && w.size == 20 && w.color == Colors.white,
        );
        await tester.tap(saveIcon);
        await tester.pumpAndSettle();

        expect(repo.lastUpdatedId, 'rec-unowned');
        expect(repo.lastUpdatedPatch?['owner_user_id'], 'user-sara');
      },
    );
  });

  group('Task #2 & #3 — Clover-style NoteEditorV3 & auto-structure on paste',
      () {
    Future<Widget> buildEditor(
      WidgetTester tester, {
      List<NoteBlock>? initialBlocks,
    }) async {
      final repo = _FakeRepo();
      final state = V3State(repo)
        ..loading = false
        ..family = const FamilyRow(
          id: 'fam-1',
          name: 'Home',
          kind: 'family',
          inviteCode: 'ABCD',
          ownerId: 'user-asif',
        )
        ..members = const [
          MemberRow(
            userId: 'user-asif',
            name: 'Asif',
            role: 'owner',
            relationship: 'Self',
            status: 'active',
            hue: 289,
          ),
        ];
      final presence = _FakePresence();

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<V3State>.value(value: state),
          ChangeNotifierProvider<NotesPresenceService>.value(value: presence),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Nocturne.bg,
          ),
          home: NoteEditorV3(initialBlocks: initialBlocks),
        ),
      );
    }

    testWidgets('typing / in empty paragraph opens slash-command menu',
        (tester) async {
      final widget = await buildEditor(tester);
      await tester.pumpWidget(widget);
      await tester.pump();

      final paraFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText ==
                'Write something, type / for blocks, or paste a list…',
      );
      expect(paraFinder, findsOneWidget);

      await tester.enterText(paraFinder, '/');
      await tester.pump();

      expect(find.text('INSERT BLOCK'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);

      // Tap Checklist in slash menu to convert the block
      await tester.tap(find.text('Checklist'));
      await tester.pump();

      expect(find.text('INSERT BLOCK'), findsNothing);
      expect(find.text('Add item'), findsOneWidget);
    });

    testWidgets(
      'multi-line paste into paragraph auto-structures into checklist with Undo',
      (tester) async {
        final widget = await buildEditor(tester);
        await tester.pumpWidget(widget);
        await tester.pump();

        final paraFinder = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText ==
                  'Write something, type / for blocks, or paste a list…',
        );

        // Simulate pasting a multi-line shopping list into the empty paragraph
        await tester.enterText(paraFinder, 'Milk\nEggs\nBread');
        await tester.pumpAndSettle();

        // Automatically converted into a 3-item checklist
        expect(find.text('Milk'), findsOneWidget);
        expect(find.text('Eggs'), findsOneWidget);
        expect(find.text('Bread'), findsOneWidget);
        expect(find.text('Structured into 3 items'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo on the snackbar -> restores as a single paragraph
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(find.text('Milk\nEggs\nBread'), findsOneWidget);
      },
    );

    testWidgets('focused checklist offers To table conversion pill',
        (tester) async {
      final widget = await buildEditor(
        tester,
        initialBlocks: [
          NoteBlock.todoItems(const [
            TodoItem(text: 'Day 1: Tokyo'),
            TodoItem(text: 'Day 2: Kyoto'),
          ]),
        ],
      );
      await tester.pumpWidget(widget);
      await tester.pump();

      // Tap inside the first todo item to focus the block
      await tester.tap(find.text('Day 1: Tokyo'));
      await tester.pump();

      expect(find.text('To table'), findsOneWidget);
      await tester.tap(find.text('To table'));
      await tester.pump();

      // Converted to a 2-column table with 'Tokyo' and 'Kyoto' cells
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Kyoto'), findsOneWidget);
    });
  });

  group('Task #3 — AiSettingsV3 (§5.3)', () {
    testWidgets('switches providers, reveals base URL, and saves config',
        (tester) async {
      await tester.runAsync(() async {
        await AiConfigStore.clear();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiSettingsV3()),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('Anthropic Claude'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Other (OpenAI-compatible)'), findsOneWidget);
      expect(find.text('BASE URL'), findsNothing);

      // Select Other (OpenAI-compatible) -> reveals BASE URL field
      await tester.tap(find.text('Other (OpenAI-compatible)'));
      await tester.pump();

      expect(find.text('BASE URL'), findsOneWidget);

      // Switch back to Gemini and test connection with empty key
      await tester.tap(find.text('Google Gemini'));
      await tester.pump();

      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test connection'));
      await tester.pump();

      expect(find.text('Enter an API key first'), findsOneWidget);
    });
  });
}