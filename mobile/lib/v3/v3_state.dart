import 'package:flutter/foundation.dart';

import 'data/expense_import.dart';
import 'data/note_blocks.dart';
import 'data/notification_bridge.dart';
import 'data/payment_parser.dart';
import 'data/v3_models.dart';
import 'data/v3_repository.dart';
import 'v3_design.dart';

/// Screen state for the v3 app, backed by Supabase.
///
/// Everything the screens read is derived here so a widget never has to know
/// about the database. Loads are guarded: a failure logs and leaves the
/// previous data in place rather than throwing during a build.
class V3State extends ChangeNotifier {
  V3State(this._repo);

  final V3Repository _repo;
  V3Repository get repo => _repo;

  // ── Load status ───────────────────────────────────────────────────────────
  bool loading = true;
  String? loadError;

  // ── Workspace ─────────────────────────────────────────────────────────────
  List<FamilyRow> families = [];
  FamilyRow? family;
  String get familyId => family?.id ?? '';

  List<MemberRow> members = [];
  List<CategoryRow> categories = [];
  List<SourceRow> sources = [];
  List<TxnRow> txns = [];
  List<BudgetRow> budgets = [];
  List<RecurringRow> recurring = [];
  List<CardRow> cards = [];
  List<NoteRow> notes = [];
  List<FolderRow> folders = [];
  List<SettlementRow> settlements = [];
  List<ApprovalRow> approvals = [];
  List<DetectedRow> detected = [];
  PrefsRow prefs = const PrefsRow();

  // ── Selection ─────────────────────────────────────────────────────────────
  /// 'family', or a member's user id.
  String scope = 'family';
  String period = '30d';
  bool hidden = false;
  String? srcFilter;

  int get threshold => prefs.alertThreshold;
  String get chartStyle => prefs.chartStyle;

  bool get isFamily => scope == 'family';
  String? get myId => _repo.currentUserId;

  MemberRow? get me {
    for (final m in members) {
      if (m.userId == myId) return m;
    }
    return null;
  }

  MemberRow? get scopeMember {
    for (final m in members) {
      if (m.userId == scope) return m;
    }
    return null;
  }

  String get scopeName =>
      isFamily ? (family?.name ?? 'Family') : (scopeMember?.name ?? '');
  String get periodLabel => period == '7d' ? 'Last 7 days' : 'Last 30 days';
  int get maxDays => period == '7d' ? 7 : 30;

  bool get canEdit {
    final role = me?.role ?? 'viewer';
    return role == 'owner' || role == 'admin' || role == 'member';
  }

  bool get isOwner => (me?.role ?? '') == 'owner';

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    // The provider is created before the auth gate renders, so bootstrap can
    // fire with no session. Every query needs a user id and RLS would refuse
    // them anyway, so bail quietly rather than dereferencing a null id.
    if (_repo.currentUserId == null) {
      families = [];
      family = null;
      loading = false;
      loadError = null;
      notifyListeners();
      return;
    }

    loading = true;
    loadError = null;
    notifyListeners();

    final fams = await V3Repository.guard('V3State.myFamilies', _repo.myFamilies);
    if (fams == null) {
      loadError = 'Could not reach the server.';
      loading = false;
      notifyListeners();
      return;
    }

    families = fams;
    if (families.isEmpty) {
      // No workspace yet — the caller shows onboarding.
      loading = false;
      notifyListeners();
      return;
    }

