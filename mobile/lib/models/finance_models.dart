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
  final Map<String, double> shares; // e.g. {'asif': 1000, 'sara': 1000}
  final bool requiresPayback; // whether members need to pay back or it's a gift/shared
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
  final String title; // e.g., 'Wedding Loan', 'Home Renovation Loan'
  final String poolType; // 'Loan', 'Savings Pool', 'Grant'
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

  const SharedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.lastEditedBy,
    required this.lastEditedTime,
    this.categoryTag,
  });
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

  const FamilyMemberDef({
    required this.id,
    required this.name,
    required this.rel,
    required this.role,
    required this.openingBalance,
    required this.color,
    this.authority = MemberAuthority.member,
  });

  String get initial => name.isNotEmpty ? name[0] : 'U';
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
  final String method; // 'UPI', 'Cash', 'Card', 'Bank'
  final String origin; // 'sms' or 'manual'
  final String time;
  final String? fundPoolId; // If linked to a Loan / Special Pool Fund
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
    this.split,
  });
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
  final String confidence; // 'High', 'Check', 'Duplicate?'
  final bool isDuplicate;
  final String snippet;
  final String note;

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
  });
}

class ApprovalItem {
  final String id;
  final String kind; // 'Edit' or 'New'
  final String fromMemberId;
  final int? txnId;
  final String time;
  final String reason;
  final Map<String, dynamic>? changes; // e.g. {'amt': 2200.0}
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
