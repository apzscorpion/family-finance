import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../v3_design.dart';
import 'note_blocks.dart';

/// Models mirroring the v2/v3 Postgres schema. Field names match the column
/// names so the mapping stays obvious.

DateTime _ts(dynamic v) =>
    v == null ? DateTime.now() : DateTime.parse(v.toString()).toLocal();

double _num(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

class FamilyRow {
  final String id;
  final String name;
  final String kind;
  final String inviteCode;
  final String? ownerId;

  const FamilyRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.inviteCode,
    this.ownerId,
  });

  factory FamilyRow.fromJson(Map<String, dynamic> j) => FamilyRow(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'Family',
        inviteCode: j['invite_code']?.toString() ?? '',
        ownerId: j['owner_id']?.toString(),
      );
}

/// A person in a family: the membership row joined to their profile.
class MemberRow {
  final String userId;
  final String name;
  final String role;
  final String status;
  final String relationship;
  final int hue;
  final double? monthlyBudget;
  final bool isAllowance;
  final String? upiId;
  final bool isProtectedMember;

  /// People this member hides their money from (owners still see it).
  final List<String> hiddenFrom;

  /// Built-in AI requests a day (null = the default) and the models an
  /// owner or admin approved for them to pick.
  final int? aiDailyLimit;
  final List<String> aiModels;

  /// Profile photo in the public `avatars` bucket, and the short About line.
  final String? avatarPath;
  final DateTime? avatarUpdatedAt;
  final String? about;

  const MemberRow({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    required this.relationship,
    required this.hue,
    this.monthlyBudget,
    this.isAllowance = false,
    this.upiId,
    this.isProtectedMember = false,
    this.hiddenFrom = const [],
    this.aiDailyLimit,
    this.aiModels = const [],
    this.avatarPath,
    this.avatarUpdatedAt,
    this.about,
  });

  factory MemberRow.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'];
    final name = profile is Map
        ? (profile['full_name']?.toString() ?? '')
        : (j['full_name']?.toString() ?? '');
    final upi = profile is Map
        ? profile['upi_id']?.toString()
        : j['upi_id']?.toString();
    String? prof(String k) {
      final v = (profile is Map ? profile[k] : j[k])?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final isProtected = profile is Map
        ? (profile['is_protected_member'] as bool?)
        : (j['is_protected_member'] as bool?);
    return MemberRow(
      userId: j['user_id'].toString(),
      name: name.isEmpty ? 'Member' : name,
      role: j['role']?.toString() ?? 'member',
      status: j['status']?.toString() ?? 'active',
      relationship: j['relationship']?.toString() ?? '',
      hue: (j['avatar_hue'] as num?)?.toInt() ?? 289,
      monthlyBudget: j['monthly_budget'] == null
          ? null
          : _num(j['monthly_budget']),
      isAllowance: (j['is_allowance'] as bool?) ?? false,
      upiId: (upi == null || upi.trim().isEmpty) ? null : upi.trim(),
      isProtectedMember: isProtected ?? false,
      hiddenFrom: [
        for (final u in (j['hidden_from'] as List?) ?? const []) u.toString()
      ],
      aiDailyLimit: (j['ai_daily_limit'] as num?)?.toInt(),
      aiModels: [
        for (final m in (j['ai_models'] as List?) ?? const []) m.toString()
      ],
      avatarPath: prof('avatar_path'),
      avatarUpdatedAt: DateTime.tryParse(prof('avatar_updated_at') ?? ''),
      about: prof('about'),
    );
  }

  /// Public URL of the photo; `?v=` changes on every upload so caches refresh.
  String? get avatarUrl => avatarPath == null
      ? null
      : '${SupabaseService.supabaseUrl}/storage/v1/object/public/avatars/'
          '$avatarPath?v=${avatarUpdatedAt?.millisecondsSinceEpoch ?? 0}';

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
  Color get color => V3Design.hue(hue);
  bool get isActive => status == 'active';
}

class SourceRow {
  final String id;
  final String name;
  final String kind;
  final double openingBalance;
  final int sortOrder;

  /// Part of [openingBalance] held as cash; the rest was in the bank.
  final double openingCash;

  /// Whose money this is. Null only for rows from before accounts had owners.
  final String? ownerId;

  /// Co-owners of a joint account (not offered in the app yet).
  final List<String> memberIds;

