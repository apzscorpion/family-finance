import 'package:flutter/material.dart';

class SubCategoryDef {
  final String key;
  final String parentKey;
  final String name;

  const SubCategoryDef({
    required this.key,
    required this.parentKey,
    required this.name,
  });
}

class CategoryDef {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final bool isIncome;
  final List<SubCategoryDef> subCategories;

  const CategoryDef({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    this.isIncome = false,
    this.subCategories = const [],
  });
}

class ExpenseSplit {
  final String paidByMemberId;
  final String splitType; // 'equal', 'percentage', 'custom'
  final Map<String, double> shares;
  final bool requiresPayback;
  final bool isSettled;

  const ExpenseSplit({
    required this.paidByMemberId,
    this.splitType = 'equal',
    required this.shares,
    this.requiresPayback = true,
    this.isSettled = false,
  });
}

class FundPool {
  final String id;
  final String title;
  final String poolType;
  final double totalAmount;
  final double spentAmount;
  final String createdDate;

  const FundPool({
    required this.id,
    required this.title,
    this.poolType = 'Loan',
    required this.totalAmount,
    required this.spentAmount,
    required this.createdDate,
  });

  double get remainingAmount => (totalAmount - spentAmount).clamp(0.0, totalAmount);
}

class SharedNote {
  final String id;
  final String title;
  final String content;
  final String lastEditedBy;
  final String lastEditedTime;
  final String? categoryTag;
  final int colorHex;
  final bool isPinned;
  final int updatedAtMs;

  const SharedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.lastEditedBy,
    required this.lastEditedTime,
    this.categoryTag,
    this.colorHex = 0xFF1E2028,
    this.isPinned = false,
    this.updatedAtMs = 0,
  });

  String get updatedAt => lastEditedTime;
  String get category => categoryTag ?? 'General';

  SharedNote copyWith({
    String? id,
    String? title,
    String? content,
    String? lastEditedBy,
    String? lastEditedTime,
    String? categoryTag,
    int? colorHex,
    bool? isPinned,
    int? updatedAtMs,
  }) {
    return SharedNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      categoryTag: categoryTag ?? this.categoryTag,
      colorHex: colorHex ?? this.colorHex,
      isPinned: isPinned ?? this.isPinned,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'lastEditedBy': lastEditedBy,
        'lastEditedTime': lastEditedTime,
        'categoryTag': categoryTag,
        'colorHex': colorHex,
        'isPinned': isPinned,
        'updatedAtMs': updatedAtMs,
      };

  factory SharedNote.fromJson(Map<String, dynamic> json) => SharedNote(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        lastEditedBy: json['lastEditedBy']?.toString() ?? '',
        lastEditedTime: json['lastEditedTime']?.toString() ?? '',
        categoryTag: json['categoryTag']?.toString(),
        colorHex: (json['colorHex'] as int?) ?? 0xFF1E2028,
        isPinned: (json['isPinned'] as bool?) ?? false,
        updatedAtMs: (json['updatedAtMs'] as int?) ?? 0,
      );
}

class MemberAuthority {
  final bool canEditSettings;
  final bool canManageMembers;
  final bool canApproveExpenses;
  final bool canCreateCategories;

  const MemberAuthority({
    this.canEditSettings = false,
    this.canManageMembers = false,
    this.canApproveExpenses = false,
    this.canCreateCategories = false,
  });

  static const MemberAuthority owner = MemberAuthority(
    canEditSettings: true,
    canManageMembers: true,
    canApproveExpenses: true,
    canCreateCategories: true,
  );

  static const MemberAuthority admin = MemberAuthority(
    canEditSettings: true,
    canManageMembers: true,
    canApproveExpenses: true,
    canCreateCategories: true,
  );

  static const MemberAuthority member = MemberAuthority(
    canEditSettings: false,
    canManageMembers: false,
    canApproveExpenses: false,
    canCreateCategories: true,
  );
}

class FamilyMemberDef {
  final String id;
  final String name;
  final String rel;
  final String role; // 'Owner', 'Admin', 'Member', 'Viewer'
  final double openingBalance;
  final Color color;
  final MemberAuthority authority;
  final String email;
  final bool isDisabled;
  final bool isVerified;
  final String memberOtp;