    family = families.first;
    await refresh();
  }

  Future<void> switchFamily(String id) async {
    final match = families.where((f) => f.id == id);
    if (match.isEmpty) return;
    family = match.first;
    scope = 'family';
    srcFilter = null;
    await refresh();
  }

  Future<void> refresh() async {
    if (familyId.isEmpty) return;
    loading = true;
    notifyListeners();

    final results = await Future.wait([
      V3Repository.guard('members', () => _repo.members(familyId)),
      V3Repository.guard('categories', () => _repo.categories(familyId)),
      V3Repository.guard('sources', () => _repo.sources(familyId)),
      V3Repository.guard('transactions', () => _repo.transactions(familyId)),
      V3Repository.guard('budgets', () => _repo.budgets(familyId)),
      V3Repository.guard('recurring', () => _repo.recurring(familyId)),
      V3Repository.guard('cards', () => _repo.cards(familyId)),
      V3Repository.guard('notes', () => _repo.notes(familyId)),
      V3Repository.guard('folders', () => _repo.folders(familyId)),
      V3Repository.guard('settlements', () => _repo.settlements(familyId)),
      V3Repository.guard('approvals', () => _repo.approvals(familyId)),
      V3Repository.guard('detected', () => _repo.detected(familyId)),
      V3Repository.guard('prefs', () => _repo.prefs(familyId)),
    ]);

    members = (results[0] as List<MemberRow>?) ?? members;
    categories = (results[1] as List<CategoryRow>?) ?? categories;
    sources = (results[2] as List<SourceRow>?) ?? sources;
    txns = (results[3] as List<TxnRow>?) ?? txns;
    budgets = (results[4] as List<BudgetRow>?) ?? budgets;
    recurring = (results[5] as List<RecurringRow>?) ?? recurring;
    cards = (results[6] as List<CardRow>?) ?? cards;
    notes = (results[7] as List<NoteRow>?) ?? notes;
    folders = (results[8] as List<FolderRow>?) ?? folders;
    settlements = (results[9] as List<SettlementRow>?) ?? settlements;
    approvals = (results[10] as List<ApprovalRow>?) ?? approvals;
    detected = (results[11] as List<DetectedRow>?) ?? detected;
    prefs = (results[12] as PrefsRow?) ?? prefs;

    loading = false;
    notifyListeners();
  }

  // ── Lookups ───────────────────────────────────────────────────────────────

  MemberRow? memberById(String? id) {
    if (id == null) return null;
    for (final m in members) {
      if (m.userId == id) return m;
    }
    return null;
  }

  String memberName(String? id) => memberById(id)?.name ?? 'Someone';

  CategoryRow? categoryByKey(String key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }

  CategoryRow? categoryById(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  SourceRow? sourceById(String? id) {
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── Selection setters ─────────────────────────────────────────────────────

  void setScope(String s) {
    scope = s;
    notifyListeners();
  }

  void setPeriod(String p) {
    period = p;
    notifyListeners();
  }

  void toggleHidden() {
    hidden = !hidden;
    notifyListeners();
  }

  void setSource(String? id) {
    srcFilter = (srcFilter == id) ? null : id;
    notifyListeners();
  }

  Future<void> setChartStyle(String style) async {
    prefs = prefs.copyWith(chartStyle: style);
    notifyListeners();
    await V3Repository.guard(
        'savePrefs', () => _repo.savePrefs(familyId, prefs));
  }

  Future<void> savePrefs(PrefsRow next) async {
    prefs = next;
    notifyListeners();
    await V3Repository.guard(
        'savePrefs', () => _repo.savePrefs(familyId, prefs));
  }

  // ── Derived ───────────────────────────────────────────────────────────────

  /// Transactions inside the selected period, scope and money source.
  List<TxnRow> get scoped => txns.where((t) {
        if (t.ageInDays >= maxDays) return false;
        if (!isFamily && t.userId != scope) return false;
        if (srcFilter != null && t.sourceId != srcFilter) return false;
        return true;
      }).toList();

  double get totalSpent =>
      scoped.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);

  double get totalIncome =>
      scoped.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);

  /// Running balance: opening balances across money sources plus every
  /// transaction ever, not just the visible window.
  double get balance {
    final opening = sources.fold(0.0, (s, m) => s + m.openingBalance);
    final net = txns
        .where((t) => isFamily || t.userId == scope)
        .fold(0.0, (s, t) => s + (t.isExpense ? -t.amount : t.amount));
    return opening + net;
  }

  /// The ceiling the hero bar measures against: the member's own budget in
  /// member scope, otherwise the sum of every category budget.
  double get budgetLimit {
    if (!isFamily) {
      final b = scopeMember?.monthlyBudget;
      if (b != null && b > 0) return b;
    }
    final sum = budgets.fold(0.0, (s, b) => s + b.limitAmount);
    return sum > 0 ? sum : 0;
  }

  double get budgetFraction =>
      budgetLimit <= 0 ? 0 : (totalSpent / budgetLimit).clamp(0.0, 1.0);

  bool get overThreshold =>
      budgetLimit > 0 && (totalSpent / budgetLimit) * 100 >= threshold;

  /// Spend per category key, largest first.
  List<MapEntry<String, double>> get byCategory {
    final map = <String, double>{};
    for (final t in scoped.where((t) => t.isExpense)) {
      map[t.categoryKey] = (map[t.categoryKey] ?? 0) + t.amount;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Spend per member, largest first.
  List<MapEntry<MemberRow, double>> get byMember {
    final map = <String, double>{};
    for (final t in scoped.where((t) => t.isExpense)) {
      final id = t.userId;
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + t.amount;
    }
    final list = <MapEntry<MemberRow, double>>[];
    for (final m in members) {
      final v = map[m.userId];
      if (v != null && v > 0) list.add(MapEntry(m, v));
    }
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  ({double inAmt, double outAmt}) sourceTotals(String sourceId) {
    var inAmt = 0.0, outAmt = 0.0;
    for (final t in txns) {
      if (t.ageInDays >= maxDays) continue;
      if (!isFamily && t.userId != scope) continue;
      if (t.sourceId != sourceId) continue;
      if (t.isExpense) {
        outAmt += t.amount;
      } else {
        inAmt += t.amount;
      }
    }
    return (inAmt: inAmt, outAmt: outAmt);
  }

  List<TxnRow> get recent => scoped.take(5).toList();

  /// Open settlements that involve me, plus every pending approval.
  List<SettlementRow> get myDebts => settlements
      .where((d) => d.fromUser == myId || d.toUser == myId)
      .toList();

  int get attentionCount => approvals.length + myDebts.length;

  int get notifBadge => attentionCount + detected.length;

  /// Budget rows joined to their category and current spend.
  List<({CategoryRow cat, double limit, double spent, int threshold})>
      get budgetRows {
    final spentByKey = {for (final e in byCategory) e.key: e.value};
    final out = <({CategoryRow cat, double limit, double spent, int threshold})>[];
    for (final b in budgets) {
      final c = categoryById(b.categoryId);
      if (c == null) continue;
      out.add((
        cat: c,
        limit: b.limitAmount,
        spent: spentByKey[c.key] ?? 0,
        threshold: b.thresholdPct,
      ));
    }
    out.sort((a, b) => b.spent.compareTo(a.spent));
    return out;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<bool> addTransaction({
    required String title,
    required double amount,
    required String type,
    required String categoryKey,
    String method = 'UPI',
    String? sourceId,
    String? forUserId,
    String? paidBy,
    Map<String, double>? shares,
    String? note,
  }) async {
    final cat = categoryByKey(categoryKey);
    final created = await V3Repository.guard(
      'addTransaction',
      () => _repo.addTransaction(
        familyId: familyId,
        title: title.isEmpty ? (cat?.name ?? 'Expense') : title,
        amount: amount,
        type: type,
        method: method,
        categoryId: cat?.id,
        sourceId: sourceId,
        forUserId: forUserId,
        paidBy: paidBy,
        shares: shares,
        note: note,
      ),
    );
    if (created == null) return false;
    txns = [created, ...txns];
    notifyListeners();
    return true;
  }

  Future<bool> updateTransaction({
    required String id,
    required String title,
    required double amount,
    required String type,
    required String categoryKey,
    String method = 'UPI',
    String? sourceId,
    String? forUserId,
    String? paidBy,
    Map<String, double>? shares,
    String? note,
  }) async {
    final cat = categoryByKey(categoryKey);
    final patch = <String, dynamic>{
      'title': title.isEmpty ? (cat?.name ?? 'Expense') : title,
      'amount': amount,
      'type': type,
      'method': method,
      'category_id': cat?.id,
      'source_id': sourceId,
      'user_id': forUserId ?? myId,
      'paid_by': paidBy ?? myId,
      'split_with':
          shares == null || shares.isEmpty ? null : shares.keys.toList(),
      'shares': shares,
      'note': ?note,
    };
    final ok = await V3Repository.guard('updateTransaction', () async {
      await _repo.updateTransaction(id, patch);
      return true;
    });
    if (ok != true) return false;
    await refresh();
    return true;
  }

  /// Every expense that involves both me and [otherUserId], newest first.
  List<TxnRow> ledgerWith(String otherUserId) {
    final me = myId;
    if (me == null) return const [];
    return txns.where((t) {
      if (!t.isExpense) return false;
      final payer = t.paidBy;
      if (payer == me) return t.shares.containsKey(otherUserId);
      if (payer == otherUserId) return t.shares.containsKey(me);
      return false;
    }).toList();
  }

  /// What [otherUserId] owes me on a single entry, signed: positive means they
  /// owe me, negative means I owe them.
  double signedShare(TxnRow t, String otherUserId) {
    final me = myId;
    if (me == null) return 0;
    if (t.paidBy == me) return t.shareOf(otherUserId);
    if (t.paidBy == otherUserId) return -t.shareOf(me);
    return 0;
  }

  /// Net balance with one person. Positive means they owe me.
  Future<double> pairBalance(String otherUserId) async =>
      await V3Repository.guard(
        'pairBalance',
        () => _repo.pairBalance(familyId, otherUserId),
      ) ??
      0;

  Future<bool> settleWith(String otherUserId, double amount) async {
    final me = myId;
    if (me == null || amount == 0) return false;
    // A positive balance means they owe me, so they are the payer.
    final theyOweMe = amount > 0;
    final ok = await V3Repository.guard<bool>('recordSettlement', () async {
      await _repo.recordSettlement(
        familyId: familyId,
        fromUser: theyOweMe ? otherUserId : me,
        toUser: theyOweMe ? me : otherUserId,
        amount: amount.abs(),
        note: 'Settled up',
      );
      return true;
    });
    if (ok != true) return false;
    await refresh();
    return true;
  }

  Future<void> deleteTransaction(String id) async {
    await V3Repository.guard(
        'deleteTransaction', () => _repo.deleteTransaction(id));
    txns = txns.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<bool> addRecurring({
    required String title,
    required double amount,
    required String cadence,
    required DateTime nextDue,
    String type = 'expense',
    String? categoryKey,
    String? sourceId,
    bool autoPost = true,
    int remindDays = 2,
  }) async {
    final cat = categoryByKey(
        categoryKey ?? (type == 'income' ? 'salary' : 'bills'));
    final created = await V3Repository.guard(
      'addRecurring',
      () => _repo.addRecurring(
        familyId: familyId,
        title: title.isEmpty ? (cat?.name ?? 'Recurring') : title,
        amount: amount,
        cadence: cadence,
        nextDue: nextDue,
        type: type,
        categoryId: cat?.id,
        sourceId: sourceId,
        autoPost: autoPost,
        remindDays: remindDays,
      ),
    );
    if (created == null) return false;
    recurring = [...recurring, created]
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    notifyListeners();
    return true;
  }

  Future<bool> updateRecurring(String id, Map<String, dynamic> patch) async {
    final ok = await V3Repository.guard('updateRecurring', () async {
      await _repo.updateRecurring(id, patch);
      return true;
    });
    if (ok != true) return false;
    await refresh();
    return true;
  }

  Future<bool> deleteRecurring(String id) async {
    final ok = await V3Repository.guard('deleteRecurring', () async {
      await _repo.deleteRecurring(id);
      return true;
    });
    if (ok != true) return false;
    recurring = recurring.where((r) => r.id != id).toList();
    notifyListeners();
    return true;
  }

  Future<int> postDueRecurring() async {
    final count = await V3Repository.guard(
            'postDueRecurring', () => _repo.postDueRecurring(familyId)) ??
        0;
    if (count > 0) {
      await refresh();
    }
    return count;
  }

  Future<bool> removeMember(String userId) async {
    final ok = await V3Repository.guard('removeMember', () async {
      await _repo.removeMember(familyId, userId);
      return true;
    });
    if (ok == true) {
      members = members.where((m) => m.userId != userId).toList();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setMemberRole(String userId, String role) async {
    await V3Repository.guard(
      'setMemberRole',
      () => _repo.setMemberRole(familyId, userId, role),
    );
    await refresh();
  }

  Future<void> setMemberStatus(String userId, String status) async {
    await V3Repository.guard(
      'setMemberStatus',
      () => _repo.setMemberStatus(familyId, userId, status),
    );
    await refresh();
  }

  Future<bool> renameMe(String newName) async {
    final ok = await V3Repository.guard('renameMe', () async {
      await _repo.renameMe(newName);
      return true;
    });
    if (ok == true) {
      await refresh();
      return true;
    }
    return false;
  }

  Future<bool> renameFamily(String newName) async {
    final ok = await V3Repository.guard('renameFamily', () async {
      await _repo.renameFamily(familyId, newName);
      return true;
    });
    if (ok == true) {
      await refresh();
      return true;
    }
    return false;
  }

  Future<bool> deleteMyAccount() async {
    final ok = await V3Repository.guard('deleteMyAccount', () async {
      await _repo.deleteMyAccount();
      return true;
    });
    return ok == true;
  }

  Future<void> settleDebt(String id) async {
    await V3Repository.guard('settle', () => _repo.settle(id));
    settlements = settlements.where((s) => s.id != id).toList();
    notifyListeners();
  }

  Future<void> decideApproval(String id, bool approve) async {
    await V3Repository.guard(
        'decideApproval', () => _repo.decideApproval(id, approve));
    approvals = approvals.where((a) => a.id != id).toList();
    notifyListeners();
  }

  /// Saves rows the user confirmed in the import preview.
  ///
  /// Category text from the file is matched to a real category by key or name;
  /// anything unrecognised is left unset rather than guessed at, so an import
  /// never silently files spending under the wrong heading. Returns how many
  /// rows were written.
  Future<int> importExpenses(List<ImportedExpense> rows) async {
    if (familyId.isEmpty) return 0;
    final chosen = rows.where((r) => r.selected).toList();
    if (chosen.isEmpty) return 0;

    final byKey = {for (final c in categories) c.key.toLowerCase(): c.id};
    final byName = {for (final c in categories) c.name.toLowerCase(): c.id};

    final payload = <Map<String, dynamic>>[];
    for (final r in chosen) {
      final raw = r.category?.trim().toLowerCase();
      final categoryId =
          raw == null ? null : (byKey[raw] ?? byName[raw]);

      payload.add({
        'title': r.title,
        'amount': r.amount,
        'type': r.isIncome ? 'income' : 'expense',
        'category_id': ?categoryId,
        'occurred_at':
            (r.date ?? DateTime.now()).toUtc().toIso8601String(),
      });
    }

    final written = await V3Repository.guard(
      'importExpenses',
      () => _repo.addTransactionsBulk(familyId: familyId, rows: payload),
    );

    if (written != null && written > 0) await refresh();
    return written ?? 0;
  }

  /// Pulls whatever the notification listener captured, drops anything that
  /// duplicates an entry already recorded, and files the rest for review.
  /// Returns how many new candidates were added.
  Future<int> importDetected() async {
    if (familyId.isEmpty) return 0;
    final parsed = await NotificationBridge.drain();
    if (parsed.isEmpty) return 0;

    final existing = txns
        .map((t) => (amount: t.amount, title: t.title, at: t.occurredAt))
        .toList();

    var added = 0;
    for (final p in parsed) {
      final dup = PaymentParser.looksDuplicate(p, existing);
      final ok = await V3Repository.guard<bool>('addDetected', () async {
        await _repo.addDetected(
          familyId: familyId,
          merchant: p.merchant,
          amount: p.amount,
          sourceApp: p.sourceApp,
          method: p.method,
          categoryKey: p.categoryKey,
          confidence: dup ? 'duplicate' : p.confidence.name,
          snippet: p.snippet,
          note: dup
              ? 'Looks like an entry you already added'
              : p.note,
          detectedAt: p.postedAt,
        );
        return true;
      });
      if (ok == true) added++;
    }

    if (added > 0) {
      detected = await V3Repository.guard(
              'detected', () => _repo.detected(familyId)) ??
          detected;
      notifyListeners();
    }
    return added;
  }

  Future<void> resolveDetected(DetectedRow d, String status) async {
    String? txnId;
    if (status == 'added') {
      final cat = d.categoryKey == null ? null : categoryByKey(d.categoryKey!);
      final created = await V3Repository.guard(
        'detected->txn',
        () => _repo.addTransaction(
          familyId: familyId,
          title: d.merchant,
          amount: d.amount,
          type: 'expense',
          method: d.method ?? 'UPI',
          origin: 'notification',
          categoryId: cat?.id,
          occurredAt: d.detectedAt,
        ),
      );
      if (created != null) {
        txnId = created.id;
        txns = [created, ...txns];
      }
    }
    await V3Repository.guard('setDetectedStatus',
        () => _repo.setDetectedStatus(d.id, status, transactionId: txnId));
    detected = detected.where((x) => x.id != d.id).toList();
    notifyListeners();
  }

  Future<bool> addSource(String name, {String kind = 'income'}) async {
    final created = await V3Repository.guard(
      'addSource',
      () => _repo.addSource(familyId: familyId, name: name, kind: kind),
    );
    if (created == null) return false;
    sources = [...sources, created];
    notifyListeners();
    return true;
  }

  Future<void> renameSource(String id, String name) async {
    await V3Repository.guard(
        'renameSource', () => _repo.updateSource(id, name: name));
    await refresh();
  }

  /// Deletes a source that nothing references; archives it otherwise, so the
  /// history of past transactions is never silently rewritten.
  Future<String> removeSource(String id) async {
    final unused =
        await V3Repository.guard('sourceIsUnused', () => _repo.sourceIsUnused(id));
    if (unused == true) {
      await V3Repository.guard('deleteSource', () => _repo.deleteSource(id));
      sources = sources.where((s) => s.id != id).toList();
      notifyListeners();
      return 'deleted';
    }
    await V3Repository.guard('archiveSource', () => _repo.archiveSource(id));
    sources = sources.where((s) => s.id != id).toList();
    notifyListeners();
    return 'archived';
  }

  Future<bool> saveNote({
    String? id,
    required String title,
    required List<NoteBlock> blocks,
    bool pinned = false,
    bool isPrivate = false,
    String? folderId,
  }) async {
    final saved = await V3Repository.guard(
      'saveNote',
      () => _repo.saveNote(
        familyId: familyId,
        id: id,
        title: title,
        content: blocksToPlainText(blocks),
        blocks: blocks.map((b) => b.toJson()).toList(),
        pinned: pinned,
        visibility: isPrivate ? 'private' : 'family',
        folderId: folderId,
      ),
    );
    if (saved == null) return false;
    final i = notes.indexWhere((n) => n.id == saved.id);
    notes = i == -1 ? [saved, ...notes] : [...notes]
      ..[i == -1 ? 0 : i] = saved;
    notifyListeners();
    return true;
  }

  Future<bool> createFolder(String name) async {
    final created = await V3Repository.guard(
      'createFolder',
      () => _repo.createFolder(familyId: familyId, name: name),
    );
    if (created == null) return false;
    folders = [...folders, created];
    notifyListeners();
    return true;
  }

  Future<void> deleteFolder(String id) async {
    await V3Repository.guard('deleteFolder', () => _repo.deleteFolder(id));
    folders = folders.where((f) => f.id != id).toList();
    notes = notes
        .map((n) => n.folderId == id ? n : n)
        .toList(); // rows reload on next refresh; folder_id is SET NULL server-side
    notifyListeners();
  }

  int notesInFolder(String folderId) =>
      notes.where((n) => n.folderId == folderId).length;

  Future<void> deleteNote(String id) async {
    await V3Repository.guard('deleteNote', () => _repo.deleteNote(id));
    notes = notes.where((n) => n.id != id).toList();
    notifyListeners();
  }

  Future<String?> createInvite(String role, double? spendLimit) =>
      V3Repository.guard(
        'createInvite',
        () => _repo.createInvite(
            familyId: familyId, role: role, spendLimit: spendLimit),
      );

  // ── Presentation helpers ──────────────────────────────────────────────────

  /// The design's icon/colour for a category key, falling back to the row's own
  /// stored colour when it is a custom category.
  V3Cat catStyle(String key) {
    final design = V3Design.cats[key];
    if (design != null) return design;
    final row = categoryByKey(key);
    return V3Cat(
      key,
      row?.name ?? key,
      null,
      V3Design.cat(key).icon,
      V3Design.parseHex(row?.color) ?? V3Design.cat(key).color,
    );
  }

  String money(num v) => V3Design.inrHidden(v, hidden);
  String moneyShort(num v) => V3Design.inrShort(v, hidden: hidden);
}