  const SourceRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.sortOrder,
    this.openingCash = 0,
    this.ownerId,
    this.memberIds = const [],
  });

  /// Whether [userId] owns this account (or co-owns a joint one).
  bool isOf(String? userId) =>
      ownerId == null || ownerId == userId || memberIds.contains(userId);

  factory SourceRow.fromJson(Map<String, dynamic> j) => SourceRow(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'savings',
        openingBalance: _num(j['opening_balance']),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        openingCash: _num(j['opening_cash']),
        ownerId: j['owner_id']?.toString(),
        memberIds: [
          for (final m in (j['member_ids'] as List?) ?? const []) m.toString()
        ],
      );

  /// Falls back to the design's icon/hue for the seeded source names.
  V3Source get design =>
      V3Design.sources.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
        orElse: () => V3Design.sources.last,
      );
}

/// Money moved between bank and cash inside one source: not spending.
class WalletMoveRow {
  final String id;
  final String sourceId;
  final double amount;

  /// true: withdrawn from the bank as cash; false: cash deposited.
  final bool toCash;
  final DateTime occurredAt;

  const WalletMoveRow({
    required this.id,
    required this.sourceId,
    required this.amount,
    required this.toCash,
    required this.occurredAt,
  });

  factory WalletMoveRow.fromJson(Map<String, dynamic> j) => WalletMoveRow(
        id: j['id'].toString(),
        sourceId: j['source_id'].toString(),
        amount: _num(j['amount']),
        toCash: j['to_cash'] == true,
        occurredAt:
            DateTime.tryParse(j['occurred_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

class CategoryRow {
  final String id;
  final String key;
  final String name;
  final String? icon;
  final String? color;
  final String? parentId;

  /// Position set in Settings; the add screen lists categories in this order.
  final int sortOrder;

  /// 'expense' or 'income'.
  final String kind;

  /// Sub-categories only: other main categories this one is also listed
  /// under ("with fam" under Food, Travel and Games).
  final List<String> alsoParentIds;

  /// People linked to this category: picking it fills "For" with them, and
  /// picking exactly them selects it.
  final List<String> memberIds;

  const CategoryRow({
    required this.id,
    required this.key,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
    this.sortOrder = 0,
    this.kind = 'expense',
    this.alsoParentIds = const [],
    this.memberIds = const [],
  });

  bool get isSubCategory => parentId != null && parentId!.isNotEmpty;

  /// Whether this sub-category is listed under main category [mainId].
  bool isUnder(String mainId) =>
      parentId == mainId || alsoParentIds.contains(mainId);

  CategoryRow copyWith({
    String? id,
    String? key,
    String? name,
    String? icon,
    String? color,
    String? parentId,
  }) {
    return CategoryRow(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder,
      kind: kind,
      alsoParentIds: alsoParentIds,
      memberIds: memberIds,
    );
  }

  factory CategoryRow.fromJson(Map<String, dynamic> j) => CategoryRow(
        id: j['id'].toString(),
        key: j['key']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString(),
        color: j['color']?.toString(),
        parentId: j['parent_id']?.toString(),
        // Fallbacks keep the old built-in order and split until the
        // category migration has run.
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? _builtInOrder(j['key']),
        kind: j['kind']?.toString() ??
            (V3Design.incomeCats.contains(j['key']) ? 'income' : 'expense'),
        alsoParentIds: _ids(j['also_parent_ids']),
        memberIds: _ids(j['member_ids']),
      );

  static List<String> _ids(Object? v) =>
      v is List ? [for (final x in v) '$x'] : const [];

  static int _builtInOrder(Object? key) {
    final i = [...V3Design.expenseCats, ...V3Design.incomeCats].indexOf('$key');
    return i < 0 ? 100 : i + 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (parentId != null) 'parent_id': parentId,
      };
}

class TxnRow {
  final String id;
  final String familyId;
  final String? userId;
  final String? sourceId;
  final String? categoryId;

  /// Optional sub-category, alongside the main [categoryId].
  final String? subCategoryId;
  final String? cardId;

  /// Who actually paid. May differ from [userId], the entry's owner.
  final String? paidBy;

  /// What each person owes of this transaction. Empty means nobody owes
  /// anybody — a plain personal expense.
  final Map<String, double> shares;
  final String title;
  final double amount;
  final String type;
  final String method;
  final String origin;
  final DateTime occurredAt;
  final Map<String, dynamic>? split;
  final String? note;

  /// Resolved client-side from [categoryId] so screens can colour rows without
  /// a second lookup per row.
  final String categoryKey;

  /// posted | pending | rejected. Income someone adds for another person
  /// waits for that person's approval; only posted entries count.
  final String status;

  /// Who entered it.
  final String? addedBy;

  const TxnRow({
    required this.id,
    required this.familyId,
    this.userId,
    this.sourceId,
    this.categoryId,
    this.subCategoryId,
    this.cardId,
    this.paidBy,
    this.shares = const {},
    required this.title,
    required this.amount,
    required this.type,
    this.method = 'UPI',
    this.origin = 'manual',
    required this.occurredAt,
    this.split,
    this.note,
    this.categoryKey = 'shopping',
    this.status = 'posted',
    this.addedBy,
  });

  factory TxnRow.fromJson(Map<String, dynamic> j) {
    final cat = j['categories'];
    return TxnRow(
      id: j['id'].toString(),
      familyId: j['family_id'].toString(),
      userId: j['user_id']?.toString(),
      sourceId: j['source_id']?.toString(),
      categoryId: j['category_id']?.toString(),
      subCategoryId: j['sub_category_id']?.toString(),
      cardId: j['card_id']?.toString(),
      paidBy: (j['paid_by'] ?? j['user_id'])?.toString(),
      shares: {
        for (final r in (j['transaction_shares'] as List? ?? const []))
          if (r is Map && r['user_id'] != null)
            r['user_id'].toString(): _num(r['amount']),
      },
      title: j['title']?.toString() ?? '',
      amount: _num(j['amount']),
      type: j['type']?.toString() ?? 'expense',
      method: j['method']?.toString() ?? 'UPI',
      origin: j['origin']?.toString() ?? 'manual',
      occurredAt: _ts(j['occurred_at']),
      split: j['split'] is Map
          ? Map<String, dynamic>.from(j['split'] as Map)
          : null,
      note: j['note']?.toString(),
      categoryKey: cat is Map ? (cat['key']?.toString() ?? 'shopping') : 'shopping',
      status: j['status']?.toString() ?? 'posted',
      addedBy: j['added_by']?.toString(),
    );
  }

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isPosted => status == 'posted';

  /// Same entry filed under main category [main] with sub-category [subId].
  TxnRow refiled(CategoryRow main, String subId) => TxnRow(
    id: id,
    familyId: familyId,
    userId: userId,
    sourceId: sourceId,
    categoryId: main.id,
    subCategoryId: subId,
    cardId: cardId,
    paidBy: paidBy,
    shares: shares,
    title: title,
    amount: amount,
    type: type,
    method: method,
    origin: origin,
    occurredAt: occurredAt,
    split: split,
    note: note,
    categoryKey: main.key,
    status: status,
    addedBy: addedBy,
  );

  /// Whole calendar days between this transaction and today.
  int get ageInDays {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    return a.difference(b).inDays;
  }

  /// Everyone who owes something on this entry, payer excluded.
  List<String> get splitWith =>
      shares.keys.where((u) => u != paidBy).toList();

  bool get isShared => shares.length > 1 || splitWith.isNotEmpty;

  /// What [userId] owes on this entry.
  double shareOf(String? uid) => uid == null ? 0 : (shares[uid] ?? 0);

  String get timeLabel {
    final h = occurredAt.hour;
    final m = occurredAt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }
}

class BudgetRow {
  final String id;
  final String? categoryId;
  final double limitAmount;
  final String period;
  final int thresholdPct;

  const BudgetRow({
    required this.id,
    this.categoryId,
    required this.limitAmount,
    required this.period,
    required this.thresholdPct,
  });

  factory BudgetRow.fromJson(Map<String, dynamic> j) => BudgetRow(
        id: j['id'].toString(),
        categoryId: j['category_id']?.toString(),
        limitAmount: _num(j['limit_amount']),
        period: j['period']?.toString() ?? 'monthly',
        thresholdPct: (j['threshold_pct'] as num?)?.toInt() ?? 80,
      );
}

class GoalRow {
  final String id;
  final String familyId;
  final String? createdBy;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String icon;
  final String color;
  final String? categoryId;
  final String status;
  final DateTime createdAt;

  const GoalRow({
    required this.id,
    required this.familyId,
    this.createdBy,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.icon = 'target',
    this.color = '#9184D9',
    this.categoryId,
    this.status = 'active',
    required this.createdAt,
  });

  factory GoalRow.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return GoalRow(
      id: j['id'].toString(),
      familyId: j['family_id']?.toString() ?? '',
      createdBy: j['created_by']?.toString(),
      name: j['name']?.toString() ?? 'Savings Goal',
      targetAmount: _num(j['target_amount']),
      currentAmount: _num(j['current_amount']),
      targetDate: parseDate(j['target_date']),
      icon: j['icon']?.toString() ?? 'target',
      color: j['color']?.toString() ?? '#9184D9',
      categoryId: j['category_id']?.toString(),
      status: j['status']?.toString() ?? 'active',
      createdAt: _ts(j['created_at']),
    );
  }

  double get progress => targetAmount <= 0
      ? 0.0
      : (currentAmount / targetAmount).clamp(0.0, 1.0);

  bool get isCompleted => currentAmount >= targetAmount;

  double get remainingAmount => (targetAmount - currentAmount).clamp(0, targetAmount);

  /// Estimate remaining months based on target date
  int? get remainingMonths {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final diffDays = targetDate!.difference(now).inDays;
    if (diffDays <= 0) return 0;
    return (diffDays / 30).ceil();
  }
}

class GoldHoldingRow {
  final String id;
  final String familyId;
  final String? ownerId;
  final String itemName;
  final String metalType; // 'gold' or 'silver'
  final double weightGrams;
  final int purityKarat; // 18, 21, 22, 24
  final String? notes;
  final DateTime createdAt;

  const GoldHoldingRow({
    required this.id,
    required this.familyId,
    this.ownerId,
    required this.itemName,
    this.metalType = 'gold',
    required this.weightGrams,
    this.purityKarat = 24,
    this.notes,
    required this.createdAt,
  });

  factory GoldHoldingRow.fromJson(Map<String, dynamic> j) => GoldHoldingRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        ownerId: j['owner_id']?.toString(),
        itemName: j['item_name']?.toString() ?? 'Gold item',
        metalType: j['metal_type']?.toString() ?? 'gold',
        weightGrams: _num(j['weight_grams']),
        purityKarat: (j['purity_karat'] as num?)?.toInt() ?? 24,
        notes: j['notes']?.toString(),
        createdAt: _ts(j['created_at']),
      );

  /// 24k equivalent weight in grams
  double get pure24kGrams => (weightGrams * purityKarat) / 24.0;
}

class PendingRefundRow {
  final String id;
  final String familyId;
  final String? userId;
  final String merchant;
  final double amount;
  final String? utrRef;
  final String? sourceApp;
  final String status; // 'pending', 'received', 'disputed'
  final DateTime initiatedAt;
  final DateTime? expectedBy;
  final DateTime? receivedAt;
  final String? notes;

  const PendingRefundRow({
    required this.id,
    required this.familyId,
    this.userId,
    required this.merchant,
    required this.amount,
    this.utrRef,
    this.sourceApp,
    this.status = 'pending',
    required this.initiatedAt,
    this.expectedBy,
    this.receivedAt,
    this.notes,
  });

  factory PendingRefundRow.fromJson(Map<String, dynamic> j) => PendingRefundRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        userId: j['user_id']?.toString(),
        merchant: j['merchant']?.toString() ?? 'Merchant Refund',
        amount: _num(j['amount']),
        utrRef: j['utr_ref']?.toString(),
        sourceApp: j['source_app']?.toString() ?? 'UPI',
        status: j['status']?.toString() ?? 'pending',
        initiatedAt: _ts(j['initiated_at']),
        expectedBy: j['expected_by'] != null ? _ts(j['expected_by']) : null,
        receivedAt: j['received_at'] != null ? _ts(j['received_at']) : null,
        notes: j['notes']?.toString(),
      );

  bool get isPending => status == 'pending';
  bool get isDelayed => isPending && DateTime.now().difference(initiatedAt).inDays >= 4;
}

class DeliverySubscriptionRow {
  final String id;
  final String familyId;
  final String name;
  final String itemType; // 'milk', 'newspaper', 'water', 'other'
  final double unitPrice;
  final String? vendorName;
  final String? vendorPhone;
  final List<String> skippedDates; // YYYY-MM-DD strings

