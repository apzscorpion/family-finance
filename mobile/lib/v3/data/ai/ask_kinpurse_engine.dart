import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../services/app_log.dart';
import '../../v3_design.dart';
import '../v3_models.dart';
import 'ai_config.dart';
import 'ai_structurer.dart';

/// Structured query intent extracted from natural language by LLM.
/// **NO RAW TRANSACTIONS OR SENSITIVE USER DATA ARE EVER SENT TO THE MODEL.**
/// The AI only receives the user question + schema metadata (category names,
/// member names, today's date), and outputs structured filtering rules.
class AskKinPurseQuery {
  final String intent; // 'sum', 'count', 'compare', 'list', 'average', 'max', 'help'
  final String? category;
  final String? member;
  final String? merchant;
  final String? txnType; // 'expense', 'income', or null (all)
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? compareStartDate;
  final DateTime? compareEndDate;
  final String explanation; // What the AI understood

  /// Only expenses shared with or paid for someone else.
  final bool sharedOnly;

  /// Account to keep, or to leave out (matched by name).
  final String? account;
  final String? excludeAccount;

  /// The reply to a 'help' question (how to use the app), not about data.
  final String? answer;

  /// For 'help': a screen to open ([AskKinPurseEngine.screens]), a setting
  /// to switch ([AskKinPurseEngine.settings]) to [turnOn], a theme id or a
  /// text size ([AskKinPurseEngine.textSizes]). The app offers it as a button.
  final String? open;
  final String? setting;
  final bool? turnOn;
  final String? theme;
  final String? textSize;

  /// What the model returned, so a follow-up can refine it.
  final Map<String, dynamic> raw;

  const AskKinPurseQuery({
    required this.intent,
    this.category,
    this.member,
    this.merchant,
    this.txnType,
    this.startDate,
    this.endDate,
    this.compareStartDate,
    this.compareEndDate,
    required this.explanation,
    this.sharedOnly = false,
    this.account,
    this.excludeAccount,
    this.answer,
    this.open,
    this.setting,
    this.turnOn,
    this.theme,
    this.textSize,
    this.raw = const {},
  });

  factory AskKinPurseQuery.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return AskKinPurseQuery(
      intent: j['intent']?.toString() ?? 'sum',
      category: j['category']?.toString(),
      member: j['member']?.toString(),
      merchant: j['merchant']?.toString(),
      txnType: j['txn_type']?.toString(),
      startDate: parseDate(j['start_date']),
      endDate: parseDate(j['end_date']),
      compareStartDate: parseDate(j['compare_start_date']),
      compareEndDate: parseDate(j['compare_end_date']),
      explanation: j['explanation']?.toString() ?? 'Filtered financial records',
      sharedOnly: j['shared_with_others'] == true,
      account: j['account']?.toString(),
      excludeAccount: j['exclude_account']?.toString(),
      answer: j['answer']?.toString(),
      open: AskKinPurseEngine.screens.contains(j['open']) ? j['open'] as String : null,
      setting: AskKinPurseEngine.settings.contains(j['setting'])
          ? j['setting'] as String
          : null,
      turnOn: j['turn_on'] is bool ? j['turn_on'] as bool : null,
      theme: AskKinPurseEngine.themes.contains(j['theme']) ? j['theme'] as String : null,
      textSize: AskKinPurseEngine.textSizes.contains(j['text_size'])
          ? j['text_size'] as String
          : null,
      raw: j,
    );
  }
}

/// The computed result calculated entirely on-device from local database state.
class AskKinPurseResult {
  final String answerText;
  final double primaryAmount;
  final double? compareAmount;
  final double? percentageDiff;
  final int count;
  final List<TxnRow> matchingTxns;
  final List<TxnRow>? compareTxns;
  final String? error;

  /// What was asked, so the next message can refine it.
  final AskKinPurseQuery? query;

  const AskKinPurseResult({
    required this.answerText,
    required this.primaryAmount,
    this.compareAmount,
    this.percentageDiff,
    required this.count,
    required this.matchingTxns,
    this.compareTxns,
    this.error,
    this.query,
  });

  bool get hasComparison => compareAmount != null;
}