  const FamilyMemberDef({
    required this.id,
    required this.name,
    required this.rel,
    required this.role,
    required this.openingBalance,
    required this.color,
    this.authority = MemberAuthority.member,
    this.email = '',
    this.isDisabled = false,
    this.isVerified = true,
    this.memberOtp = '',
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'U';

  FamilyMemberDef copyWith({
    String? id,
    String? name,
    String? rel,
    String? role,
    double? openingBalance,
    Color? color,
    MemberAuthority? authority,
    String? email,
    bool? isDisabled,
    bool? isVerified,
    String? memberOtp,
  }) {
    return FamilyMemberDef(
      id: id ?? this.id,
      name: name ?? this.name,
      rel: rel ?? this.rel,
      role: role ?? this.role,
      openingBalance: openingBalance ?? this.openingBalance,
      color: color ?? this.color,
      authority: authority ?? this.authority,
      email: email ?? this.email,
      isDisabled: isDisabled ?? this.isDisabled,
      isVerified: isVerified ?? this.isVerified,
      memberOtp: memberOtp ?? this.memberOtp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rel': rel,
        'role': role,
        'openingBalance': openingBalance,
        'colorValue': color.toARGB32(),
        'email': email,
        'isDisabled': isDisabled,
        'isVerified': isVerified,
        'memberOtp': memberOtp,
      };

  factory FamilyMemberDef.fromJson(Map<String, dynamic> json) => FamilyMemberDef(
        id: json['id']?.toString() ?? 'me',
        name: json['name']?.toString() ?? 'Me',
        rel: json['rel']?.toString() ?? 'You',
        role: json['role']?.toString() ?? 'Member',
        openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
        color: Color((json['colorValue'] as int?) ?? 0xFF9184D9),
        email: json['email']?.toString() ?? '',
        isDisabled: (json['isDisabled'] as bool?) ?? false,
        isVerified: (json['isVerified'] as bool?) ?? true,
        memberOtp: json['memberOtp']?.toString() ?? '',
      );
}

class FamilyLoginRequest {
  final String id;
  final String name;
  final String email;
  final String familyCode;
  final String verificationOtp;
  final String requestedAt;
  final String status; // 'pending', 'approved', 'rejected'

  const FamilyLoginRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.familyCode,
    required this.verificationOtp,
    required this.requestedAt,
    this.status = 'pending',
  });

  FamilyLoginRequest copyWith({
    String? id,
    String? name,
    String? email,
    String? familyCode,
    String? verificationOtp,
    String? requestedAt,
    String? status,
  }) {
    return FamilyLoginRequest(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      familyCode: familyCode ?? this.familyCode,
      verificationOtp: verificationOtp ?? this.verificationOtp,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'familyCode': familyCode,
        'verificationOtp': verificationOtp,
        'requestedAt': requestedAt,
        'status': status,
      };

  factory FamilyLoginRequest.fromJson(Map<String, dynamic> json) => FamilyLoginRequest(
        id: json['id']?.toString() ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name']?.toString() ?? 'Family User',
        email: json['email']?.toString() ?? '',
        familyCode: json['familyCode']?.toString() ?? '',
        verificationOtp: json['verificationOtp']?.toString() ?? '000000',
        requestedAt: json['requestedAt']?.toString() ?? 'Just now',
        status: json['status']?.toString() ?? 'pending',
      );
}

class CreditCardDef {
  final String id;
  final String bankName;
  final String cardName;
  final String last4;
  final String network; // 'Visa', 'Mastercard', 'RuPay', 'Amex'
  final String cardType; // 'Credit', 'RuPay UPI', 'Debit'
  final double creditLimit;
  final double openingUsed;
  final int billingDay;
  final int dueDay;
  final int colorHex;
  final String holderMemberId;
  final bool autoTrackSms;

  const CreditCardDef({
    required this.id,
    required this.bankName,
    required this.cardName,
    required this.last4,
    this.network = 'Visa',
    this.cardType = 'Credit',
    required this.creditLimit,
    this.openingUsed = 0.0,
    this.billingDay = 15,
    this.dueDay = 5,
    this.colorHex = 0xFF312E81,
    this.holderMemberId = 'me',
    this.autoTrackSms = true,
  });

  String get displayTitle => cardName.isNotEmpty ? '$bankName $cardName' : bankName;
  String get shortLabel => '$bankName ••$last4';

  CreditCardDef copyWith({
    String? id,
    String? bankName,
    String? cardName,
    String? last4,
    String? network,
    String? cardType,
    double? creditLimit,
    double? openingUsed,
    int? billingDay,
    int? dueDay,
    int? colorHex,
    String? holderMemberId,
    bool? autoTrackSms,
  }) {
    return CreditCardDef(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      cardName: cardName ?? this.cardName,
      last4: last4 ?? this.last4,
      network: network ?? this.network,
      cardType: cardType ?? this.cardType,
      creditLimit: creditLimit ?? this.creditLimit,
      openingUsed: openingUsed ?? this.openingUsed,
      billingDay: billingDay ?? this.billingDay,
      dueDay: dueDay ?? this.dueDay,
      colorHex: colorHex ?? this.colorHex,
      holderMemberId: holderMemberId ?? this.holderMemberId,
      autoTrackSms: autoTrackSms ?? this.autoTrackSms,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'cardName': cardName,
        'last4': last4,
        'network': network,
        'cardType': cardType,
        'creditLimit': creditLimit,
        'openingUsed': openingUsed,
        'billingDay': billingDay,
        'dueDay': dueDay,
        'colorHex': colorHex,
        'holderMemberId': holderMemberId,
        'autoTrackSms': autoTrackSms,
      };

  factory CreditCardDef.fromJson(Map<String, dynamic> json) => CreditCardDef(
        id: json['id']?.toString() ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
        bankName: json['bankName']?.toString() ?? 'Bank',
        cardName: json['cardName']?.toString() ?? 'Credit Card',
        last4: json['last4']?.toString() ?? '0000',
        network: json['network']?.toString() ?? 'Visa',
        cardType: json['cardType']?.toString() ?? 'Credit',
        creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 100000.0,
        openingUsed: (json['openingUsed'] as num?)?.toDouble() ?? 0.0,
        billingDay: (json['billingDay'] as int?) ?? 15,
        dueDay: (json['dueDay'] as int?) ?? 5,
        colorHex: (json['colorHex'] as int?) ?? 0xFF312E81,
        holderMemberId: json['holderMemberId']?.toString() ?? 'me',
        autoTrackSms: (json['autoTrackSms'] as bool?) ?? true,
      );
}

class AutoCardCharge {
  final String id;
  final String cardId;
  final String title;
  final double amount;
  final String catKey;
  final int dayOfMonth;
  final bool isActive;
  final String? lastAppliedMonth; // e.g. '2026-10'

  const AutoCardCharge({
    required this.id,
    required this.cardId,
    required this.title,
    required this.amount,
    this.catKey = 'bills',
    this.dayOfMonth = 1,
    this.isActive = true,
    this.lastAppliedMonth,
  });

  AutoCardCharge copyWith({
    String? id,
    String? cardId,
    String? title,
    double? amount,
    String? catKey,
    int? dayOfMonth,
    bool? isActive,
    String? lastAppliedMonth,
  }) {
    return AutoCardCharge(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      catKey: catKey ?? this.catKey,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      lastAppliedMonth: lastAppliedMonth ?? this.lastAppliedMonth,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'title': title,
        'amount': amount,
        'catKey': catKey,
        'dayOfMonth': dayOfMonth,
        'isActive': isActive,
        'lastAppliedMonth': lastAppliedMonth,
      };

  factory AutoCardCharge.fromJson(Map<String, dynamic> json) => AutoCardCharge(
        id: json['id']?.toString() ?? 'ac_${DateTime.now().millisecondsSinceEpoch}',
        cardId: json['cardId']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Subscription',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        catKey: json['catKey']?.toString() ?? 'bills',
        dayOfMonth: (json['dayOfMonth'] as int?) ?? 1,
        isActive: (json['isActive'] as bool?) ?? true,
        lastAppliedMonth: json['lastAppliedMonth']?.toString(),
      );
}

class TransactionDef {
  final int id;
  final int daysAgo; // 0 = Today, 1 = Yesterday, etc.
  final String title;
  final String catKey;
  final String? subCatKey;
  final double amount;
  final String type; // 'expense' or 'income'
  final String memberId;
  final String method; // 'UPI', 'Cash', 'Card', 'Bank', 'Salary', 'Loan'
  final String origin; // 'sms' or 'manual' or 'auto_card'
  final String time;
  final String? fundPoolId;
  final String? cardId;
  final ExpenseSplit? split;

  const TransactionDef({
    required this.id,
    required this.daysAgo,
    required this.title,
    required this.catKey,
    this.subCatKey,
    required this.amount,
    required this.type,
    required this.memberId,
    required this.method,
    required this.origin,
    required this.time,
    this.fundPoolId,
    this.cardId,
    this.split,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'daysAgo': daysAgo,
        'title': title,
        'catKey': catKey,
        'subCatKey': subCatKey,
        'amount': amount,
        'type': type,
        'memberId': memberId,
        'method': method,
        'origin': origin,
        'time': time,
        'fundPoolId': fundPoolId,
        'cardId': cardId,
      };

  factory TransactionDef.fromJson(Map<String, dynamic> json) => TransactionDef(
        id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        daysAgo: (json['daysAgo'] as int?) ?? 0,
        title: json['title']?.toString() ?? '',
        catKey: json['catKey']?.toString() ?? 'shopping',
        subCatKey: json['subCatKey']?.toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        type: json['type']?.toString() ?? 'expense',
        memberId: json['memberId']?.toString() ?? 'me',
        method: json['method']?.toString() ?? 'UPI',
        origin: json['origin']?.toString() ?? 'manual',
        time: json['time']?.toString() ?? 'Now',
        fundPoolId: json['fundPoolId']?.toString(),
        cardId: json['cardId']?.toString(),
      );
}

class BudgetDef {
  final String catKey;
  final double familyLimit;
  final double personalLimit;

  const BudgetDef({
    required this.catKey,
    required this.familyLimit,
    required this.personalLimit,
  });
}

class SmsQueueItem {
  final String id;
  final String bank;
  final String when;
  final double amount;
  final String merchant;
  final String catKey;
  final String confidence;
  final bool isDuplicate;
  final String snippet;
  final String note;
  final String? cardId;
  final String? cardLast4;

  const SmsQueueItem({
    required this.id,
    required this.bank,
    required this.when,
    required this.amount,
    required this.merchant,
    required this.catKey,
    required this.confidence,
    this.isDuplicate = false,
    required this.snippet,
    required this.note,
    this.cardId,
    this.cardLast4,
  });
}

class ApprovalItem {
  final String id;
  final String kind; // 'Edit' or 'New'
  final String fromMemberId;
  final int? txnId;
  final String time;
  final String reason;
  final Map<String, dynamic>? changes;
  final TransactionDef? newTxn;

  const ApprovalItem({
    required this.id,
    required this.kind,
    required this.fromMemberId,
    this.txnId,
    required this.time,
    required this.reason,
    this.changes,
    this.newTxn,
  });
}

class JoinedGroupDef {
  final String code; // e.g. 'NTY5AFLR' (permanent group code shared by all members)
  final String name; // e.g. "Asif's Family" or "Friends Goa Trip"
  final String kind; // 'Family', 'Friends', 'Trip', 'Couple', 'Office'
  final String role; // 'Owner' or 'Member'
  final String ownerEmail;

  const JoinedGroupDef({
    required this.code,
    required this.name,
    this.kind = 'Family',
    this.role = 'Owner',
    this.ownerEmail = '',
  });

  JoinedGroupDef copyWith({
    String? code,
    String? name,
    String? kind,
    String? role,
    String? ownerEmail,
  }) =>
      JoinedGroupDef(
        code: code ?? this.code,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        role: role ?? this.role,
        ownerEmail: ownerEmail ?? this.ownerEmail,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'kind': kind,
        'role': role,
        'ownerEmail': ownerEmail,
      };

  factory JoinedGroupDef.fromJson(Map<String, dynamic> json) => JoinedGroupDef(
        code: (json['code']?.toString() ?? '').trim().toUpperCase(),
        name: json['name']?.toString() ?? 'Family Group',
        kind: json['kind']?.toString() ?? 'Family',
        role: json['role']?.toString() ?? 'Member',
        ownerEmail: json['ownerEmail']?.toString() ?? '',
      );
}