  const DeliverySubscriptionRow({
    required this.id,
    required this.familyId,
    required this.name,
    this.itemType = 'milk',
    required this.unitPrice,
    this.vendorName,
    this.vendorPhone,
    this.skippedDates = const [],
  });

  factory DeliverySubscriptionRow.fromJson(Map<String, dynamic> j, [List<String> skips = const []]) =>
      DeliverySubscriptionRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Milk / Newspaper',
        itemType: j['item_type']?.toString() ?? 'milk',
        unitPrice: _num(j['unit_price']),
        vendorName: j['vendor_name']?.toString(),
        vendorPhone: j['vendor_phone']?.toString(),
        skippedDates: skips,
      );

  /// Compute bill for a given month
  double computeMonthlyBill(int year, int month) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final monthSkips = skippedDates.where((d) => d.startsWith(prefix)).length;
    final activeDays = (daysInMonth - monthSkips).clamp(0, daysInMonth);
    return activeDays * unitPrice;
  }
}

class DomesticStaffRow {
  final String id;
  final String familyId;
  final String name;
  final String role; // 'Maid', 'Driver', 'Cook', 'Nanny'
  final String? phone;
  final double monthlySalary;
  final int salaryDay;
  final double advancesBalance;
  final int leavesThisMonth;

  const DomesticStaffRow({
    required this.id,
    required this.familyId,
    required this.name,
    this.role = 'Maid',
    this.phone,
    required this.monthlySalary,
    this.salaryDay = 1,
    this.advancesBalance = 0.0,
    this.leavesThisMonth = 0,
  });

