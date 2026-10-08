import 'package:family_finance/v3/data/chat_controller.dart';
import 'package:family_finance/v3/data/note_blocks.dart';
import 'package:family_finance/v3/data/notes_presence.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/screens/chat_list_v3.dart';
import 'package:family_finance/v3/screens/chat_thread_v3.dart';
import 'package:family_finance/v3/screens/note_editor_v3.dart';
import 'package:family_finance/v3/screens/notes_widgets.dart';
import 'package:family_finance/v3/sheets/v3_sheets.dart';
import 'package:family_finance/v3/v3_nav.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:family_finance/web/web_app.dart';
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

  int saveCalls = 0;
  List<NoteBlock>? lastSavedBlocks;
  int nextVersion = 2;

  final List<DirectMessageRow> sentMessages = [];
  final List<String> markedReadSenders = [];
  final List<String> deletedMessageIds = [];
  final List<String> clearedPartnerIds = [];

  @override
  Future<NoteSaveResult> saveNoteConditional({
    required String familyId,
    String? id,
    required String title,
    required String content,
    required List<Map<String, dynamic>> blocks,
    bool pinned = false,
    String visibility = 'family',
    String? folderId,
    int? expectedVersion,
  }) async {
    saveCalls++;
    lastSavedBlocks = blocks
        .map((b) => NoteBlock.fromJson(Map<String, dynamic>.from(b)))
        .toList();
    final v = nextVersion++;
    return NoteSaveResult(
      ok: true,
      row: NoteRow(
        id: id ?? 'note-1',
        title: title,
        content: content,
        blocks: lastSavedBlocks!,
        pinned: pinned,
        visibility: visibility,
        folderId: folderId,
        createdBy: 'user-asif',
        updatedBy: 'user-asif',
        updatedAt: DateTime.now(),
        version: v,
      ),
    );
  }

  @override
  Future<List<DirectMessageRow>> directMessages(
    String familyId, {
    int limit = 300,
  }) async =>
      List.of(sentMessages);

  @override
  Future<DirectMessageRow> sendDirectMessage({
    required String familyId,
    required String recipientId,
    required String body,
    String kind = 'text',
    String? imageData,
  }) async {
    final row = DirectMessageRow(
      id: 'dm-${sentMessages.length + 1}',
      familyId: familyId,
      senderId: 'user-asif',
      recipientId: recipientId,
      body: body,
      kind: kind,
      imageData: imageData,
      createdAt: DateTime.now(),
    );
    sentMessages.add(row);
    return row;
  }

  @override
  Future<void> deleteDirectMessage(String messageId) async {
    deletedMessageIds.add(messageId);
    sentMessages.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> clearDirectThread({
    required String familyId,
    required String partnerId,
  }) async {
    clearedPartnerIds.add(partnerId);
    sentMessages.removeWhere(
      (m) =>
          (m.senderId == 'user-asif' && m.recipientId == partnerId) ||
          (m.senderId == partnerId && m.recipientId == 'user-asif'),
    );
  }

  @override
  Future<void> markDirectMessagesRead({
    required String familyId,
    required String senderId,
  }) async {
    markedReadSenders.add(senderId);
  }
}

class _TestPresence extends NotesPresenceService {
  _TestPresence()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<NoteBlock> broadcastedBlocks = [];
  String? activeNoteId;
  String? activeBlockId;

  @override
  Future<void> connect({required String familyId, required String selfName}) async {}

  @override
  Future<void> ensureChannel({
    required String familyId,
    required String selfName,
  }) async {}

  @override
  Future<void> setActiveNote(
    String? noteId, {
    String? title,
    String? blockId,
  }) async {
    activeNoteId = noteId;
    activeBlockId = blockId;
  }

  @override
  Future<void> setFocusedBlock(String? blockId) async {
    activeBlockId = blockId;
  }

  @override
  void sendTyping(String noteId, {String? blockId}) {}