class AskKinPurseEngine {
  AskKinPurseEngine._();

  /// What a 'help' answer may offer; the screen maps each to its action.
  static const screens = ['home', 'activity', 'insights', 'more', 'settings', 'add', 'voice', 'detected', 'cards', 'notes', 'messages', 'notifications', 'prayer', 'prayer_settings', 'ai_settings', 'monthly_recap', 'spending_calendar', 'budget', 'goals', 'recurring', 'categories', 'money_sources', 'import', 'invite', 'faith', 'guardian', 'updates'];
  static const settings = ['app_lock', 'hide_amounts', 'read_payments', 'prayer_times', 'budget_alerts', 'family_alerts', 'approval_alerts', 'daily_digest', 'reduce_motion', 'match_device_theme'];
  static const themes = ['dark', 'light', 'blue', 'maroon', 'golden', 'yellow'];
  static const textSizes = ['small', 'default', 'large', 'largest']; // ThemeController.textScales, in order

  static const _systemPrompt = '''
You are KinPurse Query Assistant.
Your task is to convert a user's natural language question about their family finances into a structured search filter.
IMPORTANT PRIVACY RULE: You NEVER see real transactions or monetary amounts. You only extract filtering criteria.

Today's date and context will be provided in the user prompt.
Extract:
1. "intent": "sum" (default total), "count" (how many times), "compare" (comparing two periods or categories), "list" (show recent), "average", "max" (highest), or "help" when the question is NOT about their transactions (how to use the app, a feature, a greeting).
2. "category": Matching category name if mentioned (e.g. "Food", "Groceries", "Fuel", "Bills"), or null.
3. "member": Member's name if mentioned (e.g. "Sara", "Dad", "myself"), or null.
4. "merchant": Merchant/Store name if mentioned (e.g. "Swiggy", "Amazon", "Uber"), or null.
5. "txn_type": "expense", "income", or null.
6. "start_date" & "end_date": ISO-8601 (YYYY-MM-DD) date range for the main query.
7. "compare_start_date" & "compare_end_date": ISO-8601 (YYYY-MM-DD) date range if comparing with a previous period (e.g. "last month vs this month").
8. "explanation": A friendly, concise 1-line summary of what you are calculating (e.g. "Total groceries spending in October compared to September").
9. "shared_with_others": true when the question is about spending for or with other people (split, shared, paid for someone), else null.
10. "account": account name to limit to (e.g. "Salary"), or null.
11. "exclude_account": account name to leave out (e.g. "exclude loan account" -> "Loan"), or null.
12. "answer": only for "help": a short, friendly answer in plain text (no markdown) saying where the feature is and how to use it, from the app guide below. If the guide does not cover it, say so and suggest searching in Settings instead of inventing steps. Otherwise null.
13. For "help" only, when it helps the user, also set ONE of:
   - "open": a screen to take them to: home, activity, insights, more, settings, add, voice, detected, cards, notes, messages, notifications, prayer, prayer_settings, ai_settings, monthly_recap, spending_calendar, budget, goals, recurring, categories, money_sources, import, invite, faith, guardian, updates.
   - "setting" + "turn_on" (true/false): when they ask to turn something on or off: app_lock, hide_amounts, read_payments, prayer_times, budget_alerts, family_alerts, approval_alerts, daily_digest, reduce_motion, match_device_theme.
   - "theme": when they ask for a colour theme: dark, light, blue, maroon, golden, yellow.
   - "text_size": when they ask for bigger or smaller text: small, default, large, largest.
   The app shows it as a button the user taps, so say what the button does (e.g. "Tap below to turn it on.").

App guide (bottom bar: Home, Activity, +, Insights, More):
- Add income or an expense: the + button, or Home > Add. By voice: Home > Voice (English or Malayalam).
- Payments read from bank SMS and notifications: Home > Detected. Turn it on or off: More > Settings > Read payments.
- Cards and accounts: Home > Cards. Manage money sources (bank, cash, wallet): More > Settings > Money sources.
- Family notes: Home > Notes. Messages with family: More > Direct messages.
- Set a budget limit: Home > "AI That Feels Like Magic" > What-If tab: pick a category, slide how much to cut, tap "Lock in this budget restriction". Budgets then show on Home under "Budgets".
- Budget alerts and the alert threshold: More > Settings > Notifications.
- Savings goals: Home > "Savings goals" > "+ Set goal".
- Duplicate subscriptions, polite money reminders, "price in hours of work": Home > "AI That Feels Like Magic".
- Zakat, gold and sadaqah calculator: Home > "Faith & Charity". Prayer times: Home prayer card; settings: More > Settings > Prayer times.
- Card guardian, refund watchdog, spend roast: Home > "Install Magnets & Security".
- Charts and trends: Insights. Spending calendar and Monthly recap: Insights. Full history and search: Activity.
- Family members, invite someone (owner or admin): More > Members > Invite. Approvals and who owes who, settle up and split a receipt: More.
- Recurring bills and subscriptions: More > Settings > Recurring rules. Categories: More > Settings > Categories.
- Import from CSV/Excel: More > Settings > Import expenses. Export: More > Settings > Export.
- Profile photo and About line: tap your picture at the top of Settings. UPI ID: More > Settings > UPI ID.
- Theme, text size, reduce motion: More > Settings > Appearance. App lock and Hide amounts: the tiles at the top of Settings.
- Hide my money from some members: More > Settings > Hide my money from.
- AI provider and keys: More > Settings > AI restructuring. App updates: More > Settings > App updates. Report a problem: More > Settings > Support & feedback.

Return ONLY JSON matching the schema.
''';

