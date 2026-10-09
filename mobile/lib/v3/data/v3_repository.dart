import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import 'v3_models.dart';

/// All Supabase access for the v3 screens.
///
/// Reads are family-scoped; RLS enforces that server-side, so a missing filter
/// here cannot leak another household's data — but the filters are written
/// anyway so queries stay cheap.
class V3Repository {
  V3Repository(this._db);

  final SupabaseClient _db;

  String? get currentUserId => _db.auth.currentUser?.id;

  // ── Families and membership ───────────────────────────────────────────────

  Future<List<FamilyRow>> myFamilies() async {
    final rows = await _db
        .from('family_memberships')
        .select('families(id,name,kind,invite_code,owner_id)')
        .eq('user_id', currentUserId!)
        .eq('status', 'active');
    return (rows as List)
        .map((r) => r['families'])
        .whereType<Map<String, dynamic>>()
        .map(FamilyRow.fromJson)
        .toList();
  }

  Future<FamilyRow> createFamily(String name, {String kind = 'Family'}) async {
    final row = await _db.rpc('create_family', params: {
      'p_name': name,
      'p_kind': kind,
    });
    return FamilyRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Honours a configured invite when one matches, otherwise the family's own
  /// permanent code — [redeem_invite] handles both.
  Future<FamilyRow> joinByCode(String code) async {
    final row = await _db.rpc('redeem_invite', params: {'p_code': code});
    return FamilyRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<List<MemberRow>> members(String familyId) async {
    final rows = await _db
        .from('family_memberships')
        .select(
            'user_id,role,status,relationship,avatar_hue,monthly_budget,is_allowance,profiles(full_name)')
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => MemberRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> setMemberStatus(
      String familyId, String userId, String status) async {
    await _db
        .from('family_memberships')
        .update({'status': status})
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  Future<void> setMemberRole(
      String familyId, String userId, String role) async {
    try {
      await _db.rpc('set_member_role', params: {
        'p_family': familyId,
        'p_user': userId,
        'p_role': role,
      });
    } catch (_) {
      await _db
          .from('family_memberships')
          .update({'role': role})
          .eq('family_id', familyId)
          .eq('user_id', userId);
    }
  }

  Future<void> removeMember(String familyId, String userId) async {
    try {
      await _db.rpc('remove_member', params: {
        'p_family': familyId,
        'p_user': userId,
      });
    } catch (_) {
      await _db
          .from('family_memberships')
          .delete()
          .eq('family_id', familyId)
          .eq('user_id', userId);
    }
  }

  Future<void> renameMe(String newName) async {
    await _db.rpc('rename_me', params: {'p_name': newName});
  }

  Future<void> renameFamily(String familyId, String newName) async {
    await _db.rpc('rename_family', params: {
      'p_family': familyId,
      'p_name': newName,
    });
  }

  Future<void> deleteMyAccount() async {
    await _db.rpc('delete_my_account');
  }

  // ── Reference data ────────────────────────────────────────────────────────

  Future<List<CategoryRow>> categories(String familyId) async {
    final rows = await _db
        .from('categories')
        .select('id,key,name,icon,color,parent_id')
        .eq('family_id', familyId)
        .order('name');
    return (rows as List)
        .map((r) => CategoryRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<CategoryRow> addCategory({
    required String familyId,
    required String name,
    required String key,
    String? icon,
    String? color,
    String? parentId,
  }) async {
    final row = await _db
        .from('categories')
        .insert({
          'family_id': familyId,
          'name': name.trim(),
          'key': key.trim(),
          if (icon != null && icon.isNotEmpty) 'icon': icon,
          if (color != null && color.isNotEmpty) 'color': color,
          if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
        })
        .select('id,key,name,icon,color,parent_id')
        .single();
    return CategoryRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<CategoryRow> updateCategory({
    required String id,
    required String name,
    String? icon,
    String? color,
    String? parentId,
  }) async {
    final patch = <String, dynamic>{
      'name': name.trim(),
      'icon': (icon != null && icon.isNotEmpty) ? icon : null,
      'color': (color != null && color.isNotEmpty) ? color : null,
      'parent_id': (parentId != null && parentId.isNotEmpty) ? parentId : null,
    };
    final row = await _db
        .from('categories')
        .update(patch)
        .eq('id', id)
        .select('id,key,name,icon,color,parent_id')
        .single();
    return CategoryRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }

  Future<List<SourceRow>> sources(String familyId) async {
    final rows = await _db
        .from('money_sources')
        .select('id,name,kind,opening_balance,sort_order')
        .eq('family_id', familyId)
        .eq('archived', false)
        .order('sort_order');
    return (rows as List)
        .map((r) => SourceRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<SourceRow> addSource({
    required String familyId,
    required String name,
    String kind = 'income',
    double openingBalance = 0,
  }) async {
    final row = await _db
        .from('money_sources')
        .insert({
          'family_id': familyId,
          'name': name,
          'kind': kind,
          'opening_balance': openingBalance,
          'sort_order': 99,
        })
        .select('id,name,kind,opening_balance,sort_order')
        .single();
    return SourceRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateSource(
    String id, {
    String? name,
    String? kind,
    double? openingBalance,
  }) async {
    await _db.from('money_sources').update({
      'name': ?name,
      'kind': ?kind,
      'opening_balance': ?openingBalance,
    }).eq('id', id);
  }

  /// True when nothing references this source, so it is safe to delete rather
  /// than archive.
  Future<bool> sourceIsUnused(String id) async {
    final t = await _db
        .from('transactions')
        .select('id')
        .eq('source_id', id)
        .limit(1);
    if ((t as List).isNotEmpty) return false;
    final r = await _db
        .from('recurring_charges')
        .select('id')
        .eq('source_id', id)
        .limit(1);
    return (r as List).isEmpty;
  }

  Future<void> deleteSource(String id) async {
    await _db.from('money_sources').delete().eq('id', id);
  }

  Future<void> archiveSource(String id) async {
    await _db.from('money_sources').update({'archived': true}).eq('id', id);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<TxnRow>> transactions(String familyId, {int limit = 500}) async {
    final rows = await _db
        .from('transactions')
        .select(
            'id,family_id,user_id,paid_by,source_id,category_id,card_id,title,amount,type,method,origin,occurred_at,split,note,categories(key),transaction_shares(user_id,amount)')
        .eq('family_id', familyId)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => TxnRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Inserts many transactions in one round trip.
  ///
  /// An import can be hundreds of rows, and inserting them one at a time was
  /// both slow and liable to leave a half-finished import behind if the
  /// connection dropped partway.
  Future<int> addTransactionsBulk({
    required String familyId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return 0;

    final uid = currentUserId;
    final payload = [
      for (final r in rows)
        {
          'family_id': familyId,
          'user_id': uid,
          'paid_by': uid,
          'origin': 'import',
          'method': 'Other',
          ...r,
        },
    ];

    final inserted =
        await _db.from('transactions').insert(payload).select('id');
    return (inserted as List).length;
  }

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
    final row = await _db
        .from('transactions')
        .insert({
          'family_id': familyId,
          'user_id': forUserId ?? currentUserId,
          'paid_by': paidBy ?? forUserId ?? currentUserId,
          'title': title,
          'amount': amount,
          'type': type,
          'method': method,
          'origin': origin,
          'category_id': ?categoryId,
          'source_id': ?sourceId,
          'card_id': ?cardId,
          'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
          if (note != null && note.isNotEmpty) 'note': note,
        })
        .select(
            'id,family_id,user_id,paid_by,source_id,category_id,card_id,title,amount,type,method,origin,occurred_at,split,note,categories(key),transaction_shares(user_id,amount)')
        .single();

    final created = TxnRow.fromJson(Map<String, dynamic>.from(row));

    // Shares are rows, so they are written after the transaction exists.
    if (shares != null && shares.isNotEmpty) {
      await _db.from('transaction_shares').insert([
        for (final e in shares.entries)
          if (e.value > 0)
            {
              'transaction_id': created.id,
              'user_id': e.key,
              'amount': e.value,
            },
      ]);
      return TxnRow.fromJson({
        ...Map<String, dynamic>.from(row),
        'transaction_shares': [
          for (final e in shares.entries)
            if (e.value > 0) {'user_id': e.key, 'amount': e.value},
        ],
      });
    }
    return created;
  }

  /// Net between the caller and [otherUserId]. Positive means they owe you.
  Future<double> pairBalance(String familyId, String otherUserId) async {
    final v = await _db.rpc('pair_balance', params: {
      'p_family': familyId,
      'p_other': otherUserId,
    });
    return v == null ? 0 : (v as num).toDouble();
  }

  /// Records that a debt between two people has been paid off.
  Future<void> recordSettlement({
    required String familyId,
    required String fromUser,
    required String toUser,
    required double amount,
    String? note,
  }) async {
    await _db.from('settlements').insert({
      'family_id': familyId,
      'from_user': fromUser,
      'to_user': toUser,
      'amount': amount,
      'note': note,
      'status': 'settled',
      'settled_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> patch) async {
    await _db.from('transactions').update(patch).eq('id', id);
  }

  /// Patches many transactions in chunks, like [deleteTransactionsBulk].
  Future<int> updateTransactionsBulk(
    List<String> ids,
    Map<String, dynamic> patch,
  ) async {
    var updated = 0;
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, i + 100 < ids.length ? i + 100 : ids.length);
      final rows = await _db
          .from('transactions')
          .update(patch)
          .inFilter('id', chunk)
          .select('id');
      updated += (rows as List).length;
    }
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    await _db.from('transactions').delete().eq('id', id);
  }

  /// Deletes multiple transactions in chunks so large batch selections never
  /// exceed query-string limits. Returns the number of deleted rows.
  Future<int> deleteTransactionsBulk(List<String> ids) async {
    if (ids.isEmpty) return 0;
    var removed = 0;
    for (var i = 0; i < ids.length; i += 100) {
      final end = (i + 100 < ids.length) ? i + 100 : ids.length;
      final chunk = ids.sublist(i, end);
      final rows = await _db
          .from('transactions')
          .delete()
          .inFilter('id', chunk)
          .select('id');
      removed += (rows as List).length;
    }
    return removed;
  }

  /// Deletes all imported transactions (`origin = 'import'`) in [familyId],
  /// optionally restricted to [userId]. Returns the number of deleted rows.
  Future<int> deleteImportedTransactions(
    String familyId, {
    String? userId,
  }) async {
    var q = _db
        .from('transactions')
        .delete()
        .eq('family_id', familyId)
        .eq('origin', 'import');
    if (userId != null) {
      q = q.eq('user_id', userId);
    }
    final rows = await q.select('id');
    return (rows as List).length;
  }

  // ── Budgets, recurring, cards ─────────────────────────────────────────────

  Future<List<BudgetRow>> budgets(String familyId) async {
    final rows = await _db
        .from('budgets')
        .select('id,category_id,limit_amount,period,threshold_pct')
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => BudgetRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> upsertBudget({
    required String familyId,
    required String categoryId,
    required double limitAmount,
    String period = 'monthly',
    int thresholdPct = 80,
  }) async {
    await _db.from('budgets').upsert({
      'family_id': familyId,
      'category_id': categoryId,
      'limit_amount': limitAmount,
      'period': period,
      'threshold_pct': thresholdPct,
    }, onConflict: 'family_id,category_id,period');
  }

  static const _recurringCols =
      'id,family_id,owner_user_id,title,amount,type,cadence,next_due,category_id,source_id,card_id,active,auto_post,remind_days,categories(key)';
  static const _recurringColsLegacy =
      'id,family_id,title,amount,cadence,next_due,category_id,source_id,card_id,active,auto_post,remind_days,categories(key)';

  Future<List<RecurringRow>> recurring(String familyId) async {
    List rows;
    try {
      rows = await _db
          .from('recurring_charges')
          .select(_recurringCols)
          .eq('family_id', familyId)
          .eq('active', true)
          .order('next_due');
    } catch (_) {
      rows = await _db
          .from('recurring_charges')
          .select(_recurringColsLegacy)
          .eq('family_id', familyId)
          .eq('active', true)
          .order('next_due');
    }
    return rows
        .map((r) => RecurringRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<RecurringRow> addRecurring({
    required String familyId,
    required String title,
    required double amount,
    required String cadence,
    required DateTime nextDue,
    String type = 'expense',
    String? categoryId,
    String? sourceId,
    bool autoPost = true,
    int remindDays = 2,
    String? ownerUserId,
  }) async {
    final resolvedOwner = ownerUserId ?? currentUserId;
    final payload = <String, dynamic>{
      'family_id': familyId,
      // Defaults to the signed-in user so a charge always has an owner; the
      // posting function relies on this to attribute the transaction.
      'owner_user_id': resolvedOwner,
      'title': title,
      'amount': amount,
      'cadence': cadence,
      'next_due': nextDue.toIso8601String().substring(0, 10),
      'type': type,
      'category_id': ?categoryId,
      'source_id': ?sourceId,
      'auto_post': autoPost,
      'remind_days': remindDays,
      'active': true,
    };

    Map<String, dynamic> row;
    try {
      row = await _db
          .from('recurring_charges')
          .insert(payload)
          .select(_recurringCols)
          .single();
    } catch (_) {
      // Fallback if 'type' or 'owner_user_id' column is not yet created:
      payload
        ..remove('type')
        ..remove('owner_user_id');
      row = await _db
          .from('recurring_charges')
          .insert(payload)
          .select(_recurringColsLegacy)
          .single();
    }
    return RecurringRow.fromJson({
      ...row,
      'type': row['type'] ?? type,
      'owner_user_id': row['owner_user_id'] ?? resolvedOwner,
    });
  }

  Future<void> updateRecurring(String id, Map<String, dynamic> patch) async {
    await _db.from('recurring_charges').update(patch).eq('id', id);
  }

  Future<void> deleteRecurring(String id) async {
    await _db.from('recurring_charges').delete().eq('id', id);
  }

  Future<int> postDueRecurring(String familyId) async {
    try {
      final res = await _db.rpc('post_due_recurring', params: {'p_family': familyId});
      return (res as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<CardRow>> cards(String familyId) async {
    final rows = await _db
        .from('cards')
        .select('id,label,last4,credit_limit,billing_day,due_day')
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => CardRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addCard({
    required String familyId,
    required String label,
    String? last4,
    double creditLimit = 0,
    int? billingDay,
    int? dueDay,
  }) async {
    await _db.from('cards').insert({
      'family_id': familyId,
      'label': label,
      if (last4 != null && last4.isNotEmpty) 'last4': last4,
      'credit_limit': creditLimit,
      'billing_day': ?billingDay,
      'due_day': ?dueDay,
    });
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  static const _noteCols =
      'id,title,content,blocks,pinned,visibility,created_by,updated_by,folder_id,updated_at,version';
  static const _noteColsLegacy =
      'id,title,content,blocks,pinned,visibility,created_by,updated_by,folder_id,updated_at';

  Future<List<NoteRow>> notes(String familyId) async {
    List rows;
    try {
      rows = await _db
          .from('notes')
          .select(_noteCols)
          .eq('family_id', familyId)
          .order('pinned', ascending: false)
          .order('updated_at', ascending: false);
    } catch (_) {
      rows = await _db
          .from('notes')
          .select(_noteColsLegacy)
          .eq('family_id', familyId)
          .order('pinned', ascending: false)
          .order('updated_at', ascending: false);
    }
    return rows
        .map((r) => NoteRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<NoteRow> saveNote({
    required String familyId,
    String? id,
    required String title,
    required String content,
    required List<Map<String, dynamic>> blocks,
    bool pinned = false,
    String visibility = 'family',
    String? folderId,
  }) async {
    final res = await saveNoteConditional(
      familyId: familyId,
      id: id,
      title: title,
      content: content,
      blocks: blocks,
      pinned: pinned,
      visibility: visibility,
      folderId: folderId,
    );
    return res.row;
  }

  /// Conditional note save using `save_note_v2` RPC when available, falling
  /// back to direct table insert/update if the RPC is not present.
  ///
  /// When [expectedVersion] is provided and another writer saved first, returns
  /// `NoteSaveResult(ok: false, row: <winning server row>)`.
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
    try {
      final raw = await _db.rpc('save_note_v2', params: {
        'p_family_id': familyId,
        'p_id': id,
        'p_title': title,
        'p_content': content,
        'p_blocks': blocks,
        'p_pinned': pinned,
        'p_visibility': visibility,
        'p_folder_id': folderId,
        'p_expected_version': expectedVersion,
      });
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final ok = (map['ok'] as bool?) ?? true;
        final rowMap = Map<String, dynamic>.from(map['row'] as Map);
        return NoteSaveResult(ok: ok, row: NoteRow.fromJson(rowMap));
      }
    } catch (_) {
      // Fallback to direct table access if RPC is unavailable
    }

    final payload = {
      'family_id': familyId,
      'title': title,
      'content': content,
      'blocks': blocks,
      'pinned': pinned,
      'visibility': visibility,
      'folder_id': folderId,
      'updated_by': currentUserId,
      if (id == null) 'created_by': currentUserId,
    };
    final row = id == null
        ? await _db.from('notes').insert(payload).select().single()
        : await _db
            .from('notes')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
    return NoteSaveResult(
      ok: true,
      row: NoteRow.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  Future<void> deleteNote(String id) async {
    await _db.from('notes').delete().eq('id', id);
  }

  Future<List<FolderRow>> folders(String familyId) async {
    final rows = await _db
        .from('note_folders')
        .select('id,name,icon,color,sort_order')
        .eq('family_id', familyId)
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map((r) => FolderRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<FolderRow> createFolder({
    required String familyId,
    required String name,
    String icon = 'folder',
    String color = '#9184D9',
  }) async {
    final row = await _db
        .from('note_folders')
        .insert({
          'family_id': familyId,
          'name': name,
          'icon': icon,
          'color': color,
          'created_by': currentUserId,
        })
        .select()
        .single();
    return FolderRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteFolder(String id) async {
    await _db.from('note_folders').delete().eq('id', id);
  }

  // ── Direct messages ───────────────────────────────────────────────────────

  Future<List<DirectMessageRow>> directMessages(
    String familyId, {
    int limit = 300,
  }) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db
        .from('direct_messages')
        .select(
            'id,family_id,sender_id,recipient_id,body,kind,image_data,created_at,read_at')
        .eq('family_id', familyId)
        .or('sender_id.eq.$uid,recipient_id.eq.$uid')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((r) =>
            DirectMessageRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<DirectMessageRow> sendDirectMessage({
    required String familyId,
    required String recipientId,
    required String body,
    String kind = 'text',
    String? imageData,
  }) async {
    final uid = currentUserId!;
    final row = await _db
        .from('direct_messages')
        .insert({
          'family_id': familyId,
          'sender_id': uid,
          'recipient_id': recipientId,
          'body': body.trim(),
          'kind': kind,
          'image_data': ?imageData,
        })
        .select(
            'id,family_id,sender_id,recipient_id,body,kind,image_data,created_at,read_at')
        .single();
    return DirectMessageRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteDirectMessage(String messageId) async {
    try {
      await _db.rpc('delete_direct_message', params: {
        'p_message_id': messageId,
      });
    } catch (_) {
      await _db.from('direct_messages').delete().eq('id', messageId);
    }
  }

  Future<void> clearDirectThread({
    required String familyId,
    required String partnerId,
  }) async {
    try {
      await _db.rpc('clear_direct_thread', params: {
        'p_family_id': familyId,
        'p_partner_id': partnerId,
      });
    } catch (_) {
      final uid = currentUserId;
      if (uid == null) return;
      await _db
          .from('direct_messages')
          .delete()
          .eq('family_id', familyId)
          .or('and(sender_id.eq.$uid,recipient_id.eq.$partnerId),and(sender_id.eq.$partnerId,recipient_id.eq.$uid)');
    }
  }

  Future<void> markDirectMessagesRead({
    required String familyId,
    required String senderId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('family_id', familyId)
        .eq('sender_id', senderId)
        .eq('recipient_id', uid)
        .isFilter('read_at', null);
  }

  // ── Settlements, approvals, detected ──────────────────────────────────────

  Future<List<SettlementRow>> settlements(String familyId) async {
    final rows = await _db
        .from('settlements')
        .select('id,from_user,to_user,amount,note,status')
        .eq('family_id', familyId)
        .eq('status', 'open');
    return (rows as List)
        .map((r) => SettlementRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> settle(String id) async {
    await _db.from('settlements').update({
      'status': 'settled',
      'settled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<ApprovalRow>> approvals(String familyId) async {
    final rows = await _db
        .from('approvals')
        .select('id,requested_by,kind,reason,payload,status,created_at')
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ApprovalRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> decideApproval(String id, bool approve) async {
    await _db.from('approvals').update({
      'status': approve ? 'approved' : 'rejected',
      'decided_by': currentUserId,
      'decided_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<DetectedRow>> detected(String familyId,
      {String status = 'pending'}) async {
    final rows = await _db
        .from('detected_payments')
        .select(
            'id,source_app,merchant,amount,method,category_key,confidence,snippet,note,status,detected_at')
        .eq('family_id', familyId)
        .eq('status', status)
        .order('detected_at', ascending: false);
    return (rows as List)
        .map((r) => DetectedRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addDetected({
    required String familyId,
    required String merchant,
    required double amount,
    String? sourceApp,
    String? method,
    String? categoryKey,
    String confidence = 'high',
    String? snippet,
    String? note,
    required DateTime detectedAt,
  }) async {
    await _db.from('detected_payments').insert({
      'family_id': familyId,
      'user_id': currentUserId,
      'merchant': merchant,
      'amount': amount,
      'source_app': ?sourceApp,
      'method': ?method,
      'category_key': ?categoryKey,
      'confidence': confidence,
      'snippet': ?snippet,
      'note': ?note,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<void> setDetectedStatus(String id, String status,
      {String? transactionId}) async {
    await _db.from('detected_payments').update({
      'status': status,
      'transaction_id': ?transactionId,
    }).eq('id', id);
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<PrefsRow> prefs(String familyId) async {
    final rows = await _db
        .from('user_preferences')
        .select()
        .eq('family_id', familyId)
        .eq('user_id', currentUserId!)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return const PrefsRow();
    return PrefsRow.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  Future<void> savePrefs(String familyId, PrefsRow p) async {
    await _db.from('user_preferences').upsert({
      'user_id': currentUserId,
      'family_id': familyId,
      ...p.toJson(),
    }, onConflict: 'user_id,family_id');
  }

  // ── Invites ───────────────────────────────────────────────────────────────

  Future<String> createInvite({
    required String familyId,
    required String role,
    double? spendLimit,
  }) async {
    final row = await _db
        .from('family_invites')
        .insert({
          'family_id': familyId,
          'role': role,
          'spend_limit': ?spendLimit,
          'created_by': currentUserId,
        })
        .select('code')
        .single();
    return row['code'].toString();
  }

  /// Wraps a call so a network or RLS failure surfaces in the log and as null,
  /// instead of tearing down the widget tree mid-build.
  static Future<T?> guard<T>(String context, Future<T> Function() op) async {
    try {
      return await op();
    } catch (err, stack) {
      AppLog.error(context, err, stack);
      return null;
    }
  }
}
