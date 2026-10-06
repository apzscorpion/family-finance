import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Insights: a daily spend chart with an average line, KPI tiles, and the
/// category breakdown.
class InsightsV3 extends StatefulWidget {
  const InsightsV3({super.key});

  @override
  State<InsightsV3> createState() => _InsightsV3State();
}

class _InsightsV3State extends State<InsightsV3> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final days = s.maxDays;

    // Spend per day, index 0 = today.
    final perDay = List<double>.filled(days, 0);
    for (final t in s.scoped.where((t) => t.isExpense)) {
      final i = t.ageInDays;
      if (i >= 0 && i < days) perDay[i] += t.amount;
    }
    final maxDay = perDay.fold<double>(0, math.max);
    final total = perDay.fold<double>(0, (a, b) => a + b);
    final avg = days == 0 ? 0.0 : total / days;

    final selected = _selectedDay;
    final tipAmount = selected == null ? total : perDay[selected];
    final tipLabel = selected == null
        ? 'Spent · ${s.periodLabel.toLowerCase()}'
        : _dayLabel(selected);

    // Same window immediately before, for the change figure.
    var prev = 0.0;
    for (final t in s.txns.where((t) => t.isExpense)) {
      if (!s.isFamily && t.userId != s.scope) continue;
      final a = t.ageInDays;
      if (a >= days && a < days * 2) prev += t.amount;
    }
    final delta = prev <= 0 ? 0.0 : ((total - prev) / prev) * 100;

    final cats = s.byCategory;
    final biggest = s.scoped.where((t) => t.isExpense).fold<double>(
        0, (a, t) => math.max(a, t.amount));

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: Nocturne.accent300,
      backgroundColor: Nocturne.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Insights',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text)),
                      GestureDetector(
                        onTap: () => V3Sheets.openScope(context),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(s.scopeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Nocturne.neutral500)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(PhBold.caretDown,
                                size: 10, color: Nocturne.neutral500),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                V3Segmented(
                  labels: const ['7D', '30D'],
                  selected: s.period == '7d' ? 0 : 1,
                  ground: Nocturne.surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  onChanged: (i) {
                    setState(() => _selectedDay = null);
                    s.setPeriod(i == 0 ? '7d' : '30d');
                  },
                ),
              ],
            ),
          ),
          // Chart
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Nocturne.neutral900, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipLabel,
                    style: const TextStyle(
                        fontSize: 11.5, color: Nocturne.neutral500)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    V3Num(s.money(tipAmount),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text)),
                    const SizedBox(width: 8),
                    if (selected == null && prev > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${delta >= 0 ? '+' : ''}${delta.round()}% vs prev',
                          style: TextStyle(
                            fontSize: 12,
                            color: delta > 0
                                ? NocturneSemantic.expense
                                : NocturneSemantic.income,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: LayoutBuilder(builder: (context, c) {
                    final gap = days > 14 ? 2.0 : 4.0;
                    final avgFrac = maxDay <= 0 ? 0.0 : avg / maxDay;
                    return Stack(
                      children: [
                        // The dashed average line.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: c.maxHeight * avgFrac,
                          child: const _DashedLine(),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = days - 1; i >= 0; i--) ...[
                              if (i < days - 1) SizedBox(width: gap),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() =>
                                      _selectedDay =
                                          _selectedDay == i ? null : i),
                                  behavior: HitTestBehavior.opaque,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      height: maxDay <= 0
                                          ? 2
                                          : math.max(
                                              2,
                                              c.maxHeight *
                                                  (perDay[i] / maxDay)),
                                      decoration: BoxDecoration(
                                        color: _selectedDay == i
                                            ? Nocturne.accent300
                                            : perDay[i] > avg
                                                ? Nocturne.accent500
                                                : Nocturne.accent800,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(3),
                                          bottom: Radius.circular(1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dayLabel(days - 1),
                        style: const TextStyle(
                            fontSize: 10.5, color: Nocturne.neutral500)),
                    Text('avg ${V3Design.inrShort(avg)}/day',
                        style: const TextStyle(
                            fontSize: 10.5, color: Nocturne.neutral500)),
                    const Text('Today',
                        style: TextStyle(
                            fontSize: 10.5, color: Nocturne.neutral500)),
                  ],
                ),
              ],
            ),
          ),
          // KPIs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Kpi(
                    icon: PhRegular.trendUp,
                    label: 'Busiest day',
                    value: maxDay <= 0
                        ? '—'
                        : _dayLabel(perDay.indexOf(maxDay)),
                    sub: maxDay <= 0 ? '' : V3Design.inrShort(maxDay),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Kpi(
                    icon: PhRegular.target,
                    label: 'Biggest expense',
                    value: biggest <= 0 ? '—' : V3Design.inrShort(biggest),
                    sub: '',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Kpi(
                    icon: PhRegular.calendar,
                    label: 'Daily average',
                    value: V3Design.inrShort(avg),
                    sub: s.periodLabel.toLowerCase(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Kpi(
                    icon: PhRegular.chartDonut,
                    label: 'Categories used',
                    value: '${cats.length}',
                    sub: cats.isEmpty
                        ? ''
                        : 'top: ${s.catStyle(cats.first.key).name}',
                  ),
                ),
              ],
            ),
          ),
          if (cats.isNotEmpty) ...[
            const V3SectionHeader(title: 'By category'),
            V3Panel(
              child: Column(
                children: [
                  for (var i = 0; i < cats.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final c = s.catStyle(cats[i].key);
                      final pct =
                          total <= 0 ? 0.0 : cats[i].value / s.totalSpent;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(c.icon, size: 16, color: c.color),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Nocturne.text))),
                              V3Num(s.money(cats[i].value),
                                  style: const TextStyle(
                                      fontSize: 13, color: Nocturne.text)),
                              SizedBox(
                                width: 40,
                                child: V3Num('${(pct * 100).round()}%',
                                    align: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Nocturne.neutral500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          V3ProgressBar(
                              fraction: pct, fill: c.color, height: 5),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                children: [
                  Icon(PhRegular.chartBar,
                      size: 38, color: Nocturne.neutral600),
                  SizedBox(height: 8),
                  Text('Nothing to chart yet',
                      style: TextStyle(
                          fontSize: 14, color: Nocturne.neutral300)),
                  SizedBox(height: 4),
                  Text('Add a few entries and insights will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5, color: Nocturne.neutral500)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _dayLabel(int daysAgo) {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// `border-top:1px dashed var(--color-neutral-600)`
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          const dash = 4.0, gap = 4.0;
          final count = (c.maxWidth / (dash + gap)).floor();
          return Row(
            children: List.generate(
              count,
              (_) => Container(
                width: dash,
                height: 1,
                margin: const EdgeInsets.only(right: gap),
                color: Nocturne.neutral600,
              ),
            ),
          );
        },
      );
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nocturne.neutral900, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Nocturne.neutral500),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Nocturne.neutral500)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: V3Num(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text)),
            ),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: Nocturne.neutral500)),
          ],
        ),
      );
}
