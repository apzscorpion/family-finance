import 'package:flutter/material.dart';

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

  const MemberRow({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    required this.relationship,
    required this.hue,
    this.monthlyBudget,
    this.isAllowance = false,
  });

  factory MemberRow.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'];
    final name = profile is Map
        ? (profile['full_name']?.toString() ?? '')
        : (j['full_name']?.toString() ?? '');
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
    );
  }

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

  const SourceRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.sortOrder,
  });

  factory SourceRow.fromJson(Map<String, dynamic> j) => SourceRow(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'savings',
        openingBalance: _num(j['opening_balance']),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Falls back to the design's icon/hue for the seeded source names.
  V3Source get design =>
      V3Design.sources.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
        orElse: () => V3Design.sources.last,
      );
}

class CategoryRow {
  final String id;
  final String key;
  final String name;
  final String? icon;
  final String? color;

  const CategoryRow({
    required this.id,
    required this.key,
    required this.name,
    this.icon,
    this.color,
  });

  factory CategoryRow.fromJson(Map<String, dynamic> j) => CategoryRow(
        id: j['id'].toString(),
        key: j['key']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString(),
        color: j['color']?.toString(),
      );
}

class TxnRow {
  final String id;
  final String familyId;
  final String? userId;
  final String? sourceId;
  final String? categoryId;
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

  const TxnRow({
    required this.id,
    required this.familyId,
    this.userId,
    this.sourceId,
    this.categoryId,
    this.cardId,
    this.paidBy,
    this.shares = const {},
    required this.title,
    required this.amount,
    required this.type,
    required this.method,
    required this.origin,
    required this.occurredAt,
    this.split,
    this.note,
    this.categoryKey = 'shopping',
  });

  factory TxnRow.fromJson(Map<String, dynamic> j) {
    final cat = j['categories'];
    return TxnRow(
      id: j['id'].toString(),
      familyId: j['family_id'].toString(),
      userId: j['user_id']?.toString(),
      sourceId: j['source_id']?.toString(),
      categoryId: j['category_id']?.toString(),
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
    );
  }

  bool get isExpense => type == 'expense';

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
        blocks: (j['blocks'] as List?)
                ?.whereType<Map>()
                .map((e) => NoteBlock.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
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
