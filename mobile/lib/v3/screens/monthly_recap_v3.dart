import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/nocturne.dart';
import '../data/ai/ai_config.dart';
import '../data/ai/ai_structurer.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

class MonthlyRecapScreen extends StatefulWidget {
  const MonthlyRecapScreen({super.key});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _aiCaption;
  String? _aiRoast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAiCaption();
      _generateAiRoast();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _generateAiCaption() async {
    final s = context.read<V3State>();
    final cfg = await AiConfigStore.load();
    if (!cfg.isConfigured) return;

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthTxns = s.txns.where((t) => t.isExpense && !t.occurredAt.isBefore(thisMonthStart)).toList();
    final totalSpent = thisMonthTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    // Compute top category
    final catTotals = <String, double>{};
    for (final t in thisMonthTxns) {
      catTotals[t.categoryKey] = (catTotals[t.categoryKey] ?? 0) + t.amount;
    }
    String topCat = 'General';
    double topAmt = 0;
    catTotals.forEach((k, v) {
      if (v > topAmt) {
        topAmt = v;
        topCat = s.catStyle(k).name;
      }
    });

    final prompt = 'Family: "${s.family?.name ?? 'Household'}". Total spend this month: ₹${totalSpent.toStringAsFixed(0)}. Top category: "$topCat" (₹${topAmt.toStringAsFixed(0)}). Write ONE fun, witty, encouraging Spotify-Wrapped style headline (maximum 15 words) for our monthly recap story.';

    final res = await AiStructurer.askJson(
      config: cfg,
      system: 'You generate punchy, fun 1-line monthly wrap headlines for family finance apps. Return JSON {"headline": "..."}',
      input: prompt,
      schema: ({required bool strict}) => {
        'type': 'object',
        'properties': {
          'headline': {'type': 'string'},
        },
        'required': ['headline'],
      },
      example: {'headline': 'Mastered the kitchen budget this month! Keep up the momentum! 🎉'},
    );

    if (mounted) {
      if (res.data != null && res.data!['headline'] != null) {
        setState(() {
          _aiCaption = res.data!['headline'].toString();
        });
      }
    }
  }

  Future<void> _generateAiRoast() async {
    final s = context.read<V3State>();
    final cfg = await AiConfigStore.load();
    if (!cfg.isConfigured) return;

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthTxns = s.txns.where((t) => t.isExpense && !t.occurredAt.isBefore(thisMonthStart)).toList();
    final totalSpent = thisMonthTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final catTotals = <String, double>{};
    for (final t in thisMonthTxns) {
      catTotals[t.categoryKey] = (catTotals[t.categoryKey] ?? 0) + t.amount;
    }
    String topCat = 'General';
    double topAmt = 0;
    catTotals.forEach((k, v) {
      if (v > topAmt) {
        topAmt = v;
        topCat = s.catStyle(k).name;
      }
    });

    final prompt = 'Household spending this month: ₹${totalSpent.toStringAsFixed(0)} across ${thisMonthTxns.length} expenses. Top spend: "$topCat" (₹${topAmt.toStringAsFixed(0)}). Write ONE savage, witty, affectionate Indian household roast (maximum 20 words) in quotes, e.g. "23 Swiggy orders. Your kitchen has filed a missing-person report." Return JSON {"roast": "..."}';

    final res = await AiStructurer.askJson(
      config: cfg,
      system: 'You generate savage, hilarious, affectionate roasts of household spending habits for sharing on WhatsApp. Return JSON {"roast": "..."}',
      input: prompt,
      schema: ({required bool strict}) => {
        'type': 'object',
        'properties': {
          'roast': {'type': 'string'},
        },
        'required': ['roast'],
      },
      example: {'roast': '23 Swiggy orders. Your kitchen has officially filed a missing-person report.'},
    );

    if (mounted && res.data != null && res.data!['roast'] != null) {
      setState(() {
        _aiRoast = res.data!['roast'].toString();
      });
    }
  }

  String _defaultRoast(V3State s, List<TxnRow> txns) {
    final foodCount = txns.where((t) => t.categoryKey == 'groceries' || t.title.toLowerCase().contains('swiggy') || t.title.toLowerCase().contains('zomato')).length;
    if (foodCount >= 5) {
      return '$foodCount food deliveries this month. Your kitchen stove is officially considering filing for abandonment. 🍳';
    }
    if (txns.length > 20) {
      return 'Your UPI app processed ${txns.length} payments this month. Your thumb is in better shape than your savings account. 💸';
    }
    return 'Your bank account survived another month of "we definitely needed this". Treat yourself to tap water! 💧';
  }