  factory DomesticStaffRow.fromJson(Map<String, dynamic> j, {double advances = 0.0, int leaves = 0}) =>
      DomesticStaffRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Helper',
        role: j['role']?.toString() ?? 'Maid',
        phone: j['phone']?.toString(),
        monthlySalary: _num(j['monthly_salary']),
        salaryDay: (j['salary_day'] as num?)?.toInt() ?? 1,
        advancesBalance: advances,
        leavesThisMonth: leaves,
      );
}

class SecurityAlertRow {
  final String id;
  final String familyId;
  final String userId;
  final String alertType; // 'scam_sms', 'unusual_debit', 'suspicious_payee', 'phishing_link'
  final String title;
  final String description;
  final String? snippet;
  final String severity; // 'warning', 'critical'
  final String status; // 'active', 'dismissed', 'resolved'
  final DateTime createdAt;

  const SecurityAlertRow({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.alertType,
    required this.title,
    required this.description,
    this.snippet,
    this.severity = 'critical',
    this.status = 'active',
    required this.createdAt,
  });

  factory SecurityAlertRow.fromJson(Map<String, dynamic> j) => SecurityAlertRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        userId: j['user_id']?.toString() ?? '',
        alertType: j['alert_type']?.toString() ?? 'scam_sms',
        title: j['title']?.toString() ?? 'Security Warning',
        description: j['description']?.toString() ?? '',
        snippet: j['snippet']?.toString(),
        severity: j['severity']?.toString() ?? 'critical',
        status: j['status']?.toString() ?? 'active',
        createdAt: _ts(j['created_at']),
      );

  bool get isActive => status == 'active';
  bool get isCritical => severity == 'critical';
}

