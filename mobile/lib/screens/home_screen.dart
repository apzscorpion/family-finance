import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Bar / User Header
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 12),
            child: Row(
              children: [
                // User Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accent500, AppTheme.accent700],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(provider.currentUserInitial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                // Greeting & Context Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good morning, ${provider.currentUserName.isNotEmpty ? provider.currentUserName : 'User'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                      Text(
                        provider.scopeMemberId == null
                            ? '${provider.familyName} · ${provider.members.length} ${provider.members.length == 1 ? 'member' : 'members'}'
                            : (provider.scopeMemberId == 'me'
                                ? 'My finances'
                                : '${provider.members.firstWhere((m) => m.id == provider.scopeMemberId, orElse: () => provider.members.first).name}\'s finances'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Shared Notes Button
                IconButton(
                  onPressed: () => provider.openSubPage('notes'),
                  icon: const Icon(Icons.note_alt_outlined, size: 20, color: AppTheme.text),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    side: const BorderSide(color: Color(0xFF3F424D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(42, 42),
                  ),
                ),
                const SizedBox(width: 8),
                // Bell Notification Button with Badge
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => provider.openSubPage('notifs'),
                      icon: const Icon(Icons.notifications_none, size: 20, color: AppTheme.text),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        side: const BorderSide(color: Color(0xFF3F424D)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(42, 42),
                      ),
                    ),
                    if (provider.notifBadgeCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${provider.notifBadgeCount}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.bg),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                // Settings Button
                IconButton(
                  onPressed: () => provider.openSubPage('settings'),
                  icon: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.text),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    side: const BorderSide(color: Color(0xFF3F424D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(42, 42),
                  ),
                ),
              ],
            ),
          ),

          // 2. Context Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                _buildContextChip(
                  context: context,
                  provider: provider,
                  id: 'family',
                  label: 'Family',
                  icon: Icons.people_outline,
                  avatarBg: AppTheme.accent800,
                ),
                const SizedBox(width: 8),
                _buildContextChip(
                  context: context,
                  provider: provider,
                  id: 'me',
                  label: 'Me',
                  initial: provider.currentUserInitial,
                  avatarBg: AppTheme.accent700,
                ),
                const SizedBox(width: 8),
                ...provider.members.skip(1).map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildContextChip(
                      context: context,
                      provider: provider,
                      id: m.id,
                      label: m.name,
                      initial: m.initial,
                      avatarBg: m.color.withOpacity(0.4),
                    ),
                  );
                }),
              ],
            ),
          ),

          // 3. Tracked Balance Card + Account/Method Selector (Cash, Salary, Loan, UPI, Bank, Card)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppTheme.balanceGradient,
                border: Border.all(color: AppTheme.accent800, width: 1),
                boxShadow: const [AppTheme.shadowMd],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.selectedAccount == 'All'
                            ? (provider.scopeMemberId == null
                                ? 'ALL ACCOUNTS BALANCE'
                                : (provider.scopeMemberId == 'me' ? 'MY TOTAL BALANCE' : 'MEMBER BALANCE'))
                            : '${provider.selectedAccount.toUpperCase()} ACCOUNT BALANCE',
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent300,
                        ),
                      ),
                      // 7D / 30D Selector
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _buildPeriodButton(provider, '7d', '7D'),
                            _buildPeriodButton(provider, '30d', '30D'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Balance Text, Hide Eye Toggle & Set Balances Button
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                provider.balanceHidden ? '₹ ••••••' : formatInr(provider.trackedBalance),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () => provider.toggleBalanceHidden(),
                              icon: Icon(
                                provider.balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: AppTheme.textMuted,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showEditBalancesModal(context, provider),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accent700),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 13, color: AppTheme.accent200),
                              SizedBox(width: 5),
                              Text(
                                'Set Balances',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent100),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Interactive Account / Wallet Selector (All, Cash, Salary, Loan, UPI, Bank, Card)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: FinanceProvider.walletAccounts.map((acct) {
                        final isSelected = provider.selectedAccount == acct;
                        final bal = provider.accountBalance(acct);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => provider.setSelectedAccount(acct),
                            onLongPress: acct == 'All'
                                ? null
                                : () => _showEditBalancesModal(context, provider, initialFocusAccount: acct),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accent : Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _accountIcon(acct),
                                    size: 13,
                                    color: isSelected ? AppTheme.bg : AppTheme.accent200,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        acct,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppTheme.bg : Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        provider.balanceHidden ? '₹•••' : formatInr(bal),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppTheme.bg : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),
                  // Spent vs Received summary pills
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.selectedAccount == 'All' ? 'SPENT' : 'SPENT (${provider.selectedAccount.toUpperCase()})',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSubtle),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.balanceHidden ? '₹ •••' : formatInr(provider.totalExpense),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.selectedAccount == 'All' ? 'RECEIVED' : 'RECEIVED (${provider.selectedAccount.toUpperCase()})',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSubtle),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.balanceHidden ? '₹ •••' : formatInr(provider.totalIncome),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Quick Action Buttons Grid (Add transaction, Cards, SMS inbox, Family, Insights)
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  context: context,
                  label: 'Add expense',
                  icon: Icons.add,
                  isPrimary: true,
                  onTap: () => QuickAddSheet.show(context),
                ),
                _buildQuickActionButton(
                  context: context,
                  label: 'Cards',
                  icon: Icons.credit_card_rounded,
                  badge: provider.cards.isNotEmpty ? '${provider.cards.length}' : null,
                  onTap: () => provider.openSubPage('cards'),
                ),
                _buildQuickActionButton(
                  context: context,
                  label: 'SMS Inbox',
                  icon: Icons.chat_bubble_outline,
                  badge: provider.smsQueue.isNotEmpty ? '${provider.smsQueue.length}' : null,
                  onTap: () => provider.openSubPage('sms_inbox'),
                ),
                _buildQuickActionButton(
                  context: context,
                  label: 'Family',
                  icon: Icons.people_outline,
                  badge: provider.approvals.isNotEmpty ? '${provider.approvals.length}' : null,
                  onTap: () => provider.setTab(3),
                ),
                _buildQuickActionButton(
                  context: context,
                  label: 'Insights',
                  icon: Icons.bar_chart_rounded,
                  onTap: () => provider.setTab(2),
                ),
              ],
            ),
          ),

          // 4B. Credit Cards & Automatic Credit Usage Section
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 18),
            child: InkWell(
              onTap: () => provider.openSubPage('cards'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent700.withValues(alpha: 0.55)),
                  boxShadow: const [AppTheme.shadowSm],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.accent900,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.credit_card_rounded, size: 18, color: AppTheme.accent200),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credit Cards & Auto Usage (${provider.cards.length})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
                                ),
                                Text(
                                  provider.cards.isEmpty
                                      ? 'Tap to add cards, limits & auto-detect SMS/statements'
                                      : 'Used ${formatInr(provider.totalCreditUsed)} of ${formatInr(provider.totalCreditLimit)} (${provider.totalCreditUtilizationPct.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accent900,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accent700),
                          ),
                          child: Text(
                            provider.cards.isEmpty ? '+ Add Card' : 'Total List',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.accent200),
                          ),
                        ),
                      ],
                    ),
                    if (provider.cards.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.totalCreditLimit > 0
                              ? (provider.totalCreditUsed / provider.totalCreditLimit).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 6,
                          backgroundColor: AppTheme.bg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            provider.totalCreditUtilizationPct >= 70
                                ? AppTheme.red
                                : (provider.totalCreditUtilizationPct >= 30 ? AppTheme.amber : AppTheme.green),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: provider.cards.map((c) {
                            final used = provider.cardUsedAmount(c.id);
                            final avail = provider.cardAvailableCredit(c.id);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(c.colorHex),
                                      Color.lerp(Color(c.colorHex), Colors.black, 0.4) ?? Colors.black87,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          c.shortLabel,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          c.network.toUpperCase(),
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Used ${formatInr(used)} · Avl ${formatInr(avail)}',
                                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 5. Active SMS Alert Banner
          if (provider.smsQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 18),
              child: InkWell(
                onTap: () => provider.openSubPage('sms_inbox'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.accent900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mark_chat_unread_outlined, size: 20, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${provider.smsQueue.length} bank SMS detected',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text),
                            ),
                            const Text('Review parsed expenses', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.bg)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Active Approvals Banner
          if (provider.approvals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 10),
              child: InkWell(
                onTap: () => provider.setTab(3),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.amber.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.amberBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.hourglass_empty, size: 20, color: AppTheme.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${provider.approvals.length} requests from family',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text),
                            ),
                            const Text('Needs your review', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.amber),
                        ),
                        child: const Text('Review', style: TextStyle(fontSize: 12, color: AppTheme.amber)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Where it went (Category Spending Card)
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [AppTheme.shadowSm],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Where it went', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                      Text(provider.period == '7d' ? 'Last 7 days' : 'Last 30 days', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategorySpendingView(context, provider, formatInr),
                ],
              ),
            ),
          ),

          // 8. Family Spending Section
          if (provider.scopeMemberId == null)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [AppTheme.shadowSm],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Family spending', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                        TextButton(
                          onPressed: () => provider.setTab(3),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: const Text('All members', style: TextStyle(fontSize: 12, color: AppTheme.accent300)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...provider.members.map((m) {
                      final mSpend = provider.transactions
                          .filterInScope(m.id, provider.maxDays)
                          .where((t) => t.type == 'expense')
                          .fold(0.0, (sum, t) => sum + t.amount);

                      final maxMemberSpend = provider.members.map((mem) {
                        return provider.transactions
                            .filterInScope(mem.id, provider.maxDays)
                            .where((t) => t.type == 'expense')
                            .fold(0.0, (sum, t) => sum + t.amount);
                      }).reduce(math.max);

                      final pct = maxMemberSpend > 0 ? (mSpend / maxMemberSpend) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: InkWell(
                          onTap: () => provider.setContext(m.id),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: m.color.withOpacity(0.4)),
                                alignment: Alignment.center,
                                child: Text(m.initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${m.name} · ${m.rel}', style: const TextStyle(fontSize: 13.5, color: AppTheme.text)),
                                        Text(formatInr(mSpend), style: const TextStyle(fontSize: 13.5, color: AppTheme.text)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: pct.clamp(0.02, 1.0),
                                        minHeight: 4,
                                        backgroundColor: AppTheme.bg,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Text('Confirmed expenses only · pending requests excluded', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                  ],
                ),
              ),
            ),

          // 9. Budgets Progress Grid
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [AppTheme.shadowSm],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Budgets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                      Text('Alert at ${provider.alertThreshold}%', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: FinanceProvider.budgets.map((b) {
                      final cat = FinanceProvider.categories[b.catKey] ?? FinanceProvider.categories['shopping']!;
                      final limit = provider.scopeMemberId == null ? b.familyLimit : b.personalLimit;

                      final spent = provider.transactions
                          .filterInScope(provider.scopeMemberId, 30)
                          .where((t) => t.catKey == b.catKey && t.type == 'expense')
                          .fold(0.0, (sum, t) => sum + t.amount);

                      final pct = limit > 0 ? (spent / limit) * 100 : 0.0;
                      final isOver = pct >= 100;
                      final isWarn = pct >= provider.alertThreshold;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isOver ? AppTheme.red.withOpacity(0.4) : Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(cat.icon, size: 16, color: cat.color),
                                const SizedBox(width: 6),
                                Text(cat.name, style: const TextStyle(fontSize: 12.5, color: AppTheme.text)),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(formatInr(spent), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text)),
                                Text(' / ${formatInr(limit)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                              ],
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (pct / 100).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: AppTheme.surface,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOver ? AppTheme.red : (isWarn ? AppTheme.amber : AppTheme.accent),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  isOver ? Icons.warning_amber : (isWarn ? Icons.info_outline : Icons.check),
                                  size: 12,
                                  color: isOver ? AppTheme.red : (isWarn ? AppTheme.amber : AppTheme.textSubtle),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isOver
                                        ? 'Over by ${formatInr(spent - limit)}'
                                        : (isWarn ? '${formatInr(limit - spent)} left · ${pct.round()}%' : '${formatInr(limit - spent)} left'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOver ? AppTheme.red : (isWarn ? AppTheme.amber : AppTheme.textSubtle),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // 10. Recent Activity List
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                TextButton(
                  onPressed: () => provider.setTab(1),
                  child: const Text('View all', style: TextStyle(fontSize: 12, color: AppTheme.accent300)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [AppTheme.shadowSm],
              ),
              child: provider.scopedTransactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppTheme.textSubtle),
                          SizedBox(height: 8),
                          Text('No transactions recorded yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text)),
                          SizedBox(height: 4),
                          Text('Tap the + button above to log an expense or income for your family.', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : Column(
                      children: provider.scopedTransactions.take(5).map((t) {
                        final cat = FinanceProvider.categories[t.catKey] ?? FinanceProvider.categories['shopping']!;
                        final member = provider.members.firstWhere(
                          (m) => m.id == t.memberId,
                          orElse: () => FamilyMemberDef(id: t.memberId, name: provider.currentUserName, rel: 'You', role: 'Owner', openingBalance: 0, color: AppTheme.accent),
                        );
                        final isIncome = t.type == 'income';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(cat.icon, size: 19, color: cat.color),
                              ),
                              const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title, style: const TextStyle(fontSize: 14, color: AppTheme.text)),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${t.time} · ${member.name}',
                                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent900,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.accent700),
                                            ),
                                            child: Text(
                                              t.cardId != null && provider.cardById(t.cardId) != null
                                                  ? '${provider.cardById(t.cardId)!.shortLabel} · Avl ₹${provider.cardAvailableCredit(t.cardId!).round()}'
                                                  : '${t.method} · Bal ₹${provider.accountBalance(t.method).round()}',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent200),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isIncome ? '+' : '-'}${formatInr(t.amount)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isIncome ? AppTheme.green : AppTheme.text,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      );
    }

  IconData _accountIcon(String acct) {
    switch (acct) {
      case 'Cash':
        return Icons.payments_outlined;
      case 'Salary':
        return Icons.work_outline_rounded;
      case 'Loan':
        return Icons.account_balance_outlined;
      case 'UPI':
        return Icons.qr_code_scanner_rounded;
      case 'Bank':
        return Icons.savings_outlined;
      case 'Card':
        return Icons.credit_card_rounded;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  void _showEditBalancesModal(BuildContext context, FinanceProvider provider, {String? initialFocusAccount}) {
    final accounts = ['Cash', 'Salary', 'Loan', 'UPI', 'Bank', 'Card'];
    final controllers = {
      for (final a in accounts)
        a: TextEditingController(
          text: (provider.accountOpeningBalances[a] ?? 0) > 0
              ? (provider.accountOpeningBalances[a] ?? 0).round().toString()
              : '',
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set Account & Wallet Balances',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Enter your opening or current base balance for Cash, Salary, Loan, UPI, Bank, or Card.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              ...accounts.map((acct) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[acct],
                    autofocus: initialFocusAccount == acct,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(_accountIcon(acct), size: 18, color: AppTheme.accent300),
                      labelText: '$acct Balance (₹)',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      hintText: '0',
                      filled: true,
                      fillColor: AppTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3F424D)),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    for (final acct in accounts) {
                      final raw = controllers[acct]!.text.replaceAll(',', '').trim();
                      final val = double.tryParse(raw) ?? 0.0;
                      await provider.setAccountOpeningBalance(acct, val);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Account Balances', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextChip({
    required BuildContext context,
    required FinanceProvider provider,
    required String id,
    required String label,
    IconData? icon,
    String? initial,
    required Color avatarBg,
  }) {
    final isSelected = provider.ctx == id;
    return GestureDetector(
      onTap: () => provider.setContext(id),
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 5, right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent900 : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppTheme.accent : const Color(0xFF3F424D)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 14, color: Colors.white)
                  : Text(initial ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.text)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(FinanceProvider provider, String code, String label) {
    final isSelected = provider.period == code;
    return GestureDetector(
      onTap: () => provider.setPeriod(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent800 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.accent100 : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    bool isPrimary = false,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isPrimary ? AppTheme.accentButtonGradient : null,
                  color: isPrimary ? null : AppTheme.surface,
                  border: Border.all(color: isPrimary ? AppTheme.accent : const Color(0xFF3F424D)),
                ),
                child: Icon(icon, size: 24, color: isPrimary ? AppTheme.accent100 : AppTheme.text),
              ),
              if (badge != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.bg)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCategorySpendingView(BuildContext context, FinanceProvider provider, String Function(double) formatInr) {
    final expTxns = provider.scopedTransactions.where((t) => t.type == 'expense').toList();
    final Map<String, double> catTotals = {};
    for (var t in expTxns) {
      catTotals[t.catKey] = (catTotals[t.catKey] ?? 0.0) + t.amount;
    }

    final sortedEntries = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totExp = provider.totalExpense;

    if (sortedEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No expenses in selected period', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    return Column(
      children: sortedEntries.take(5).map((entry) {
        final cat = FinanceProvider.categories[entry.key] ?? FinanceProvider.categories['shopping']!;
        final pct = totExp > 0 ? (entry.value / totExp * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(cat.icon, size: 16, color: cat.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 13, color: AppTheme.text))),
                  Text(formatInr(entry.value), style: const TextStyle(fontSize: 13, color: AppTheme.text)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text('${pct.round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.02, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.bg,
                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