  void _shareRoast(String roast) {
    Share.share(
      '🔥 KinPurse AI Spending Roast 🔥\n\n"$roast"\n\nTrack family spending and get roasted together on KinPurse!',
      subject: 'My Monthly Spending Roast',
    );
  }

  void _shareRecap(String summary) {
    Share.share(
      '✨ KinPurse Monthly Recap ✨\n\n$summary\n\nTrack family spending together with KinPurse!',
      subject: 'Our Family Monthly Recap',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final now = DateTime.now();
    final thisMonthName = _monthName(now.month);
    final prevMonthName = _monthName(now.month == 1 ? 12 : now.month - 1);

    // Current month window
    final curStart = DateTime(now.year, now.month, 1);
    final curTxns = s.txns.where((t) => t.isExpense && !t.occurredAt.isBefore(curStart)).toList();
    final curSpent = curTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final curIncome = s.txns
        .where((t) => t.isIncome && !t.occurredAt.isBefore(curStart))
        .fold<double>(0.0, (acc, t) => acc + t.amount);

    // Previous month window
    final prevStart = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);
    final prevEnd = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
    final prevSpent = s.txns
        .where((t) => t.isExpense && !t.occurredAt.isBefore(prevStart) && !t.occurredAt.isAfter(prevEnd))
        .fold<double>(0.0, (acc, t) => acc + t.amount);

    final diff = prevSpent > 0 ? ((curSpent - prevSpent) / prevSpent) * 100 : 0.0;

    // Top categories
    final catTotals = <String, double>{};
    for (final t in curTxns) {
      catTotals[t.categoryKey] = (catTotals[t.categoryKey] ?? 0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCatKey = sortedCats.isNotEmpty ? sortedCats.first.key : 'other';
    final topCatAmt = sortedCats.isNotEmpty ? sortedCats.first.value : 0.0;
    final topCatName = s.catStyle(topCatKey).name;

    // Biggest single expense
    final biggestTxn = curTxns.isEmpty
        ? null
        : curTxns.reduce((a, b) => a.amount > b.amount ? a : b);

    // Member spenders
    final memberTotals = <String, double>{};
    for (final t in curTxns) {
      final uid = t.userId ?? t.paidBy;
      if (uid != null) {
        memberTotals[uid] = (memberTotals[uid] ?? 0) + t.amount;
      }
    }
    final sortedMembers = memberTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mvpMemberId = sortedMembers.isNotEmpty ? sortedMembers.first.key : null;
    final mvpMember = mvpMemberId != null ? s.memberName(mvpMemberId) : 'The Family';
    final mvpAmount = sortedMembers.isNotEmpty ? sortedMembers.first.value : 0.0;

    final summaryShareText = '📊 $thisMonthName Spend: ${V3Design.inr(curSpent)}\n'
        '🏆 Top Category: $topCatName (${V3Design.inr(topCatAmt)})\n'
        '⭐ Top Contributor: $mvpMember (${V3Design.inr(mvpAmount)})\n'
        '${diff < 0 ? '📉 Saved ${diff.abs().toStringAsFixed(1)}% compared to $prevMonthName!' : ''}';

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top story progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: i <= _currentPage ? Nocturne.accent : Nocturne.neutral800,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Main swipeable cards
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  // Card 1: Total & Month Overview
                  _StoryCard(
                    badge: '$thisMonthName Overview',
                    badgeColor: Nocturne.accent300,
                    icon: PhRegular.sparkle,
                    title: 'Your Family Spend',
                    headline: V3Design.inr(curSpent),
                    subtitle: curIncome > 0
                        ? 'Earned ${V3Design.inr(curIncome)} · Net cash flow ${V3Design.inr(curIncome - curSpent)}'
                        : 'Total expenses recorded across ${curTxns.length} entries',
                    highlight: _aiCaption ??
                        (diff < 0
                            ? 'Down ${diff.abs().toStringAsFixed(1)}% vs $prevMonthName! Amazing saving! 📉'
                            : 'Tracking steadily with previous months.'),
                    cardColor: Nocturne.surface,
                  ),

                  // Card 2: Top Category
                  _StoryCard(
                    badge: 'Category Breakdown',
                    badgeColor: NocturneSemantic.income,
                    icon: PhRegular.chartDonut,
                    title: 'Top Spending Category',
                    headline: topCatName,
                    subtitle: '${V3Design.inr(topCatAmt)} of your budget went here (${curSpent > 0 ? ((topCatAmt / curSpent) * 100).toStringAsFixed(0) : 0}% of total)',
                    highlight: sortedCats.length > 1
                        ? 'Runner-up: ${s.catStyle(sortedCats[1].key).name} (${V3Design.inr(sortedCats[1].value)})'
                        : 'All spending was grouped in this category.',
                    cardColor: Nocturne.surface,
                  ),

                  // Card 3: Biggest Purchase & MVP
                  _StoryCard(
                    badge: 'Highlights',
                    badgeColor: Nocturne.accent200,
                    icon: PhRegular.star,
                    title: 'Biggest Single Expense',
                    headline: biggestTxn != null ? V3Design.inr(biggestTxn.amount) : '₹0',
                    subtitle: biggestTxn != null
                        ? '"${biggestTxn.title}" on ${biggestTxn.occurredAt.day} $thisMonthName'
                        : 'No expenses yet this month',
                    highlight: 'Top Spender: $mvpMember contributed ${V3Design.inr(mvpAmount)} toward family expenses.',
                    cardColor: Nocturne.surface,
                  ),

                  // Card 4: The Monthly Roast 🔥
                  _StoryCard(
                    badge: '🔥 The Monthly Roast',
                    badgeColor: NocturneSemantic.expense,
                    icon: PhRegular.lightning,
                    title: 'AI Reality Check',
                    headline: 'Brace for Impact',
                    subtitle: 'A loving review of your financial choices this month',
                    highlight: _aiRoast ?? _defaultRoast(s, curTxns),
                    cardColor: Nocturne.surface,
                    action: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NocturneSemantic.expense,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _shareRoast(_aiRoast ?? _defaultRoast(s, curTxns)),
                      icon: const Icon(PhRegular.shareNetwork, size: 16),
                      label: const Text('Share Roast on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Card 5: Wrap-Up & Share
                  _StoryCard(
                    badge: 'Family Scorecard',
                    badgeColor: NocturneSemantic.income,
                    icon: PhRegular.star,
                    title: 'Ready for Next Month',
                    headline: '${s.goals.where((g) => g.isCompleted).length}/${s.goals.length} Goals Met',
                    subtitle: 'Shared notes updated, budgets balanced, bills settled.',
                    highlight: 'Share this month’s recap image and achievements with your family on WhatsApp!',
                    cardColor: Nocturne.surface,
                    action: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Nocturne.accent,
                        foregroundColor: Nocturne.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _shareRecap(summaryShareText),
                      icon: const Icon(PhRegular.shareNetwork, size: 16),
                      label: const Text('Share Recap', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Navigation & Share Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      icon: const Icon(PhRegular.arrowLeft, size: 14, color: Nocturne.neutral400),
                      label: const Text('Back', style: TextStyle(color: Nocturne.neutral400)),
                    )
                  else
                    const SizedBox.shrink(),
                  if (_currentPage < 4)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Nocturne.surface,
                        foregroundColor: Nocturne.accent300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Nocturne.accent700),
                        ),
                      ),
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      icon: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                      label: const Icon(PhRegular.caretRight, size: 14),
                    )
                  else
                    IconButton(
                      onPressed: () => _shareRecap(summaryShareText),
                      icon: const Icon(PhRegular.shareNetwork, color: Nocturne.accent300),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

class _StoryCard extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final String title;
  final String headline;
  final String subtitle;
  final String highlight;
  final Color cardColor;
  final Widget? action;

  const _StoryCard({
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.title,
    required this.headline,
    required this.subtitle,
    required this.highlight,
    required this.cardColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Nocturne.neutral800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badge.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
              color: Nocturne.neutral400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Nocturne.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, height: 1.4, color: Nocturne.neutral300),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(PhRegular.quotes, size: 16, color: Nocturne.accent300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlight,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            Center(child: action!),
          ],
        ],
      ),
    );
  }
}

