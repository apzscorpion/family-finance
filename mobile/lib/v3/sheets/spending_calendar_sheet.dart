import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import 'v3_sheets.dart';

/// Modal bottom sheet showing a full monthly spending calendar heatmap.
/// Each day is colored proportionally according to the day's total expense amount.
class SpendingCalendarSheet extends StatefulWidget {
  const SpendingCalendarSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => const SpendingCalendarSheet(),
    );
  }

  @override
  State<SpendingCalendarSheet> createState() => _SpendingCalendarSheetState();
}

class _SpendingCalendarSheetState extends State<SpendingCalendarSheet> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final maxH = MediaQuery.of(context).size.height * 0.90;

    // Filter transactions for this month
    final monthTxns = s.txns.where((t) {
      if (!t.isExpense) return false;
      if (!s.isFamily && t.userId != s.scope) return false;
      return t.occurredAt.year == _currentMonth.year &&
          t.occurredAt.month == _currentMonth.month;
    }).toList();

    // Map spend per day of month
    final Map<int, double> dayTotals = {};
    for (final t in monthTxns) {
      dayTotals[t.occurredAt.day] = (dayTotals[t.occurredAt.day] ?? 0) + t.amount;
    }

    final maxSpend = dayTotals.values.fold<double>(0.0, math.max);
    final monthTotal = dayTotals.values.fold<double>(0.0, (a, b) => a + b);

    // Days in current month
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday % 7; // Sunday = 0

    // Transactions for selected date
    final selectedTxns = _selectedDate == null
        ? <TxnRow>[]
        : s.txns.where((t) {
            if (!t.isExpense) return false;
            if (!s.isFamily && t.userId != s.scope) return false;
            return t.occurredAt.year == _selectedDate!.year &&
                t.occurredAt.month == _selectedDate!.month &&
                t.occurredAt.day == _selectedDate!.day;
          }).toList();

    final selectedTotal = _selectedDate == null
        ? 0.0
        : (dayTotals[_selectedDate!.day] ?? 0.0);

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.palette.edge, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sheet pill handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header with Month Navigation
          Row(
            children: [
              IconButton(
                icon: Icon(PhRegular.caretLeft, size: 20, color: Nocturne.palette.text),
                onPressed: _prevMonth,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_currentMonth),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.palette.text,
                      ),
                    ),
                    Text(
                      'Total: ${V3Design.inr(monthTotal)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Nocturne.palette.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(PhRegular.caretRight, size: 20, color: Nocturne.palette.text),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('S'),
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),

          // Calendar Grid Heatmap
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final day = index - firstWeekday + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final spend = dayTotals[day] ?? 0.0;
              final fraction = maxSpend <= 0 ? 0.0 : (spend / maxSpend).clamp(0.0, 1.0);

              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;

              final isToday = DateTime.now().year == date.year &&
                  DateTime.now().month == date.month &&
                  DateTime.now().day == date.day;

              Color cellColor = Nocturne.palette.bg;
              if (spend > 0) {
                if (fraction > 0.75) {
                  cellColor = const Color(0xFFDC2626); // High spend (red)
                } else if (fraction > 0.40) {
                  cellColor = const Color(0xFFF59E0B); // Medium spend (amber)
                } else {
                  cellColor = Nocturne.palette.tintEdge; // Normal spend (purple)
                }
              }

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : (isToday ? Nocturne.palette.accentMuted : Nocturne.palette.edge),
                      width: isSelected ? 2 : (isToday ? 1.5 : 0.8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                        color: spend > 0 ? Colors.white : Nocturne.palette.muted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // Selected Day Summary
          if (_selectedDate != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, d MMM').format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.palette.text,
                  ),
                ),
                Text(
                  selectedTotal > 0 ? V3Design.inr(selectedTotal) : 'No expenses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedTotal > 0 ? Nocturne.palette.text : Nocturne.palette.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // List of transactions for selected date
            Expanded(
              child: selectedTxns.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses recorded on this day',
                        style: TextStyle(fontSize: 13, color: Nocturne.palette.muted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: selectedTxns.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final txn = selectedTxns[i];
                        final cat = s.catStyle(txn.categoryKey);
                        return GestureDetector(
                          onTap: () {
                            V3Sheets.openDetail(context, txn);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Nocturne.palette.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Nocturne.palette.edge, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cat.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(cat.icon, size: 16, color: cat.color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txn.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Nocturne.palette.text,
                                        ),
                                      ),
                                      Text(
                                        cat.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Nocturne.palette.subtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  V3Design.inr(txn.amount),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Nocturne.palette.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Nocturne.palette.muted,
        ),
      ),
    );
  }
}

