import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'calc_engine.dart';

/// Sheet to view, manage, and create recurring transactions.
class V3RecurringSheet extends StatefulWidget {
  const V3RecurringSheet({super.key});

  @override
  State<V3RecurringSheet> createState() => _V3RecurringSheetState();
}

class _V3RecurringSheetState extends State<V3RecurringSheet> {
  String _filter = 'all'; // 'all' | 'income' | 'expense'

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final items = s.recurring.where((r) {
      if (_filter == 'income') return r.isIncome;
      if (_filter == 'expense') return r.isExpense;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recurring rules',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.text)),
                  SizedBox(height: 2),
                  Text('Salary, rent, bills & EMIs tracked on a schedule',
                      style:
                          TextStyle(fontSize: 12, color: Nocturne.neutral500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                barrierColor: const Color(0xA306070E),
                isScrollControlled: true,
                builder: (_) => const _AddRecurringDialog(),
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Nocturne.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhBold.plus, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text('New rule',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _filterChip('All (${s.recurring.length})', 'all'),
            const SizedBox(width: 8),
            _filterChip(
                'Income (${s.recurring.where((r) => r.isIncome).length})',
                'income'),
            const SizedBox(width: 8),
            _filterChip(
                'Expenses (${s.recurring.where((r) => r.isExpense).length})',
                'expense'),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.neutral800, width: 1),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(PhRegular.arrowsClockwise,
                    size: 32, color: Nocturne.neutral500),
                const SizedBox(height: 8),
                Text(
                  _filter == 'income'
                      ? 'No recurring income set up yet'
                      : _filter == 'expense'
                          ? 'No recurring expenses set up yet'
                          : 'No recurring transactions set up yet',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set up salary credited on the 1st, rent, or Netflix subscriptions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Nocturne.neutral500),
                ),
              ],
            ),
          ),
        ] else ...[
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = items[i];
                final style = s.catStyle(r.categoryKey);
                final dueDays = r.dueInDays;
                final dueText = dueDays == 0
                    ? 'Due today'
                    : dueDays > 0
                        ? 'Due in $dueDays ${dueDays == 1 ? 'day' : 'days'}'
                        : 'Overdue by ${dueDays.abs()} days';

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Nocturne.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Nocturne.neutral800, width: 1),
                  ),
                  child: Row(
                    children: [
                      V3IconTile(
                        icon: style.icon,
                        color: style.color,
                        size: 38,
                        radius: 11,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Nocturne.text),
                                  ),
                                ),
                                if (r.autoPost) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Nocturne.accent900,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Auto',
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Nocturne.accent200)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_daySuffix(r.nextDue.day)} of month · $dueText',
                              style: const TextStyle(
                                  fontSize: 11.5, color: Nocturne.neutral500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${r.isIncome ? '+' : '-'} ${V3Design.inr(r.amount)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: r.isIncome
                                  ? NocturneSemantic.income
                                  : Nocturne.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _confirmDelete(context, s, r),
                            behavior: HitTestBehavior.opaque,
                            child: const Icon(PhRegular.trash,
                                size: 16, color: Nocturne.neutral500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? Nocturne.neutral700 : Nocturne.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? Nocturne.neutral600 : Nocturne.neutral800, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? Nocturne.text : Nocturne.neutral400,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, V3State s, RecurringRow r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: Text('Delete "${r.title}"?'),
        content: const Text(
            'This will stop future recurring reminders or auto-posts for this item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              s.deleteRecurring(r.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: NocturneSemantic.expense)),
          ),
        ],
      ),
    );
  }

  static String _daySuffix(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }
}

class _AddRecurringDialog extends StatefulWidget {
  const _AddRecurringDialog();

  @override
  State<_AddRecurringDialog> createState() => _AddRecurringDialogState();
}