  static Map<String, dynamic> _schema({required bool strict}) => {
        'type': 'object',
        'properties': {
          'intent': {
            'type': 'string',
            'enum': ['sum', 'count', 'compare', 'list', 'average', 'max', 'help']
          },
          'category': {'type': ['string', 'null']},
          'member': {'type': ['string', 'null']},
          'merchant': {'type': ['string', 'null']},
          'txn_type': {
            'type': ['string', 'null'],
            'enum': ['expense', 'income', null]
          },
          'start_date': {'type': ['string', 'null']},
          'end_date': {'type': ['string', 'null']},
          'compare_start_date': {'type': ['string', 'null']},
          'compare_end_date': {'type': ['string', 'null']},
          'explanation': {'type': 'string'},
          'shared_with_others': {'type': ['boolean', 'null']},
          'account': {'type': ['string', 'null']},
          'exclude_account': {'type': ['string', 'null']},
          'answer': {'type': ['string', 'null']},
          'open': {'type': ['string', 'null']},
          'setting': {'type': ['string', 'null']},
          'turn_on': {'type': ['boolean', 'null']},
          'theme': {'type': ['string', 'null']},
          'text_size': {'type': ['string', 'null']},
        },
        'required': ['intent', 'explanation'],
        if (strict) 'additionalProperties': false,
      };

  static const _example = {
    'intent': 'compare',
    'category': 'Food & Dining',
    'member': null,
    'merchant': null,
    'txn_type': 'expense',
    'start_date': '2026-10-01',
    'end_date': '2026-10-31',
    'compare_start_date': '2026-09-01',
    'compare_end_date': '2026-09-30',
    'explanation': 'Comparing food spending in October vs September',
  };

  /// Parses the user question with the LLM into an [AskKinPurseQuery],
  /// and runs the calculation on local memory [txns].
  static Future<AskKinPurseResult> ask({
    required String question,
    required AiConfig config,
    required List<TxnRow> txns,
    required List<CategoryRow> categories,
    required List<MemberRow> members,
    required String myName,
    List<SourceRow> sources = const [],
    String? Function(TxnRow)? sourceOf,
    AskKinPurseQuery? previous,
    String? previousQuestion,
  }) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final catNames = categories.map((c) => c.name).take(30).join(', ');
    final memberNames = members.map((m) => m.name).join(', ');

    final prompt = StringBuffer()
      ..writeln("Today's Date: $todayStr")
      ..writeln('Known Categories: $catNames')
      ..writeln('Known Family Members: $memberNames (Current User: $myName)')
      ..writeln('Known Accounts: ${sources.map((x) => x.name).join(', ')}');
    if (previous != null) {
      prompt
        ..writeln('Previous question: "${previousQuestion ?? ''}"')
        ..writeln('Previous filters: ${jsonEncode(previous.raw)}');
    }
    prompt
      ..writeln()
      ..writeln('User Question: "$question"');

