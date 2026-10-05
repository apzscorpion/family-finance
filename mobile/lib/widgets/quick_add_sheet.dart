import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';

class QuickAddSheet extends StatefulWidget {
  final String initialType;
  final String? initialAmount;
  final String? initialCategory;
  final String? initialTitle;
  final String? smsId;
  final String? initialMethod;
  final String? initialCardId;

  const QuickAddSheet({
    super.key,
    this.initialType = 'expense',
    this.initialAmount,
    this.initialCategory,
    this.initialTitle,
    this.smsId,
    this.initialMethod,
    this.initialCardId,
  });

  static void show(
    BuildContext context, {
    String type = 'expense',
    String? amount,
    String? cat,
    String? title,
    String? smsId,
    String? initialMethod,
    String? initialCardId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddSheet(
        initialType: type,
        initialAmount: amount,
        initialCategory: cat,
        initialTitle: title,
        smsId: smsId,
        initialMethod: initialMethod,
        initialCardId: initialCardId,
      ),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late String _type; // 'expense' or 'income'
  late String _amountStr;
  late String _selectedCatKey;
  String _selectedMethod = 'Cash';
  String _selectedMemberId = 'me';
  String? _selectedCardId;
  String? _selectedSubCatKey;
  String? _lastSavedBanner;
  int _savedCountInSession = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _amountStr = widget.initialAmount ?? '';
    _selectedCatKey = widget.initialCategory ?? (_type == 'expense' ? 'groceries' : 'salary');
    final prov = Provider.of<FinanceProvider>(context, listen: false);
    final methods = prov.allConfiguredAccounts;

    if (prov.scopeMemberId != null && prov.scopeMemberId!.isNotEmpty) {
      _selectedMemberId = prov.scopeMemberId!;
    } else if (prov.members.isNotEmpty) {
      _selectedMemberId = prov.members.first.id;
    }

    if (widget.initialMethod != null && methods.contains(widget.initialMethod)) {
      _selectedMethod = widget.initialMethod!;
    } else if (prov.selectedAccount != 'All' &&
        prov.selectedAccount != 'All Savings' &&
        prov.selectedAccount != 'All Loans' &&
        methods.contains(prov.selectedAccount)) {
      _selectedMethod = prov.selectedAccount;
    } else if (_type == 'income') {
      _syncMethodForIncomeCategory(_selectedCatKey, prov);
    } else {
      _selectedMethod = methods.contains('Cash')
          ? 'Cash'
          : (methods.isNotEmpty ? methods.first : 'Cash');
    }
    _selectedCardId = widget.initialCardId ?? (prov.cards.isNotEmpty ? prov.cards.first.id : null);
  }

  void _syncMethodForIncomeCategory(String catKey, FinanceProvider prov) {
    final cat = FinanceProvider.categories[catKey];
    if (cat == null) return;
    final all = prov.allConfiguredAccounts;
    final match = all.where((a) => a.toLowerCase() == cat.name.toLowerCase()).toList();
    if (match.isNotEmpty) {
      _selectedMethod = match.first;
    } else if (catKey == 'loan' && prov.loanTypes.isNotEmpty) {
      _selectedMethod = prov.loanTypes.first;
    } else if (prov.savingsWays.isNotEmpty) {
      _selectedMethod = prov.savingsWays.first;
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'del') {
        if (_amountStr.isNotEmpty) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        }
      } else if (key == '.') {
        if (!_amountStr.contains('.')) {
          _amountStr = '${_amountStr.isEmpty ? '0' : _amountStr}.';
        }
      } else {
        if (_amountStr.replaceFirst('.', '').length < 8) {
          _amountStr = '${_amountStr == '0' ? '' : _amountStr}$key';
        }
      }
    });
  }

  void _submit(FinanceProvider provider) {
    final amt = double.tryParse(_amountStr) ?? 0.0;
    if (amt <= 0) return;

    final catDef = FinanceProvider.categories[_selectedCatKey] ??
        FinanceProvider.categories['shopping'] ??
        FinanceProvider.defaultCategories['shopping']!;
    final myMemberId = provider.members.isNotEmpty ? provider.members.first.id : 'me';
    final isForOther = _type == 'expense' && _selectedMemberId != myMemberId && _selectedMemberId != 'me';
    final targetMember = provider.members.firstWhere(
      (m) => m.id == _selectedMemberId,
      orElse: () => provider.members.first,
    );

    final effectiveCardId = _selectedMethod == 'Card'
        ? (_selectedCardId ?? (provider.cards.isNotEmpty ? provider.cards.first.id : null))
        : null;

    if (isForOther) {
      provider.approvals.add(ApprovalItem(
        id: 'a_${DateTime.now().millisecondsSinceEpoch}',
        kind: 'New',
        fromMemberId: _selectedMemberId,
        time: 'Just now',
        reason: 'Added on behalf of ${targetMember.name}',
        newTxn: TransactionDef(
          id: DateTime.now().millisecondsSinceEpoch,
          daysAgo: 0,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          title: widget.initialTitle ?? catDef.name,
          catKey: _selectedCatKey,
          subCatKey: _selectedSubCatKey,
          amount: amt,
          type: _type,
          memberId: _selectedMemberId,
          method: _selectedMethod,
          origin: widget.smsId != null ? 'sms' : 'manual',
          time: 'Now',
          cardId: effectiveCardId,
        ),
      ));
      if (widget.smsId != null) {
        provider.smsQueue.removeWhere((s) => s.id == widget.smsId);
      }
      provider.showToast('Sent to ${targetMember.name} for approval');
      setState(() {
        _savedCountInSession++;
        _amountStr = '';
        _lastSavedBanner = 'Sent ₹${amt.round()} (${catDef.name}) to ${targetMember.name} for approval';
      });
    } else {
      final txn = TransactionDef(
        id: DateTime.now().millisecondsSinceEpoch,
        daysAgo: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        title: widget.initialTitle ?? catDef.name,
        catKey: _selectedCatKey,
        subCatKey: _selectedSubCatKey,
        amount: amt,
        type: _type,
        memberId: _selectedMemberId,
        method: _selectedMethod,
        origin: widget.smsId != null ? 'sms' : 'manual',
        time: 'Now',
        cardId: effectiveCardId,
      );

      if (widget.smsId != null) {
        provider.smsQueue.removeWhere((s) => s.id == widget.smsId);
      }
      provider.addTransaction(txn);
      final updatedBal = provider.accountBalance(_selectedMethod);
      final cardObj = provider.cardById(effectiveCardId);
      if (cardObj != null) {
        provider.showToast(
          '₹${amt.toInt()} charged to ${cardObj.shortLabel} · Avl ₹${provider.cardAvailableCredit(cardObj.id).round()}',
        );
      } else {
        provider.showToast(
          '${_type == 'expense' ? 'Expense' : 'Income'} ₹${amt.toInt()} ($_selectedMethod · Bal ₹${updatedBal.round()})',
        );
      }
      // Keep sheet open so user can keep adding expenses! User manually closes when done.
      setState(() {
        _savedCountInSession++;
        _amountStr = '';
        _lastSavedBanner =
            '✓ Saved ₹${amt.round()} to ${catDef.name} ($_selectedMethod · Bal ₹${updatedBal.round()})';
      });
    }
  }

  void _showAddCustomCategoryDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    String selectedIcon = _type == 'expense' ? 'shopping' : 'savings';
    int selectedColor = _type == 'expense' ? 0xFF9184D9 : 0xFF34D399;

    const iconOptions = [
      'shopping',
      'groceries',
      'dining',
      'transport',
      'fuel',
      'bills',
      'health',
      'education',
      'event',
      'home',
      'flight',
      'coffee',
      'fitness',
      'pets',
      'kids',
      'savings',
      'salary',
      'business',
      'loan',
      'gift',
    ];
    const colorOptions = [
      0xFF9184D9,
      0xFF4ADE80,
      0xFFF97316,
      0xFFEC4899,
      0xFF3B82F6,
      0xFFEAB308,
      0xFFEF4444,
      0xFF06B6D4,
      0xFF8B5CF6,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New ${_type == 'expense' ? 'Expense' : 'Income'} Category',
            style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Subscriptions, Gym, Freelance',
                    hintStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Sub-categories (optional, comma-separated)',
                    hintText: 'e.g. Netflix, Spotify, iCloud',
                    hintStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Icon', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: iconOptions.map((iName) {
                    final active = selectedIcon == iName;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = iName),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: active ? AppTheme.accent900 : AppTheme.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: active ? AppTheme.accent : Colors.white12),
                        ),
                        child: Icon(
                          CategoryDef.iconRegistry[iName] ?? Icons.category_outlined,
                          size: 17,
                          color: active ? AppTheme.accent200 : AppTheme.textMuted,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Color', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: colorOptions.map((cHex) {
                    final active = selectedColor == cHex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = cHex),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(cHex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSubtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bg,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final subs = subCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final newKey = await provider.addOrUpdateCategory(
                  name: name,
                  isIncome: _type == 'income',
                  iconName: selectedIcon,
                  colorHex: selectedColor,
                  subCategoryNames: subs,
                );
                if (newKey.isNotEmpty && mounted) {
                  setState(() {
                    _selectedCatKey = newKey;
                    _selectedSubCatKey = null;
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to FinanceProvider so balances update live inside the sheet after each expense is saved!
    final provider = Provider.of<FinanceProvider>(context);
    final amtVal = double.tryParse(_amountStr) ?? 0.0;
    final myMemberId = provider.members.isNotEmpty ? provider.members.first.id : 'me';
    final isForOther = _type == 'expense' && _selectedMemberId != myMemberId && _selectedMemberId != 'me';
    final targetMember = provider.members.firstWhere(
      (m) => m.id == _selectedMemberId,
      orElse: () => provider.members.first,
    );
    final activeCatDefs = _type == 'expense' ? provider.expenseCategories : provider.incomeCategories;
    final methods = provider.allConfiguredAccounts;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF3F424D), width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header with Drag Handle & Manual Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _savedCountInSession > 0
                    ? '$_savedCountInSession saved in this session'
                    : 'Add Transaction',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _savedCountInSession > 0 ? AppTheme.green : AppTheme.textSubtle,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 16, color: AppTheme.text),
                label: const Text('Close', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.text)),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (_lastSavedBanner != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.45)),
              ),
              child: Text(
                _lastSavedBanner!,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.green),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'expense';
                        _selectedCatKey = provider.expenseCategories.isNotEmpty
                            ? provider.expenseCategories.first.key
                            : 'groceries';
                      });
                    },
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: _type == 'expense' ? AppTheme.accent900 : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _type == 'expense' ? AppTheme.accent : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Expense',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _type == 'expense' ? AppTheme.accent100 : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'income';
                        _selectedCatKey = provider.incomeCategories.isNotEmpty
                            ? provider.incomeCategories.first.key
                            : 'salary';
                        _syncMethodForIncomeCategory(_selectedCatKey, provider);
                      });
                    },
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: _type == 'income' ? AppTheme.accent900 : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _type == 'income' ? AppTheme.accent : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Income',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _type == 'income' ? AppTheme.accent100 : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹ ',
                style: TextStyle(
                  fontSize: 26,
                  color: _amountStr.isNotEmpty ? AppTheme.textMuted : AppTheme.textSubtle,
                ),
              ),
              Text(
                _amountStr.isEmpty ? '0' : _amountStr,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: _amountStr.isNotEmpty
                      ? (_type == 'expense' ? AppTheme.text : AppTheme.green)
                      : AppTheme.textSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Dynamic Categories Row + "+ Category" button
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...activeCatDefs.map((c) {
                  final isSelected = _selectedCatKey == c.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon, size: 14, color: c.color),
                          const SizedBox(width: 5),
                          Text(c.name, style: TextStyle(fontSize: 12.5, color: isSelected ? AppTheme.text : AppTheme.textMuted)),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        _selectedCatKey = c.key;
                        _selectedSubCatKey = null;
                        if (_type == 'income') {
                          _syncMethodForIncomeCategory(c.key, provider);
                        }
                      }),
                      backgroundColor: AppTheme.surface,
                      selectedColor: AppTheme.accent900,
                      side: BorderSide(color: isSelected ? AppTheme.accent : const Color(0xFF3F424D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14, color: AppTheme.accent200),
                  label: const Text('+ Category', style: TextStyle(fontSize: 12, color: AppTheme.accent200)),
                  backgroundColor: AppTheme.bg,
                  side: const BorderSide(color: AppTheme.accent700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  onPressed: () => _showAddCustomCategoryDialog(context, provider),
                ),
              ],
            ),
          ),
          if (FinanceProvider.categories[_selectedCatKey]?.subCategories.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: (FinanceProvider.categories[_selectedCatKey]?.subCategories ?? []).map((sub) {
                  final isSubSelected = _selectedSubCatKey == sub.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(sub.name, style: TextStyle(fontSize: 11.5, color: isSubSelected ? AppTheme.accent100 : AppTheme.textMuted)),
                      selected: isSubSelected,
                      onSelected: (_) => setState(() => _selectedSubCatKey = sub.key),
                      backgroundColor: AppTheme.bg,
                      selectedColor: AppTheme.accent900,
                      side: BorderSide(color: isSubSelected ? AppTheme.accent : const Color(0xFF3F424D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Account: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: methods.map((m) {
                      final isSelected = _selectedMethod == m;
                      final bal = provider.accountBalance(m);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            '$m · ₹${bal.round()}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppTheme.accent100 : AppTheme.textMuted,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedMethod = m),
                          backgroundColor: AppTheme.surface,
                          selectedColor: AppTheme.accent900,
                          side: BorderSide(color: isSelected ? AppTheme.accent600 : const Color(0xFF3F424D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedMethod == 'Card') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Card: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...provider.cards.map((c) {
                          final isCardSel = _selectedCardId == c.id;
                          final avail = provider.cardAvailableCredit(c.id);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                '${c.shortLabel} · Avl ₹${avail.round()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCardSel ? FontWeight.w600 : FontWeight.w400,
                                  color: isCardSel ? AppTheme.accent100 : AppTheme.textMuted,
                                ),
                              ),
                              selected: isCardSel,
                              onSelected: (_) => setState(() => _selectedCardId = c.id),
                              backgroundColor: AppTheme.bg,
                              selectedColor: AppTheme.accent900,
                              side: BorderSide(color: isCardSel ? AppTheme.accent : const Color(0xFF3F424D)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add_card, size: 14, color: AppTheme.accent200),
                          label: Text(
                            provider.cards.isEmpty ? '+ Add Card' : 'Manage Cards',
                            style: const TextStyle(fontSize: 11, color: AppTheme.accent200),
                          ),
                          backgroundColor: AppTheme.bg,
                          side: const BorderSide(color: AppTheme.accent700),
                          onPressed: () {
                            Navigator.pop(context);
                            provider.openSubPage('cards');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('For ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.members.map((m) {
                      final isSelected = _selectedMemberId == m.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMemberId = m.id),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: m.color.withValues(alpha: 0.3),
                              border: Border.all(
                                color: isSelected ? AppTheme.accent300 : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              m.initial,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (isForOther) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.hourglass_empty, size: 14, color: AppTheme.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${targetMember.name} will review this before it\'s added to their records',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.amber),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'del'].map((k) {
                return Material(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _onKeyPress(k),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      child: k == 'del'
                          ? const Icon(Icons.backspace_outlined, size: 20, color: AppTheme.text)
                          : Text(
                              k,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.text),
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: amtVal > 0 ? 1.0 : 0.45,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: amtVal > 0 ? () => _submit(provider) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent900,
                  foregroundColor: AppTheme.accent100,
                  side: const BorderSide(color: AppTheme.accent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  amtVal > 0
                      ? (isForOther
                          ? 'Send to ${targetMember.name} for approval'
                          : 'Save ${_type == 'expense' ? 'expense' : 'income'} · ₹${amtVal.toInt()} ($_selectedMethod)')
                      : 'Enter an amount (tap Close when done)',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

