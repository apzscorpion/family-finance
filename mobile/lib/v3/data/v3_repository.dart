import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import 'chat_media.dart';
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
    const base =
        'user_id,role,status,relationship,avatar_hue,monthly_budget,is_allowance,hidden_from,ai_daily_limit,ai_models';
    Future<dynamic> load(String profile) => _db
        .from('family_memberships')
        .select('$base,profiles($profile)')
        .eq('family_id', familyId);
    dynamic rows;
    try {
      rows = await load('full_name,upi_id,avatar_path,about,avatar_updated_at');
    } on PostgrestException {
      // shortcut: profile photo columns missing until the migration is applied; drop once it is live.
      rows = await load('full_name,upi_id');
    }
    return (rows as List)
        .map((r) => MemberRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// My built-in AI allowance today, the models on offer and the ones I may
  /// pick: {limit, used, remaining, models: [{id,label,vision}], allowed}.
  Future<Map<String, dynamic>> aiInfo(String familyId) async {
    final res = await _db.functions
        .invoke('ai-proxy', body: {'op': 'info', 'family_id': familyId});
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  /// App admins only (checked on the server): provider keys and everyone's
  /// use over the last week.
  Future<Map<String, dynamic>> aiAdmin() async {
    final res = await _db.functions.invoke('ai-proxy', body: {'op': 'admin'});
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  /// Owner: daily limit (null = default); owner or admin: approved models.
  Future<void> setMemberAi(
      String familyId, String userId, int? limit, List<String> models) async {
    await _db.rpc('set_member_ai', params: {
      'p_family': familyId,
      'p_user': userId,
      'p_limit': limit,
      'p_models': models,
    });
  }

  /// Who may not see my money in this family.
  Future<void> setHiddenFrom(String familyId, List<String> userIds) async {
    await _db.rpc('set_hidden_from',
        params: {'p_family': familyId, 'p_users': userIds});
  }

  /// Sends money to another member: my expense, their income to approve.
  Future<void> transferMoney({
    required String familyId,
    required String toUserId,
    required double amount,
    String? note,
    String? sourceId,
    String method = 'UPI',
  }) async {
    await _db.rpc('transfer_money', params: {
      'p_family': familyId,
      'p_to': toUserId,
      'p_amount': amount,
      'p_note': note,
      'p_source': sourceId,
      'p_method': method,
    });
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
    // No direct-update fallback: the server's owner rules live in the RPC.
    await _db.rpc('set_member_role', params: {
      'p_family': familyId,
      'p_user': userId,
      'p_role': role,
    });
  }

  /// Approve or reject income someone added for me.
  Future<void> decideIncome(String txnId, bool approve) async {
    await _db.rpc('decide_income',
        params: {'p_txn': txnId, 'p_approve': approve});
  }

  /// Sends income I added, and they rejected, for approval again.
  Future<void> resendIncome(String txnId) async {
    await _db.rpc('resend_income', params: {'p_txn': txnId});
  }

  /// Makes [userId] the primary owner; I stay an owner.
  Future<void> transferOwnership(String familyId, String userId) async {
    await _db.rpc('transfer_ownership',
        params: {'p_family': familyId, 'p_user': userId});
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

  /// Uploads [jpeg] as my photo (replacing any old one), or removes it when null.
  Future<void> setMyAvatar(Uint8List? jpeg) async {
    final uid = currentUserId!;
    final path = '$uid/avatar.jpg';
    final bucket = _db.storage.from('avatars');
    if (jpeg == null) {
      await bucket.remove([path]);
    } else {
      await bucket.uploadBinary(path, jpeg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
    }
    await _db.from('profiles').update({
      'avatar_path': jpeg == null ? null : path,
      'avatar_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<void> setMyAbout(String about) async {
    final v = about.trim();
    await _db
        .from('profiles')
        .update({'about': v.isEmpty ? null : v}).eq('id', currentUserId!);
  }

  Future<void> setMyUpiId(String upiId) async {
    try {
      await _db.rpc('set_my_upi_id', params: {'p_upi': upiId});
    } catch (_) {
      // Direct update fallback if RPC has not been executed yet
      await _db.from('profiles').update({
        'upi_id': upiId.trim().isEmpty ? null : upiId.trim(),
      }).eq('id', currentUserId!);
    }
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
        .select('*')
        .eq('family_id', familyId)
        .order('sort_order')
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
    String kind = 'expense',
    int sortOrder = 0,
  }) async {
    final base = {
      'family_id': familyId,
      'name': name.trim(),
      'key': key.trim(),
      if (icon != null && icon.isNotEmpty) 'icon': icon,
      if (color != null && color.isNotEmpty) 'color': color,
      if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
    };
    Future<dynamic> insert(Map<String, dynamic> values) =>
        _db.from('categories').insert(values).select('*').single();
    dynamic row;
    try {
      row = await insert({...base, 'kind': kind, 'sort_order': sortOrder});
    } on PostgrestException catch (e) {
      // PGRST204: the category migration has not added these columns yet.
      if (e.code != 'PGRST204') rethrow;
      row = await insert(base);
    }
    return CategoryRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Which main categories a sub is also under, and its linked people.
  Future<CategoryRow> updateCategoryLinks(
    String id, {
    required List<String> alsoParentIds,
    required List<String> memberIds,
  }) async {
    final row = await _db
        .from('categories')
        .update({'also_parent_ids': alsoParentIds, 'member_ids': memberIds})
        .eq('id', id)
        .select('*')
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
        .select('*')
        .single();
    return CategoryRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }

  /// Writes each category's position as its index in [orderedIds].
  Future<void> reorderCategories(List<String> orderedIds) async {
    await Future.wait([
      for (var i = 0; i < orderedIds.length; i++)
        _db
            .from('categories')
            .update({'sort_order': i + 1}).eq('id', orderedIds[i]),
    ]);
  }

  Future<List<SourceRow>> sources(String familyId) async {
    final rows = await _db
        .from('money_sources')
        .select('id,name,kind,opening_balance,opening_cash,sort_order,owner_id,member_ids')
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
        .select('id,name,kind,opening_balance,opening_cash,sort_order,owner_id,member_ids')
        .single();
    return SourceRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateSource(
    String id, {
    String? name,
    String? kind,
    double? openingBalance,
    double? openingCash,
  }) async {
    await _db.from('money_sources').update({
      'name': ?name,
      'kind': ?kind,
      'opening_balance': ?openingBalance,
      'opening_cash': ?openingCash,
    }).eq('id', id);
  }

  Future<List<WalletMoveRow>> walletMoves(String familyId) async {
    final rows = await _db
        .from('wallet_moves')
        .select('id,source_id,amount,to_cash,occurred_at')
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => WalletMoveRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<WalletMoveRow> addWalletMove({
    required String familyId,
    required String sourceId,
    required double amount,
    required bool toCash,
  }) async {
    final row = await _db
        .from('wallet_moves')
        .insert({
          'family_id': familyId,
          'source_id': sourceId,
          'amount': amount,
          'to_cash': toCash,
        })
        .select('id,source_id,amount,to_cash,occurred_at')
        .single();
    return WalletMoveRow.fromJson(Map<String, dynamic>.from(row));
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
            'id,family_id,user_id,paid_by,source_id,category_id,card_id,title,amount,type,method,origin,occurred_at,split,note,sub_category_id,status,added_by,categories!transactions_category_id_fkey(key),transaction_shares(user_id,amount)')
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

  /// Rewrites earlier imported rows in place; each row carries its `id`.
  Future<int> upsertTransactionsBulk({
    required String familyId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return 0;
    final uid = currentUserId;
    var written = 0;
    for (var i = 0; i < rows.length; i += 200) {
      final chunk = rows.sublist(i, i + 200 < rows.length ? i + 200 : rows.length);
      final result = await _db.from('transactions').upsert([
        for (final r in chunk)
          {
            'family_id': familyId,
            'user_id': uid,
            'paid_by': uid,
            'origin': 'import',
            'method': 'Other',
            ...r,
          },
      ], onConflict: 'id').select('id');
      written += (result as List).length;
    }
    return written;
  }

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
          'sub_category_id': ?subCategoryId,
          'source_id': ?sourceId,
          'card_id': ?cardId,
          'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
          if (note != null && note.isNotEmpty) 'note': note,
        })
        .select(
            'id,family_id,user_id,paid_by,source_id,category_id,card_id,title,amount,type,method,origin,occurred_at,split,note,sub_category_id,status,added_by,categories!transactions_category_id_fkey(key),transaction_shares(user_id,amount)')
        .single();

    final created = TxnRow.fromJson(Map<String, dynamic>.from(row));

    // Shares are rows, so they are written after the transaction exists.
    if (shares != null && shares.isNotEmpty) {
      await _db.from('transaction_shares').insert([
        for (final e in shares.entries)
          if (e.value >= 0)
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
            if (e.value >= 0) {'user_id': e.key, 'amount': e.value},
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

  /// [shares] replaces the entry's whole split; null or empty clears it.
  Future<void> updateTransaction(
    String id,
    Map<String, dynamic> patch, {
    Map<String, double>? shares,
  }) async {
    await _db.from('transactions').update(patch).eq('id', id);
    await _db.from('transaction_shares').delete().eq('transaction_id', id);
    final rows = [
      for (final e in (shares ?? const <String, double>{}).entries)
        if (e.value >= 0)
          {'transaction_id': id, 'user_id': e.key, 'amount': e.value},
    ];
    if (rows.isNotEmpty) await _db.from('transaction_shares').insert(rows);
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

  // ── Savings Goals ──────────────────────────────────────────────────────────

  Future<List<GoalRow>> goals(String familyId) async {
    try {
      final rows = await _db
          .from('savings_goals')
          .select('id,family_id,created_by,name,target_amount,current_amount,target_date,icon,color,category_id,status,created_at')
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => GoalRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> createGoal({
    required String familyId,
    required String name,
    required double targetAmount,
    double initialAmount = 0,
    DateTime? targetDate,
    String icon = 'target',
    String color = '#9184D9',
    String? categoryId,
  }) async {
    await _db.from('savings_goals').insert({
      'family_id': familyId,
      'created_by': currentUserId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': initialAmount,
      if (targetDate != null)
        'target_date':
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
      'icon': icon,
      'color': color,
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      'status': 'active',
    });
  }

  Future<void> contributeToGoal({
    required String goalId,
    required double newAmount,
  }) async {
    await _db.from('savings_goals').update({
      'current_amount': newAmount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', goalId);
  }

  Future<void> deleteGoal(String goalId) async {
    await _db.from('savings_goals').delete().eq('id', goalId);
  }

  Future<List<GoldHoldingRow>> goldHoldings(String familyId) async {
    try {
      final rows = await _db
          .from('gold_holdings')
          .select('id,family_id,owner_id,item_name,metal_type,weight_grams,purity_karat,notes,created_at')
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => GoldHoldingRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<GoldHoldingRow?> addGoldHolding({
    required String familyId,
    required String itemName,
    String metalType = 'gold',
    required double weightGrams,
    int purityKarat = 24,
    String? notes,
  }) async {
    try {
      final row = await _db.from('gold_holdings').insert({
        'family_id': familyId,
        'owner_id': currentUserId,
        'item_name': itemName,
        'metal_type': metalType,
        'weight_grams': weightGrams,
        'purity_karat': purityKarat,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }).select().single();
      return GoldHoldingRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGoldHolding(String id) async {
    await _db.from('gold_holdings').delete().eq('id', id);
  }

  // ── Pending Refunds Watchdog ───────────────────────────────────────────────

  Future<List<PendingRefundRow>> pendingRefunds(String familyId) async {
    try {
      final rows = await _db
          .from('pending_refunds')
          .select()
          .eq('family_id', familyId)
          .order('initiated_at', ascending: false);
      return (rows as List)
          .map((r) => PendingRefundRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<PendingRefundRow?> addPendingRefund({
    required String familyId,
    required String merchant,
    required double amount,
    String? utrRef,
    String? sourceApp,
    DateTime? expectedBy,
    String? notes,
  }) async {
    try {
      final row = await _db.from('pending_refunds').insert({
        'family_id': familyId,
        'user_id': currentUserId,
        'merchant': merchant,
        'amount': amount,
        if (utrRef != null && utrRef.isNotEmpty) 'utr_ref': utrRef,
        'source_app': ?sourceApp,
        'status': 'pending',
        'initiated_at': DateTime.now().toUtc().toIso8601String(),
        if (expectedBy != null) 'expected_by': expectedBy.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }).select().single();
      return PendingRefundRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> updateRefundStatus(String id, String status) async {
    await _db.from('pending_refunds').update({
      'status': status,
      if (status == 'received') 'received_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ── Daily Deliveries Diary (Milk, Newspaper, Water Cans) ───────────────────

  Future<List<DeliverySubscriptionRow>> deliverySubscriptions(String familyId) async {
    try {
      final subs = await _db
          .from('delivery_subscriptions')
          .select()
          .eq('family_id', familyId);
      final subList = subs as List;
      if (subList.isEmpty) return const [];

      final skips = await _db
          .from('delivery_skips')
          .select('subscription_id,skip_date');
      final skipMap = <String, List<String>>{};
      for (final s in (skips as List)) {
        final subId = s['subscription_id'].toString();
        final date = s['skip_date']?.toString() ?? '';
        if (date.isNotEmpty) {
          skipMap.putIfAbsent(subId, () => []).add(date);
        }
      }

      return subList
          .map((r) => DeliverySubscriptionRow.fromJson(
                Map<String, dynamic>.from(r as Map),
                skipMap[r['id'].toString()] ?? const [],
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<DeliverySubscriptionRow?> addDeliverySubscription({
    required String familyId,
    required String name,
    String itemType = 'milk',
    required double unitPrice,
    String? vendorName,
    String? vendorPhone,
  }) async {
    try {
      final row = await _db.from('delivery_subscriptions').insert({
        'family_id': familyId,
        'name': name,
        'item_type': itemType,
        'unit_price': unitPrice,
        'vendor_name': ?vendorName,
        'vendor_phone': ?vendorPhone,
      }).select().single();
      return DeliverySubscriptionRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleDeliverySkip(String subscriptionId, String skipDate) async {
    try {
      final existing = await _db
          .from('delivery_skips')
          .select('id')
          .eq('subscription_id', subscriptionId)
          .eq('skip_date', skipDate)
          .maybeSingle();

      if (existing != null) {
        await _db.from('delivery_skips').delete().eq('id', existing['id']);
      } else {
        await _db.from('delivery_skips').insert({
          'subscription_id': subscriptionId,
          'skip_date': skipDate,
        });
      }
    } catch (_) {}
  }

  // ── Domestic Staff & Helper Ledger ────────────────────────────────────────

  Future<List<DomesticStaffRow>> domesticStaff(String familyId) async {
    try {
      final staffRows = await _db
          .from('domestic_staff')
          .select()
          .eq('family_id', familyId);
      final staffList = staffRows as List;
      if (staffList.isEmpty) return const [];

      // Calculate advances and leaves
      final ledgerRows = await _db
          .from('staff_ledger')
          .select('staff_id,entry_type,amount,entry_date');
      final advancesMap = <String, double>{};
      final leavesMap = <String, int>{};

      final currentMonthPrefix = DateTime.now().toIso8601String().substring(0, 7);

      for (final l in (ledgerRows as List)) {
        final sId = l['staff_id'].toString();
        final type = l['entry_type']?.toString();
        final rawAmt = l['amount'];
        final amt = rawAmt is num ? rawAmt.toDouble() : (double.tryParse('$rawAmt') ?? 0.0);
        final date = l['entry_date']?.toString() ?? '';

        if (type == 'advance') {
          advancesMap[sId] = (advancesMap[sId] ?? 0.0) + amt;
        } else if (type == 'salary_paid') {
          // salary clears advance
          advancesMap[sId] = ((advancesMap[sId] ?? 0.0) - amt).clamp(0.0, double.infinity);
        }

        if (type == 'leave' && date.startsWith(currentMonthPrefix)) {
          leavesMap[sId] = (leavesMap[sId] ?? 0) + 1;
        }
      }

      return staffList
          .map((r) => DomesticStaffRow.fromJson(
                Map<String, dynamic>.from(r as Map),
                advances: advancesMap[r['id'].toString()] ?? 0.0,
                leaves: leavesMap[r['id'].toString()] ?? 0,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<DomesticStaffRow?> addDomesticStaff({
    required String familyId,
    required String name,
    String role = 'Maid',
    String? phone,
    required double monthlySalary,
    int salaryDay = 1,
  }) async {
    try {
      final row = await _db.from('domestic_staff').insert({
        'family_id': familyId,
        'name': name,
        'role': role,
        'phone': ?phone,
        'monthly_salary': monthlySalary,
        'salary_day': salaryDay,
      }).select().single();
      return DomesticStaffRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> addStaffLedgerEntry({
    required String staffId,
    required String entryType, // 'salary_paid', 'advance', 'leave', 'bonus'
    double amount = 0,
    required DateTime date,
    String? note,
  }) async {
    try {
      await _db.from('staff_ledger').insert({
        'staff_id': staffId,
        'entry_type': entryType,
        'amount': amount,
        'entry_date': date.toIso8601String().substring(0, 10),
        if (note != null && note.isNotEmpty) 'note': note,
      });
    } catch (_) {}
  }

  // ── Guardian Mode & Security Alerts ───────────────────────────────────────

  Future<List<SecurityAlertRow>> securityAlerts(String familyId) async {
    try {
      final rows = await _db
          .from('security_alerts')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => SecurityAlertRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SecurityAlertRow?> createSecurityAlert({
    required String familyId,
    required String userId,
    required String alertType,
    required String title,
    required String description,
    String? snippet,
    String severity = 'critical',
  }) async {
    try {
      final row = await _db.from('security_alerts').insert({
        'family_id': familyId,
        'user_id': userId,
        'alert_type': alertType,
        'title': title,
        'description': description,
        'snippet': ?snippet,
        'severity': severity,
        'status': 'active',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();
      return SecurityAlertRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSecurityAlertStatus(String id, String status) async {
    try {
      await _db.from('security_alerts').update({'status': status}).eq('id', id);
    } catch (_) {}
  }

  Future<void> updateMemberProtection(String userId, bool isProtected) async {
    try {
      await _db.from('profiles').update({'is_protected_member': isProtected}).eq('id', userId);
    } catch (_) {}
  }

  // ── Credit Cards & Cashback Optimizer ─────────────────────────────────────

  Future<List<CreditCardRow>> creditCards(String familyId) async {
    try {
      final rows = await _db
          .from('credit_cards')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => CreditCardRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<CreditCardRow?> addCreditCard({
    required String familyId,
    required String cardName,
    required String bank,
    String cardNetwork = 'Visa',
    String? lastFour,
    String? ownerUserId,
    int rewardPointsBalance = 0,
    DateTime? rewardPointsExpiry,
    Map<String, double> cashbackRules = const {},
  }) async {
    try {
      final row = await _db.from('credit_cards').insert({
        'family_id': familyId,
        'card_name': cardName,
        'bank': bank,
        'card_network': cardNetwork,
        'last_four': ?lastFour,
        'owner_user_id': ?ownerUserId,
        'reward_points_balance': rewardPointsBalance,
        if (rewardPointsExpiry != null)
          'reward_points_expiry': rewardPointsExpiry.toUtc().toIso8601String(),
        'cashback_rules': cashbackRules,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();
      return CreditCardRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> updateCreditCardPoints(String cardId, int points, DateTime? expiry) async {
    try {
      await _db.from('credit_cards').update({
        'reward_points_balance': points,
        if (expiry != null) 'reward_points_expiry': expiry.toUtc().toIso8601String(),
      }).eq('id', cardId);
    } catch (_) {}
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

  static const _dmColumns =
      'id,family_id,sender_id,recipient_id,body,kind,image_data,created_at,'
      'read_at,delivered_at,media_path,media_name,media_mime,media_size,media_kind,'
      'media_duration_ms,view_once,viewed_at';

  Future<List<DirectMessageRow>> directMessages(
    String familyId, {
    int limit = 300,
  }) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db
        .from('direct_messages')
        .select(_dmColumns)
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
    Map<String, dynamic> media = const {},
  }) async {
    final uid = currentUserId!;
    // The id is made here, so a retry after a lost reply cannot duplicate
    // the message: the second insert hits the key and the row is read back.
    final id = media['id']?.toString() ?? const Uuid().v4();
    final insert = {
      'family_id': familyId,
      'sender_id': uid,
      'recipient_id': recipientId,
      'body': body.trim(),
      'kind': kind,
      'image_data': ?imageData,
      ...media,
      'id': id,
    };
    // A dead connection (network switch) hangs instead of failing, so each
    // try is short and a fresh one follows.
    for (var attempt = 1;; attempt++) {
      try {
        final row = await _db
            .from('direct_messages')
            .insert(insert)
            .select(_dmColumns)
            .single()
            .timeout(const Duration(seconds: 6)); // 3 tries fit in guard()'s 20 s
        return DirectMessageRow.fromJson(Map<String, dynamic>.from(row));
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // only "already there" is success
        final row = await _db
            .from('direct_messages')
            .select(_dmColumns)
            .eq('id', id)
            .single();
        return DirectMessageRow.fromJson(Map<String, dynamic>.from(row));
      } catch (e) {
        if (attempt >= 3 || !_isConnectivity(e)) rethrow;
      }
    }
  }

  StorageFileApi get _chatMedia => _db.storage.from(kChatMediaBucket);

  Future<void> uploadChatMedia(String path, Uint8List bytes, String mime) =>
      _chatMedia.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime),
      );

  Future<Uint8List> downloadChatMedia(String path) => _chatMedia.download(path);

  /// Short-lived URL for playback, thumbnails and browser downloads.
  Future<String> chatMediaUrl(String path, {int seconds = 3600}) =>
      _chatMedia.createSignedUrl(path, seconds);

  Future<void> removeChatMedia(List<String> paths) => _chatMedia.remove(paths);

  /// Recipient only: marks a view-once message opened and deletes its file.
  Future<void> markViewedOnce(String messageId) =>
      _db.rpc('mark_viewed_once', params: {'p_message_id': messageId});

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

  /// Marks every message to me that hasn't reached me yet as delivered.
  Future<void> markDirectMessagesDelivered(String familyId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db
        .from('direct_messages')
        .update({'delivered_at': DateTime.now().toUtc().toIso8601String()})
        .eq('family_id', familyId)
        .eq('recipient_id', uid)
        .isFilter('delivered_at', null);
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
  /// True while the last network call failed for connectivity reasons.
  static final offline = ValueNotifier<bool>(false);

  /// No call may hang a tap: a request with no answer in [guardTimeout] fails
  /// like any other error instead of leaving the button looking dead.
  static Duration guardTimeout = const Duration(seconds: 20);

  static Future<T?> guard<T>(String context, Future<T> Function() op) async {
    try {
      final result = await op().timeout(guardTimeout);
      if (offline.value) offline.value = false;
      return result;
    } catch (err, stack) {
      if (_isConnectivity(err)) {
        offline.value = true;
        AppLog.error(context, 'offline: ${err.runtimeType}');
      } else {
        AppLog.error(context, err, stack);
      }
      return null;
    }
  }

  static bool _isConnectivity(Object err) {
    if (err is TimeoutException) return true;
    final text = err.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('Network is unreachable') ||
        text.contains('Connection closed');
  }
}