    final result = await AiStructurer.askJson(
      config: config,
      system: _systemPrompt,
      input: prompt.toString(),
      schema: _schema,
      example: _example,
    );

    if (result.error != null || result.data == null) {
      return AskKinPurseResult(
        answerText: result.error ?? 'Could not interpret question.',
        primaryAmount: 0,
        count: 0,
        matchingTxns: const [],
        error: result.error ?? 'Unknown error',
      );
    }

    try {
      final query = AskKinPurseQuery.fromJson(result.data!);
      // A how-to question gets its answer, never a list of every transaction.
      if (query.intent == 'help') {
        return AskKinPurseResult(
          answerText: query.answer ?? query.explanation,
          primaryAmount: 0,
          count: 0,
          matchingTxns: const [],
          query: query,
        );
      }
      final r = executeLocally(query, txns, categories, members,
          sources: sources, sourceOf: sourceOf);
      return AskKinPurseResult(
        answerText: r.answerText,
        primaryAmount: r.primaryAmount,
        compareAmount: r.compareAmount,
        percentageDiff: r.percentageDiff,
        count: r.count,
        matchingTxns: r.matchingTxns,
        compareTxns: r.compareTxns,
        error: r.error,
        query: query,
      );
    } catch (e, stack) {
      AppLog.error('AskKinPurseEngine.ask', e, stack);
      return AskKinPurseResult(
        answerText: 'Failed to process answer from query data.',
        primaryAmount: 0,
        count: 0,
        matchingTxns: const [],
        error: e.toString(),
      );
    }
  }

  /// Evaluates the query locally against the provided in-memory transactions.
  @visibleForTesting
  static AskKinPurseResult executeLocally(
    AskKinPurseQuery query,
    List<TxnRow> allTxns,
    List<CategoryRow> categories,
    List<MemberRow> members, {
    List<SourceRow> sources = const [],
    String? Function(TxnRow)? sourceOf,
  }) {
    String? accountId(String? name) {
      if (name == null || name.trim().isEmpty) return null;
      final q = name.toLowerCase();
      for (final src in sources) {
        if (src.name.toLowerCase().contains(q) || q.contains(src.name.toLowerCase())) {
          return src.id;
        }
      }
      return null;
    }

    final keepAccount = accountId(query.account);
    final dropAccount = accountId(query.excludeAccount);
    String? accountOf(TxnRow t) => sourceOf?.call(t) ?? t.sourceId;

    // 1. Resolve Category ID if name supplied
    String? categoryId;
    if (query.category != null && query.category!.isNotEmpty) {
      final qCat = query.category!.toLowerCase();
      final match = categories.firstWhere(
        (c) => c.name.toLowerCase().contains(qCat) || c.key.toLowerCase().contains(qCat),
        orElse: () => CategoryRow(id: '', key: '', name: ''),
      );
      if (match.id.isNotEmpty) categoryId = match.id;
    }

    // 2. Resolve Member ID if name supplied
    String? memberId;
    if (query.member != null && query.member!.isNotEmpty) {
      final qMember = query.member!.toLowerCase();
      final match = members.firstWhere(
        (m) => m.name.toLowerCase().contains(qMember),
        orElse: () => const MemberRow(userId: '', name: '', role: '', status: '', relationship: '', hue: 0),
      );
      if (match.userId.isNotEmpty) memberId = match.userId;
    }

    bool matchesFilters(TxnRow t, DateTime? start, DateTime? end) {
      // Date filter
      if (start != null) {
        final startInclusive = DateTime(start.year, start.month, start.day);
        if (t.occurredAt.isBefore(startInclusive)) return false;
      }
      if (end != null) {
        final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (t.occurredAt.isAfter(endInclusive)) return false;
      }

      // Type filter
      if (query.txnType != null && query.txnType!.isNotEmpty) {
        if (t.type.toLowerCase() != query.txnType!.toLowerCase()) return false;
      }

      // Category filter
      if (categoryId != null && t.categoryId != categoryId) return false;

      // Member filter (either paidBy or userId)
      if (memberId != null && t.userId != memberId && t.paidBy != memberId) {
        return false;
      }

      // Shared with, or paid for, someone else
      if (query.sharedOnly &&
          !(t.isExpense &&
              t.shares.keys.any((k) => k != (t.paidBy ?? t.userId)))) {
        return false;
      }

      // Account filters
      if (keepAccount != null && accountOf(t) != keepAccount) return false;
      if (dropAccount != null && accountOf(t) == dropAccount) return false;

      // Merchant/title filter
      if (query.merchant != null && query.merchant!.isNotEmpty) {
        if (!t.title.toLowerCase().contains(query.merchant!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }

    // Main period matches
    final primaryList = allTxns
        .where((t) => matchesFilters(t, query.startDate, query.endDate))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // Secondary period matches (for comparisons)
    List<TxnRow>? compareList;
    if (query.compareStartDate != null || query.compareEndDate != null) {
      compareList = allTxns
          .where((t) => matchesFilters(t, query.compareStartDate, query.compareEndDate))
          .toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }

    final primarySum = primaryList.fold<double>(0.0, (acc, t) => acc + t.amount);
    final primaryCount = primaryList.length;

    if (query.intent == 'compare' && compareList != null) {
      final compareSum = compareList.fold<double>(0.0, (acc, t) => acc + t.amount);
      double? diffPct;
      if (compareSum > 0) {
        diffPct = ((primarySum - compareSum) / compareSum) * 100;
      }

      String comparisonSummary;
      if (diffPct != null) {
        final direction = diffPct >= 0 ? 'more' : 'less';
        comparisonSummary =
            'You spent ${V3Design.inr(primarySum)} vs ${V3Design.inr(compareSum)} (${diffPct.abs().toStringAsFixed(1)}% $direction).';
      } else {
        comparisonSummary =
            'Current period: ${V3Design.inr(primarySum)}, Compared period: ${V3Design.inr(compareSum)}.';
      }

      return AskKinPurseResult(
        answerText: '${query.explanation}\n$comparisonSummary',
        primaryAmount: primarySum,
        compareAmount: compareSum,
        percentageDiff: diffPct,
        count: primaryCount,
        matchingTxns: primaryList,
        compareTxns: compareList,
      );
    }

    if (query.intent == 'average') {
      final avg = primaryCount > 0 ? (primarySum / primaryCount) : 0.0;
      return AskKinPurseResult(
        answerText:
            '${query.explanation}\nAverage amount is ${V3Design.inr(avg)} across $primaryCount transaction${primaryCount == 1 ? '' : 's'}.',
        primaryAmount: avg,
        count: primaryCount,
        matchingTxns: primaryList,
      );
    }

    if (query.intent == 'count') {
      return AskKinPurseResult(
        answerText:
            '${query.explanation}\nFound $primaryCount transaction${primaryCount == 1 ? '' : 's'} totaling ${V3Design.inr(primarySum)}.',
        primaryAmount: primarySum,
        count: primaryCount,
        matchingTxns: primaryList,
      );
    }

    if (query.intent == 'max') {
      final maxTxn = primaryList.isEmpty
          ? null
          : primaryList.reduce((curr, next) => curr.amount > next.amount ? curr : next);
      final maxAmount = maxTxn?.amount ?? 0.0;
      return AskKinPurseResult(
        answerText: maxTxn != null
            ? '${query.explanation}\nHighest was ${V3Design.inr(maxAmount)} for "${maxTxn.title}".'
            : 'No matching transactions found.',
        primaryAmount: maxAmount,
        count: primaryCount,
        matchingTxns: primaryList,
      );
    }

    // Default: sum / list
    return AskKinPurseResult(
      answerText:
          '${query.explanation}\nTotal is ${V3Design.inr(primarySum)} across $primaryCount transaction${primaryCount == 1 ? '' : 's'}.',
      primaryAmount: primarySum,
      count: primaryCount,
      matchingTxns: primaryList,
    );
  }
}