class _AddRecurringDialogState extends State<_AddRecurringDialog> {
  String _type = 'income'; // default to income since salary was specifically requested!
  final _titleController = TextEditingController();
  String _expression = '';
  int _dayOfMonth = 1;
  final String _cadence = 'monthly';
  String _catKey = 'salary';
  String? _sourceId;
  bool _autoPost = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Monthly Salary';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  double get _value => CalcEngine.evaluate(_expression);

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (k == '=') {
        final res = _value;
        if (res > 0) _expression = CalcEngine.format(res);
      } else if (k == '.') {
        if (!_expression.endsWith('.')) _expression += '.';
      } else if (k == '+' || k == '-' || k == '×' || k == '÷') {
        if (_expression.isNotEmpty) {
          if (_expression.endsWith('+') ||
              _expression.endsWith('-') ||
              _expression.endsWith('×') ||
              _expression.endsWith('÷')) {
            _expression =
                _expression.substring(0, _expression.length - 1) + k;
          } else {
            _expression += k;
          }
        }
      } else {
        _expression += k;
      }
    });
  }

  Future<void> _save() async {
    final s = context.read<V3State>();
    final val = _value;
    if (val <= 0 || _saving) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    var nextDue = DateTime(now.year, now.month, _dayOfMonth);
    if (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
      // Move to next month
      nextDue = DateTime(now.year, now.month + 1, _dayOfMonth);
    }

    final title = _titleController.text.trim().isEmpty
        ? (_type == 'income' ? 'Salary' : 'Monthly bill')
        : _titleController.text.trim();

    final ok = await s.addRecurring(
      title: title,
      amount: val,
      cadence: _cadence,
      nextDue: nextDue,
      type: _type,
      categoryKey: _catKey,
      sourceId: _sourceId,
      autoPost: _autoPost,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save recurring rule')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final catKeys =
        _type == 'income' ? V3Design.incomeCats : V3Design.expenseCats;
    final keys = const [
      '1', '2', '3', '+',
      '4', '5', '6', '-',
      '7', '8', '9', '×',
      '.', '0', '<', '=',
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral700, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Nocturne.neutral700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Add recurring',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Nocturne.text)),
                      const Spacer(),
                      V3Segmented(
                        labels: const ['Income', 'Expense'],
                        selected: _type == 'income' ? 0 : 1,
                        ground: Nocturne.bg,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        onChanged: (i) => setState(() {
                          _type = i == 0 ? 'income' : 'expense';
                          _catKey = i == 0 ? 'salary' : 'bills';
                          if (_type == 'income' &&
                              _titleController.text.isEmpty) {
                            _titleController.text = 'Monthly Salary';
                          }
                        }),
                      ),
                      const SizedBox(width: 10),
                      // Save checkmark (✓)
                      GestureDetector(
                        onTap: (_value > 0 && !_saving) ? _save : null,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _value > 0
                                ? (_type == 'income'
                                    ? NocturneSemantic.income
                                    : Nocturne.accent)
                                : Nocturne.neutral800,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(
                                  PhBold.check,
                                  size: 20,
                                  color: _value > 0
                                      ? Colors.white
                                      : Nocturne.neutral500,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Nocturne.bg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhRegular.notePencil,
                            size: 16, color: Nocturne.neutral500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: const TextStyle(
                                fontSize: 13.5, color: Nocturne.text),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'e.g. Salary, Rent, Netflix',
                              hintStyle: TextStyle(
                                  fontSize: 13.5, color: Nocturne.neutral600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Day of month selector
                  Row(
                    children: [
                      const SizedBox(
                        width: 52,
                        child: Text('Date',
                            style: TextStyle(
                                fontSize: 11.5, color: Nocturne.neutral500)),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 31,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              final d = i + 1;
                              final sel = _dayOfMonth == d;
                              return GestureDetector(
                                onTap: () => setState(() => _dayOfMonth = d),
                                child: Container(
                                  width: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: sel ? Nocturne.accent : Nocturne.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sel
                                          ? Nocturne.accent
                                          : Nocturne.neutral800,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$d',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: sel
                                          ? Colors.white
                                          : Nocturne.neutral400,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Categories single line horizontal scroll
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: catKeys.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final k = catKeys[i];
                        final c = s.catStyle(k);
                        final sel = _catKey == k;
                        return GestureDetector(
                          onTap: () => setState(() => _catKey = k),
                          child: Container(
                            width: 62,
                            decoration: BoxDecoration(
                              color: sel
                                  ? Nocturne.mix(c.color, 18)
                                  : Nocturne.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? c.color : Nocturne.neutral800,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(c.icon,
                                    size: 19,
                                    color: sel ? c.color : Nocturne.neutral400),
                                const SizedBox(height: 3),
                                Text(
                                  c.short,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: sel
                                        ? Nocturne.text
                                        : Nocturne.neutral400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Auto-post toggle
                  GestureDetector(
                    onTap: () => setState(() => _autoPost = !_autoPost),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _autoPost
                              ? Nocturne.accent600
                              : Nocturne.neutral800,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(PhRegular.lightning,
                              size: 16,
                              color: _autoPost
                                  ? Nocturne.accent300
                                  : Nocturne.neutral500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _type == 'income'
                                  ? 'Auto-credit to balance on ${_V3RecurringSheetState._daySuffix(_dayOfMonth)} of each month'
                                  : 'Auto-record expense on ${_V3RecurringSheetState._daySuffix(_dayOfMonth)} of each month',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _autoPost
                                    ? Nocturne.text
                                    : Nocturne.neutral400,
                              ),
                            ),
                          ),
                          _MiniToggle(on: _autoPost),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Calculator Display attached directly to keypad
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Nocturne.bg,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Text('₹',
                            style: TextStyle(
                                fontSize: 20, color: Nocturne.neutral500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _expression.isEmpty ? '0' : _expression,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: _type == 'income'
                                  ? NocturneSemantic.income
                                  : Nocturne.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                        if (CalcEngine.hasOperator(_expression) &&
                            _value > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Nocturne.accent900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '= ₹${CalcEngine.format(_value)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.accent200),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 4-column keypad
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.85,
                    children: [
                      for (final k in keys)
                        _Key(label: k, onTap: () => _press(k)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final bool on;
  const _MiniToggle({required this.on});

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 20,
        decoration: BoxDecoration(
          color: on ? Nocturne.accent600 : Nocturne.neutral800,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: on ? Nocturne.accent100 : Nocturne.neutral500,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOp = ['+', '-', '×', '÷', '='].contains(label);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOp ? Nocturne.neutral800 : Nocturne.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isOp ? Nocturne.accent600.withValues(alpha: 0.3) : Nocturne.neutral900,
            width: 1,
          ),
        ),
        child: label == '<'
            ? const Icon(PhRegular.backspace, size: 19, color: Nocturne.text)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isOp ? FontWeight.w600 : FontWeight.w500,
                  color: isOp ? Nocturne.accent200 : Nocturne.text,
                ),
              ),
      ),
    );
  }
}