  @override
  void sendBlockDelta({
    required String noteId,
    required String blockId,
    NoteBlock? block,
    bool deleted = false,
    String? title,
  }) {
    if (block != null) {
      broadcastedBlocks.add(block.deepCopy());
    }
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
    MemberRow(
      userId: 'user-sara',
      name: 'Sara',
      role: 'admin',
      relationship: 'Spouse',
      status: 'active',
      hue: 160,
    ),
  ];
  return state;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    V3Sheets.readOnly = false;
  });

  group('Phase 2 — Live Notes & Collaborative Block Editor', () {
    test('NoteBlock.deepCopy clones items, head, and rows without aliasing', () {
      final todo = NoteBlock(
        id: 'b-todo',
        kind: NoteBlockKind.todo,
        items: [
          const TodoItem(text: 'Milk', done: false),
        ],
      );
      final todoClone = todo.deepCopy();
      todoClone.items[0] = todoClone.items[0].copyWith(text: 'Almond Milk');
      todoClone.items.add(const TodoItem(text: 'Eggs', done: true));

      expect(todo.items.length, 1);
      expect(todo.items.first.text, 'Milk');

      final table = NoteBlock(
        id: 'b-table',
        kind: NoteBlockKind.table,
        head: ['Item', 'Cost'],
        rows: [
          ['Rice', '120'],
        ],
      );
      final tableClone = table.deepCopy();
      tableClone.head[0] = 'Product';
      tableClone.rows[0][1] = '999';

      expect(table.head.first, 'Item');
      expect(table.rows.first[1], '120');
    });

    testWidgets(
      'Remote block_delta merges into unfocused block, rebases history, and marks focused block contested',
      (tester) async {
        final repo = _TestRepo();
        final state = _buildSeededState(repo);
        final presence = _TestPresence();

        final initialNote = NoteRow(
          id: 'note-1',
          title: 'Groceries',
          content: 'Line one\nLine two',
          blocks: [
            const NoteBlock(
              id: 'b1',
              kind: NoteBlockKind.paragraph,
              text: 'Line one',
            ),
            const NoteBlock(
              id: 'b2',
              kind: NoteBlockKind.paragraph,
              text: 'Line two',
            ),
          ],
          pinned: false,
          visibility: 'family',
          createdBy: 'user-asif',
          updatedBy: 'user-asif',
          updatedAt: DateTime(2026, 10, 8),
          version: 1,
        );
        state.notes = [initialNote];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<V3State>.value(value: state),
              ChangeNotifierProvider<NotesPresenceService>.value(
                value: presence,
              ),
              ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: NoteEditorV3(note: initialNote),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus block b1 by tapping its TextField.
        final b1Field = find.widgetWithText(TextField, 'Line one');
        expect(b1Field, findsOneWidget);
        await tester.tap(b1Field);
        await tester.pump();

        // 1. Remote delta arrives for unfocused block b2 -> applied immediately!
        presence.debugEmitBlockDelta(
          const NoteBlockDelta(
            noteId: 'note-1',
            blockId: 'b2',
            block: NoteBlock(
              id: 'b2',
              kind: NoteBlockKind.paragraph,
              text: 'Sara updated b2',
            ),
            fromUser: 'user-sara',
            fromName: 'Sara',
            sessionId: 'remote-sess',
            seq: 1,
          ),
        );
        await tester.pump();

        expect(find.text('Sara updated b2'), findsOneWidget);

        // 2. Remote delta arrives for locally focused block b1 -> NOT clobbered;
        // marks block b1 as contested ("Sara is editing this line").
        presence.debugEmitBlockDelta(
          const NoteBlockDelta(
            noteId: 'note-1',
            blockId: 'b1',
            block: NoteBlock(
              id: 'b1',
              kind: NoteBlockKind.paragraph,
              text: 'Sara clobber attempt',
            ),
            fromUser: 'user-sara',
            fromName: 'Sara',
            sessionId: 'remote-sess',
            seq: 2,
          ),
        );
        await tester.pump();

        // Local text 'Line one' is preserved and contested pill is shown.
        expect(find.text('Line one'), findsOneWidget);
        expect(find.text('Sara clobber attempt'), findsNothing);
        expect(find.textContaining('Sara is editing this line'), findsOneWidget);

        // Flush the 5-second contested block decay timer.
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets(
      'Background autosave preserves empty blocks instead of deleting a block the user just added',
      (tester) async {
        final repo = _TestRepo();
        final state = _buildSeededState(repo);
        final presence = _TestPresence();

        final initialNote = NoteRow(
          id: 'note-1',
          title: 'Draft',
          content: 'First paragraph',
          blocks: [
            const NoteBlock(
              id: 'b1',
              kind: NoteBlockKind.paragraph,
              text: 'First paragraph',
            ),
            const NoteBlock(
              id: 'b2',
              kind: NoteBlockKind.paragraph,
              text: '',
            ),
          ],
          pinned: false,
          visibility: 'family',
          createdBy: 'user-asif',
          updatedBy: 'user-asif',
          updatedAt: DateTime(2026, 10, 8),
          version: 1,
        );
        state.notes = [initialNote];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<V3State>.value(value: state),
              ChangeNotifierProvider<NotesPresenceService>.value(
                value: presence,
              ),
              ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: NoteEditorV3(note: initialNote),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Edit b1 to trigger dirty + autosave timer (1.2s).
        await tester.enterText(
          find.widgetWithText(TextField, 'First paragraph'),
          'First paragraph updated',
        );
        await tester.pump(const Duration(milliseconds: 1500));

        expect(repo.saveCalls, greaterThanOrEqualTo(1));
        // Both b1 and the empty b2 block must be preserved on background autosave!
        expect(repo.lastSavedBlocks?.length, 2);
      },
    );

    testWidgets('LiveBanner invokes onTap and displays Follow action', (
      tester,
    ) async {
      final repo = _TestRepo();
      final state = _buildSeededState(repo);
      final presence = _TestPresence();
      presence.debugSetOthers(const [
        NotePresence(
          userId: 'user-sara',
          sessionKey: 'user-sara:sess-1',
          name: 'Sara',
          noteId: 'note-1',
          noteTitle: 'Trip Plan',
          blockId: 'b2',
        ),
      ]);

      NotePresence? tapped;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<V3State>.value(value: state),
            ChangeNotifierProvider<NotesPresenceService>.value(value: presence),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LiveBanner(
                onTap: (p) => tapped = p,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Follow'), findsOneWidget);
      await tester.tap(find.byType(LiveBanner));
      expect(tapped?.userId, 'user-sara');
      expect(tapped?.blockId, 'b2');
    });
  });

  group('Phase 3 — Direct Messages', () {
    test(
      'ChatController groups threads, tracks unread counts, and marks read on openThread',
      () async {
        final repo = _TestRepo();
        final chat = ChatController(repo);
        final state = _buildSeededState(repo);

        final m1 = DirectMessageRow.fromJson({
          'id': 'dm-1',
          'family_id': 'fam-1',
          'sender_id': 'user-sara',
          'recipient_id': 'user-asif',
          'body': 'Did you pay the electricity bill?',
          'created_at': '2026-10-08T10:00:00Z',
          'read_at': null,
        });
        final m2 = DirectMessageRow.fromJson({
          'id': 'dm-2',
          'family_id': 'fam-1',
          'sender_id': 'user-asif',
          'recipient_id': 'user-sara',
          'body': 'Yes, paid via UPI.',
          'created_at': '2026-10-08T10:02:00Z',
          'read_at': null,
        });

        chat.seedForTest(
          familyId: 'fam-1',
          myId: 'user-asif',
          messages: [m2, m1],
        );

        expect(chat.totalUnread, 1);
        expect(chat.unreadFrom('user-sara'), 1);

        final thread = chat.threadWith('user-sara');
        expect(thread.map((m) => m.id).toList(), ['dm-1', 'dm-2']);

        final summaries = chat.threadsForMembers(state.members);
        expect(summaries.length, 1);
        expect(summaries.first.partner.userId, 'user-sara');
        expect(summaries.first.unreadCount, 1);
        expect(summaries.first.lastMessage?.body, 'Yes, paid via UPI.');

        await chat.openThread('user-sara');
        expect(chat.totalUnread, 0);
        expect(repo.markedReadSenders, contains('user-sara'));
      },
    );

    testWidgets('ChatListV3 and ChatThreadV3 render and send messages', (
      tester,
    ) async {
      final repo = _TestRepo();
      final msg = DirectMessageRow(
        id: 'dm-10',
        familyId: 'fam-1',
        senderId: 'user-sara',
        recipientId: 'user-asif',
        body: 'Hello from Sara',
        createdAt: DateTime(2026, 10, 8, 9, 30),
      );
      repo.sentMessages.add(msg);

      final state = _buildSeededState(repo);
      final chat = ChatController(repo);
      chat.seedForTest(
        familyId: 'fam-1',
        myId: 'user-asif',
        messages: [msg],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<V3State>.value(value: state),
            ChangeNotifierProvider<ChatController>.value(value: chat),
            ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: ChatListV3()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sara'), findsWidgets);
      expect(find.text('Hello from Sara'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chat_thread_tile_user-sara')));
      await tester.pumpAndSettle();

      expect(find.byType(ChatThreadV3), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('chat_composer_field')),
        'Checking in!',
      );
      await tester.tap(find.byKey(const ValueKey('chat_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Checking in!'), findsOneWidget);
      expect(repo.sentMessages.last.body, 'Checking in!');
    });

    test(
      'ChatController supports online presence, typing state, pokeMember, sendImage, deleteMessage, and clearThread',
      () async {
        final repo = _TestRepo();
        final chat = ChatController(repo);
        chat.seedForTest(
          familyId: 'fam-1',
          myId: 'user-asif',
          onlineUserIds: const ['user-sara'],
        );

        expect(chat.isUserOnline('user-sara'), isTrue);
        expect(chat.isPartnerTyping('user-sara'), isFalse);

        chat.debugSetPartnerTyping('user-sara', true);
        expect(chat.isPartnerTyping('user-sara'), isTrue);
        chat.debugSetPartnerTyping('user-sara', false);

        // 1. Poke member
        await chat.pokeMember('user-sara');
        expect(chat.threadWith('user-sara').length, 1);
        expect(chat.threadWith('user-sara').first.isPoke, isTrue);

        // 2. Send image message
        await chat.sendImage(
          recipientId: 'user-sara',
          base64Data:
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          caption: 'Receipt photo',
        );
        final afterImg = chat.threadWith('user-sara');
        expect(afterImg.length, 2);
        expect(afterImg.last.isImage, isTrue);
        expect(afterImg.last.body, 'Receipt photo');

        // 3. Delete single message
        final firstId = afterImg.first.id;
        await chat.deleteMessage(firstId);
        expect(repo.deletedMessageIds, contains(firstId));
        expect(chat.threadWith('user-sara').length, 1);

        // 4. Clear entire thread
        await chat.clearThread('user-sara');
        expect(repo.clearedPartnerIds, contains('user-sara'));
        expect(chat.threadWith('user-sara'), isEmpty);
      },
    );

    testWidgets(
      'ChatListV3 & ChatThreadV3 render online dots, typing status, Poke, Delete message, and Clear chat',
      (tester) async {
        final repo = _TestRepo();
        final msg = DirectMessageRow(
          id: 'dm-55',
          familyId: 'fam-1',
          senderId: 'user-sara',
          recipientId: 'user-asif',
          body: 'Message to delete',
          createdAt: DateTime(2026, 10, 8, 9, 30),
        );
        repo.sentMessages.add(msg);

        final state = _buildSeededState(repo);
        final chat = ChatController(repo);
        chat.seedForTest(
          familyId: 'fam-1',
          myId: 'user-asif',
          messages: [msg],
          onlineUserIds: const ['user-sara'],
        );
        final nav = V3Nav();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<V3State>.value(value: state),
              ChangeNotifierProvider<ChatController>.value(value: chat),
              ChangeNotifierProvider<V3Nav>.value(value: nav),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const Scaffold(body: ChatListV3()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Online dot and badge are shown on the thread list
        expect(
          find.byKey(const ValueKey('chat_online_dot_user-sara')),
          findsOneWidget,
        );
        expect(find.text('Online'), findsOneWidget);

        // Open thread via V3Nav.openChat('user-sara')
        nav.openChat('user-sara');
        await tester.pumpAndSettle();
        expect(find.byType(ChatThreadV3), findsOneWidget);
        expect(
          find.byKey(const ValueKey('chat_header_online_dot_user-sara')),
          findsOneWidget,
        );
        expect(find.text('Online now · Live'), findsOneWidget);
        expect(find.text('Message to delete'), findsOneWidget);

        // Tap Poke button in thread header
        await tester.tap(find.byKey(const ValueKey('chat_poke_button')));
        await tester.pumpAndSettle();
        expect(repo.sentMessages.any((m) => m.isPoke), isTrue);

        // Delete single message via options button
        await tester.tap(find.byKey(const ValueKey('chat_msg_options_dm-55')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('chat_delete_message_action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Message to delete'), findsNothing);
        expect(repo.deletedMessageIds, contains('dm-55'));

        // Clear entire thread via header button
        await tester.tap(find.byKey(const ValueKey('chat_clear_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('chat_confirm_clear_button')),
        );
        await tester.pumpAndSettle();
        expect(repo.clearedPartnerIds, contains('user-sara'));
        expect(chat.threadWith('user-sara'), isEmpty);

        // Navigate back and switch tabs cleanly
        nav.closeChatThread();
        await tester.pumpAndSettle();
        expect(nav.chatPartnerId, isNull);

        nav.goTab(0);
        expect(nav.tab, 0);
        expect(nav.page, isNull);
      },
    );
  });

  group('Phase 4 — Web Shell (Read-Only Finance + Editable Notes & Chat)', () {
    testWidgets(
      'WebShell sets V3Sheets.readOnly, shows online dots, surfaces live incoming message toast, and navigates to Notes & Chat',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _TestRepo();
        final state = _buildSeededState(repo);
        final presence = _TestPresence();
        final chat = ChatController(repo);
        chat.seedForTest(
          familyId: 'fam-1',
          myId: 'user-asif',
          onlineUserIds: const ['user-sara'],
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<V3State>.value(value: state),
              ChangeNotifierProvider<V3Nav>(create: (_) => V3Nav()),
              ChangeNotifierProvider<NotesPresenceService>.value(
                value: presence,
              ),
              ChangeNotifierProvider<ChatController>.value(value: chat),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const WebShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(V3Sheets.readOnly, isTrue);
        expect(find.byKey(const ValueKey('web_readonly_banner')), findsOneWidget);
        expect(find.text('1 online'), findsOneWidget);

        // Inject a live incoming message while user is on the Overview tab -> toast appears!
        chat.injectMessageForTest(
          DirectMessageRow(
            id: 'dm-live-99',
            familyId: 'fam-1',
            senderId: 'user-sara',
            recipientId: 'user-asif',
            body: 'Hey from web live!',
            createdAt: DateTime.now(),
          ),
        );
        await tester.pump();
        expect(find.text('Hey from web live!'), findsOneWidget);
        expect(find.text('Reply'), findsOneWidget);

        // Flush the 6-second toast auto-dismiss timer.
        await tester.pump(const Duration(seconds: 7));

        // Switch to Family notes tab -> read-only banner disappears.
        await tester.tap(find.byKey(const ValueKey('web_nav_notes')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('web_readonly_banner')), findsNothing);

        // Switch to Direct messages tab -> read-only banner stays hidden and Sara's thread is visible.
        await tester.tap(find.byKey(const ValueKey('web_nav_chat')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('web_readonly_banner')), findsNothing);
        expect(find.text('Sara'), findsWidgets);
      },
    );
  });
}
