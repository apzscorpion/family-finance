import 'package:flutter/material.dart';

class CategoryDef {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final bool isIncome;

  const CategoryDef({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    this.isIncome = false,
  });
}

class FamilyMemberDef {
  final String id;
  final String name;
  final String rel;
  final String role;
  final double openingBalance;
  final Color color;

  const FamilyMemberDef({
    required this.id,
    required this.name,
    required this.rel,
    required this.role,
    required this.openingBalance,
    required this.color,
  });

  String get initial => name.isNotEmpty ? name[0] : 'U';
}

class TransactionDef {
  final int id;
  final int daysAgo; // 0 = Today, 1 = Yesterday, etc.
  final String title;
  final String catKey;
  final double amount;
  final String type; // 'expense' or 'income'
  final String memberId;
  final String method; // 'UPI', 'Cash', 'Card', 'Bank'
  final String origin; // 'sms' or 'manual'
  final String time;

  const TransactionDef({
    required this.id,
    required this.daysAgo,
    required this.title,
    required this.catKey,
    required this.amount,
    required this.type,
    required this.memberId,
    required this.method,
    required this.origin,
    required this.time,
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