class CreditCardRow {
  final String id;
  final String familyId;
  final String cardName;
  final String bank;
  final String cardNetwork;
  final String? lastFour;
  final String? ownerUserId;
  final int rewardPointsBalance;
  final DateTime? rewardPointsExpiry;
  final Map<String, double> cashbackRules;
  final DateTime createdAt;

  const CreditCardRow({
    required this.id,
    required this.familyId,
    required this.cardName,
    required this.bank,
    this.cardNetwork = 'Visa',
    this.lastFour,
    this.ownerUserId,
    this.rewardPointsBalance = 0,
    this.rewardPointsExpiry,
    this.cashbackRules = const {},
    required this.createdAt,
  });

  factory CreditCardRow.fromJson(Map<String, dynamic> j) {
    final rules = <String, double>{};
    if (j['cashback_rules'] is Map) {
      (j['cashback_rules'] as Map).forEach((k, v) {
        rules[k.toString().toLowerCase()] = _num(v);
      });
    }
    return CreditCardRow(
      id: j['id'].toString(),
      familyId: j['family_id']?.toString() ?? '',
      cardName: j['card_name']?.toString() ?? 'Credit Card',
      bank: j['bank']?.toString() ?? 'Bank',
      cardNetwork: j['card_network']?.toString() ?? 'Visa',
      lastFour: j['last_four']?.toString(),
      ownerUserId: j['owner_user_id']?.toString(),
      rewardPointsBalance: (j['reward_points_balance'] as num?)?.toInt() ?? 0,
      rewardPointsExpiry: j['reward_points_expiry'] != null ? _ts(j['reward_points_expiry']) : null,
      cashbackRules: rules,
      createdAt: _ts(j['created_at']),
    );
  }

  double cashbackFor(String merchantOrCategory) {
    final key = merchantOrCategory.toLowerCase();
    for (final e in cashbackRules.entries) {
      if (key.contains(e.key)) return e.value;
    }
    return cashbackRules['general'] ?? cashbackRules['online'] ?? 1.0;
  }

  bool get hasExpiringPoints {
    if (rewardPointsBalance <= 0 || rewardPointsExpiry == null) return false;
    final days = rewardPointsExpiry!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 30;
  }
}

class RecurringRow {
  final String id;
  final String title;
  final double amount;
  final String cadence;
  final DateTime nextDue;
  final String? categoryId;
  final String categoryKey;
  final bool active;

  /// Either 'expense' or 'income'.
  final String type;
  final String? sourceId;

  /// True when the money leaves the account by itself (an EMI or a standing
  /// instruction), so the server posts the transaction on the due date and the
  /// app only needs to remind for the rest.
  final bool autoPost;
  final int remindDays;

  /// Who the charge belongs to. The posted transaction is attributed to this
  /// person rather than to whoever happened to trigger the posting.
  final String? ownerUserId;

