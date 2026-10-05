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
  String _selectedMethod = 'UPI';
  String _selectedMemberId = 'me';
  String? _selectedCardId;

  String? _selectedSubCatKey;

  final List<String> _expenseCatKeys = ['groceries', 'event', 'dining', 'transport', 'fuel', 'shopping', 'bills', 'health', 'education'];
  final List<String> _incomeCatKeys = ['salary', 'loan', 'business', 'gift', 'pension', 'refund'];
  final List<String> _methods = ['Cash', 'Salary', 'Loan', 'UPI', 'Bank', 'Card'];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _amountStr = widget.initialAmount ?? '';
    _selectedCatKey = widget.initialCategory ?? (_type == 'expense' ? 'groceries' : 'salary');
    final prov = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.initialMethod != null && _methods.contains(widget.initialMethod)) {
      _selectedMethod = widget.initialMethod!;
    } else if (prov.selectedAccount != 'All' && _methods.contains(prov.selectedAccount)) {
      _selectedMethod = prov.selectedAccount;
    } else if (_type == 'income' && _selectedCatKey == 'salary') {
      _selectedMethod = 'Salary';
    } else if (_type == 'income' && _selectedCatKey == 'loan') {
      _selectedMethod = 'Loan';
    }
    _selectedCardId = widget.initialCardId ?? (prov.cards.isNotEmpty ? prov.cards.first.id : null);
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

    final catDef = FinanceProvider.categories[_selectedCatKey] ?? FinanceProvider.categories['shopping']!;
    final isForOther = _type == 'expense' && _selectedMemberId != 'me';
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
      Navigator.pop(context);
      provider.showToast('Sent to ${targetMember.name} for approval');
    } else {
      final txn = TransactionDef(
        id: DateTime.now().millisecondsSinceEpoch,
        daysAgo: 0,
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
      Navigator.pop(context);
      final cardObj = provider.cardById(effectiveCardId);
      if (cardObj != null) {
        provider.showToast('₹${amt.toInt()} charged to ${cardObj.shortLabel} · Avl ₹${provider.cardAvailableCredit(cardObj.id).round()}');
      } else {
        provider.showToast('${_type == 'expense' ? 'Expense' : 'Income'} of ₹${amt.toInt()} saved');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final amtVal = double.tryParse(_amountStr) ?? 0.0;
    final isForOther = _type == 'expense' && _selectedMemberId != 'me';
    final targetMember = provider.members.firstWhere(
      (m) => m.id == _selectedMemberId,
      orElse: () => provider.members.first,
    );
    final activeCatList = _type == 'expense' ? _expenseCatKeys : _incomeCatKeys;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
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
                        _selectedCatKey = 'groceries';
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
                        _selectedCatKey = 'salary';
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
          const SizedBox(height: 16),
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
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: _amountStr.isNotEmpty
                      ? (_type == 'expense' ? AppTheme.text : AppTheme.green)
                      : AppTheme.textSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: activeCatList.map((catKey) {
                final c = FinanceProvider.categories[catKey] ?? FinanceProvider.categories['shopping']!;
                final isSelected = _selectedCatKey == catKey;
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
                      _selectedCatKey = catKey;
                      _selectedSubCatKey = null;
                    }),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.accent900,
                    side: BorderSide(color: isSelected ? AppTheme.accent : const Color(0xFF3F424D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
          if (FinanceProvider.categories[_selectedCatKey]?.subCategories.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
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
                    children: _methods.map((m) {
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
            const SizedBox(height: 8),
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
          const SizedBox(height: 10),
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
                              color: m.color.withOpacity(0.3),
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
            const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
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
          const SizedBox(height: 12),
          Opacity(
            opacity: amtVal > 0 ? 1.0 : 0.45,
            child: SizedBox(
              width: double.infinity,
              height: 50,
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
                          : 'Save ${_type == 'expense' ? 'expense' : 'income'} · ₹${amtVal.toInt()}')
                      : 'Enter an amount',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