  const RecurringRow({
    required this.id,
    required this.title,
    required this.amount,
    required this.cadence,
    required this.nextDue,
    this.type = 'expense',
    this.sourceId,
    this.categoryId,
    this.categoryKey = 'bills',
    this.active = true,
    this.autoPost = false,
    this.remindDays = 2,
    this.ownerUserId,
  });

  bool get isIncome =>
      type == 'income' || V3Design.incomeCats.contains(categoryKey);
  bool get isExpense => !isIncome;

  factory RecurringRow.fromJson(Map<String, dynamic> j) {
    final cat = j['categories'];
    final cKey = cat is Map ? (cat['key']?.toString() ?? 'bills') : 'bills';
    final inferredType =
        j['type']?.toString() ?? (V3Design.incomeCats.contains(cKey) ? 'income' : 'expense');
    return RecurringRow(
      id: j['id'].toString(),
      title: j['title']?.toString() ?? '',
      amount: _num(j['amount']),
      cadence: j['cadence']?.toString() ?? 'monthly',
      nextDue: _ts(j['next_due']),
      type: inferredType,
      sourceId: j['source_id']?.toString(),
      categoryId: j['category_id']?.toString(),
      categoryKey: cKey,
      active: (j['active'] as bool?) ?? true,
      autoPost: (j['auto_post'] as bool?) ?? false,
      remindDays: (j['remind_days'] as num?)?.toInt() ?? 2,
      ownerUserId: j['owner_user_id']?.toString(),
    );
  }

  int get dueInDays {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(nextDue.year, nextDue.month, nextDue.day);
    return b.difference(a).inDays;
  }
}

class CardRow {
  final String id;
  final String label;
  final String? last4;
  final double creditLimit;
  final int? billingDay;
  final int? dueDay;
  final int remindDays;
  final bool autoPay;

  const CardRow({
    required this.id,
    required this.label,
    this.last4,
    required this.creditLimit,
    this.billingDay,
    this.dueDay,
    this.remindDays = 3,
    this.autoPay = false,
  });

  factory CardRow.fromJson(Map<String, dynamic> j) => CardRow(
        id: j['id'].toString(),
        label: j['label']?.toString() ?? '',
        last4: j['last4']?.toString(),
        creditLimit: _num(j['credit_limit']),
        billingDay: (j['billing_day'] as num?)?.toInt(),
        dueDay: (j['due_day'] as num?)?.toInt(),
        remindDays: (j['remind_days'] as num?)?.toInt() ?? 3,
        autoPay: (j['auto_pay'] as bool?) ?? false,
      );

  int get dueInDays {
    if (dueDay == null) return -1;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, dueDay!);
    if (due.isBefore(now)) due = DateTime(now.year, now.month + 1, dueDay!);
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class FolderRow {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;

  const FolderRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });

  factory FolderRow.fromJson(Map<String, dynamic> j) => FolderRow(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString() ?? 'folder',
        color: j['color']?.toString() ?? '#9184D9',
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class NoteRow {
  final String id;
  final String title;
  final String content;
  final bool pinned;
  final String visibility;
  final String? createdBy;
  final String? updatedBy;
  final String? folderId;
  final DateTime updatedAt;
  final int version;

  /// Structured content. `content` is the flattened mirror used for previews
  /// and search, so it is not the source of truth.
  final List<NoteBlock> blocks;

  const NoteRow({
    required this.id,
    required this.title,
    required this.content,
    required this.pinned,
    this.visibility = 'family',
    this.createdBy,
    this.updatedBy,
    this.folderId,
    required this.updatedAt,
    this.version = 0,
    this.blocks = const [],
  });

  bool get isPrivate => visibility == 'private';

  factory NoteRow.fromJson(Map<String, dynamic> j) => NoteRow(
        id: j['id'].toString(),
        title: j['title']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        pinned: (j['pinned'] as bool?) ?? false,
        visibility: j['visibility']?.toString() ?? 'family',
        createdBy: j['created_by']?.toString(),
        updatedBy: j['updated_by']?.toString(),
        folderId: j['folder_id']?.toString(),
        updatedAt: _ts(j['updated_at']),
        version: (j['version'] as num?)?.toInt() ?? 0,
        blocks: (j['blocks'] as List?)
                ?.whereType<Map>()
                .map((e) => NoteBlock.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

class NoteSaveResult {
  final bool ok;
  final NoteRow row;

  const NoteSaveResult({required this.ok, required this.row});
}

class DirectMessageRow {
  final String id;
  final String familyId;
  final String senderId;
  final String recipientId;
  final String body;
  final String kind;
  final String? imageData;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Storage object in the chat-media bucket; null for text, pokes and the
  /// older base64 photos.
  final String? mediaPath;
  final String? mediaName;
  final String? mediaMime;
  final int? mediaSize;

  /// `image`, `file` or `voice`.
  final String? mediaKind;
  final int? mediaDurationMs;
  final bool viewOnce;
  final DateTime? viewedAt;

  const DirectMessageRow({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.kind = 'text',
    this.imageData,
    this.readAt,
    this.mediaPath,
    this.mediaName,
    this.mediaMime,
    this.mediaSize,
    this.mediaKind,
    this.mediaDurationMs,
    this.viewOnce = false,
    this.viewedAt,
  });

  bool get isRead => readAt != null;
  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;
  bool get isPoke => kind == 'poke';
  bool get isCall => kind == 'call';
  bool get isImage =>
      kind == 'image' && imageData != null && imageData!.isNotEmpty;

  factory DirectMessageRow.fromJson(Map<String, dynamic> j) => DirectMessageRow(
        id: j['id'].toString(),
        familyId: j['family_id']?.toString() ?? '',
        senderId: j['sender_id']?.toString() ?? '',
        recipientId: j['recipient_id']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'text',
        imageData: j['image_data']?.toString(),
        createdAt: _ts(j['created_at']),
        readAt: j['read_at'] == null ? null : _ts(j['read_at']),
        mediaPath: j['media_path']?.toString(),
        mediaName: j['media_name']?.toString(),
        mediaMime: j['media_mime']?.toString(),
        mediaSize: (j['media_size'] as num?)?.toInt(),
        mediaKind: j['media_kind']?.toString(),
        mediaDurationMs: (j['media_duration_ms'] as num?)?.toInt(),
        viewOnce: j['view_once'] == true,
        viewedAt: j['viewed_at'] == null ? null : _ts(j['viewed_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'body': body,
        'kind': kind,
        if (imageData != null) 'image_data': imageData,
        'created_at': createdAt.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
        if (mediaPath != null) 'media_path': mediaPath,
        if (mediaName != null) 'media_name': mediaName,
        if (mediaMime != null) 'media_mime': mediaMime,
        if (mediaSize != null) 'media_size': mediaSize,
        if (mediaKind != null) 'media_kind': mediaKind,
        if (mediaDurationMs != null) 'media_duration_ms': mediaDurationMs,
        'view_once': viewOnce,
        'viewed_at': viewedAt?.toUtc().toIso8601String(),
      };

  DirectMessageRow copyWith({DateTime? readAt, DateTime? viewedAt}) =>
      DirectMessageRow(
        id: id,
        familyId: familyId,
        senderId: senderId,
        recipientId: recipientId,
        body: body,
        kind: kind,
        imageData: imageData,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        mediaPath: mediaPath,
        mediaName: mediaName,
        mediaMime: mediaMime,
        mediaSize: mediaSize,
        mediaKind: mediaKind,
        mediaDurationMs: mediaDurationMs,
        viewOnce: viewOnce,
        viewedAt: viewedAt ?? this.viewedAt,
      );
}

class SettlementRow {
  final String id;
  final String fromUser;
  final String toUser;
  final double amount;
  final String? note;
  final String status;

  const SettlementRow({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    this.note,
    required this.status,
  });

  factory SettlementRow.fromJson(Map<String, dynamic> j) => SettlementRow(
        id: j['id'].toString(),
        fromUser: j['from_user'].toString(),
        toUser: j['to_user'].toString(),
        amount: _num(j['amount']),
        note: j['note']?.toString(),
        status: j['status']?.toString() ?? 'open',
      );
}

class ApprovalRow {
  final String id;
  final String? requestedBy;
  final String kind;
  final String? reason;
  final Map<String, dynamic>? payload;
  final String status;
  final DateTime createdAt;

  const ApprovalRow({
    required this.id,
    this.requestedBy,
    required this.kind,
    this.reason,
    this.payload,
    required this.status,
    required this.createdAt,
  });

  factory ApprovalRow.fromJson(Map<String, dynamic> j) => ApprovalRow(
        id: j['id'].toString(),
        requestedBy: j['requested_by']?.toString(),
        kind: j['kind']?.toString() ?? 'edit',
        reason: j['reason']?.toString(),
        payload: j['payload'] is Map
            ? Map<String, dynamic>.from(j['payload'] as Map)
            : null,
        status: j['status']?.toString() ?? 'pending',
        createdAt: _ts(j['created_at']),
      );
}

class DetectedRow {
  final String id;
  final String? sourceApp;
  final String merchant;
  final double amount;
  final String? method;
  final String? categoryKey;
  final String confidence;
  final String? snippet;
  final String? note;
  final String status;
  final DateTime detectedAt;

  const DetectedRow({
    required this.id,
    this.sourceApp,
    required this.merchant,
    required this.amount,
    this.method,
    this.categoryKey,
    required this.confidence,
    this.snippet,
    this.note,
    required this.status,
    required this.detectedAt,
  });

  factory DetectedRow.fromJson(Map<String, dynamic> j) => DetectedRow(
        id: j['id'].toString(),
        sourceApp: j['source_app']?.toString(),
        merchant: j['merchant']?.toString() ?? '',
        amount: _num(j['amount']),
        method: j['method']?.toString(),
        categoryKey: j['category_key']?.toString(),
        confidence: j['confidence']?.toString() ?? 'high',
        snippet: j['snippet']?.toString(),
        note: j['note']?.toString(),
        status: j['status']?.toString() ?? 'pending',
        detectedAt: _ts(j['detected_at']),
      );
}

class PrefsRow {
  final bool budgetAlerts;
  final bool familyAlerts;
  final bool approvalAlerts;
  final bool dailyDigest;
  final bool smsAuto;
  final bool smsCategorize;
  final bool smsReview;
  final bool smsPromo;
  final bool lockApp;
  final bool hideOnOpen;
  final int alertThreshold;
  final String chartStyle;
  final String heroMetric;

  const PrefsRow({
    this.budgetAlerts = true,
    this.familyAlerts = true,
    this.approvalAlerts = true,
    this.dailyDigest = false,
    this.smsAuto = true,
    this.smsCategorize = true,
    this.smsReview = true,
    this.smsPromo = true,
    this.lockApp = true,
    this.hideOnOpen = false,
    this.alertThreshold = 80,
    this.chartStyle = 'donut',
    this.heroMetric = 'spent',
  });

  factory PrefsRow.fromJson(Map<String, dynamic> j) => PrefsRow(
        budgetAlerts: (j['budget_alerts'] as bool?) ?? true,
        familyAlerts: (j['family_alerts'] as bool?) ?? true,
        approvalAlerts: (j['approval_alerts'] as bool?) ?? true,
        dailyDigest: (j['daily_digest'] as bool?) ?? false,
        smsAuto: (j['sms_auto'] as bool?) ?? true,
        smsCategorize: (j['sms_categorize'] as bool?) ?? true,
        smsReview: (j['sms_review'] as bool?) ?? true,
        smsPromo: (j['sms_promo'] as bool?) ?? true,
        lockApp: (j['lock_app'] as bool?) ?? true,
        hideOnOpen: (j['hide_on_open'] as bool?) ?? false,
        alertThreshold: (j['alert_threshold'] as num?)?.toInt() ?? 80,
        chartStyle: j['chart_style']?.toString() ?? 'donut',
        heroMetric: j['hero_metric']?.toString() ?? 'spent',
      );

  Map<String, dynamic> toJson() => {
        'budget_alerts': budgetAlerts,
        'family_alerts': familyAlerts,
        'approval_alerts': approvalAlerts,
        'daily_digest': dailyDigest,
        'sms_auto': smsAuto,
        'sms_categorize': smsCategorize,
        'sms_review': smsReview,
        'sms_promo': smsPromo,
        'lock_app': lockApp,
        'hide_on_open': hideOnOpen,
        'alert_threshold': alertThreshold,
        'chart_style': chartStyle,
        'hero_metric': heroMetric,
      };

  PrefsRow copyWith({
    bool? budgetAlerts,
    bool? familyAlerts,
    bool? approvalAlerts,
    bool? dailyDigest,
    bool? smsAuto,
    bool? smsCategorize,
    bool? smsReview,
    bool? smsPromo,
    bool? lockApp,
    bool? hideOnOpen,
    int? alertThreshold,
    String? chartStyle,
    String? heroMetric,
  }) =>
      PrefsRow(
        budgetAlerts: budgetAlerts ?? this.budgetAlerts,
        familyAlerts: familyAlerts ?? this.familyAlerts,
        approvalAlerts: approvalAlerts ?? this.approvalAlerts,
        dailyDigest: dailyDigest ?? this.dailyDigest,
        smsAuto: smsAuto ?? this.smsAuto,
        smsCategorize: smsCategorize ?? this.smsCategorize,
        smsReview: smsReview ?? this.smsReview,
        smsPromo: smsPromo ?? this.smsPromo,
        lockApp: lockApp ?? this.lockApp,
        hideOnOpen: hideOnOpen ?? this.hideOnOpen,
        alertThreshold: alertThreshold ?? this.alertThreshold,
        chartStyle: chartStyle ?? this.chartStyle,
        heroMetric: heroMetric ?? this.heroMetric,
      );
}
