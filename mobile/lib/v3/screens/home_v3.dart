import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_donut.dart';
import '../widgets/v3_motion.dart';
import '../widgets/prayer_card.dart';
import '../widgets/v3_primitives.dart';

/// Home, per `Family Spend Tracker v3.dc.html`.
///
/// Section order and spacing follow the design: header, scope chips, hero card,
/// quick actions, money sources, Needs you, Where it went, Budgets, Coming up,
/// Who spent, Recent.
class HomeV3 extends StatelessWidget {
  const HomeV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Container(
      decoration: const BoxDecoration(
        // body{background:radial-gradient(70% 55% at 50% 0%,#1f2236,var(--color-bg))}
        gradient: RadialGradient(
          center: Alignment(0, -1),
          radius: 1.1,
          colors: [Color(0xFF1F2236), Nocturne.bg],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: s.refresh,
        color: Nocturne.accent300,
        backgroundColor: Nocturne.surface,
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 112),
          children: [
            const _Header(),
            const SizedBox(height: 12),
            const _ScopeChips(),
            const SizedBox(height: 14),
            const _HeroCard(),
            // Renders nothing unless prayer times are on and set to show here.
            const SizedBox(height: 14),
            PrayerCard(
              onTap: () => context.read<V3Nav>().goPage(V3Page.prayer),
            ),
            const SizedBox(height: 4),
            const _QuickActions(),
            if (s.sources.isNotEmpty) ...[
              V3SectionHeader(
                title: 'Money sources',
                meta: 'Tap to filter · ${s.periodLabel}',
              ),
              const _MoneySources(),
            ],
            if (s.attentionCount > 0) ...[
              V3SectionHeader(
                title: 'Needs you',
                badge: _CountBadge(s.attentionCount),
              ),
              const _NeedsYou(),
            ],
            V3SectionHeader(
              title: 'Where it went',
              actionLabel: s.chartStyle == 'donut' ? 'Bars' : 'Donut',
              onAction: () =>
                  s.setChartStyle(s.chartStyle == 'donut' ? 'bars' : 'donut'),
            ),
            const _WhereItWent(),
            if (s.budgetRows.isNotEmpty) ...[
              V3SectionHeader(
                title: 'Budgets',
                meta: 'Monthly · alert at ${s.threshold}%',
              ),
              const _Budgets(),
            ],
            if (s.recurring.isNotEmpty) ...[
              V3SectionHeader(
                title: 'Coming up',
                meta: 'Recurring',
                actionLabel: 'Manage',
                onAction: () => V3Sheets.openRecurring(context),
              ),
              const _ComingUp(),
            ] else ...[
              V3SectionHeader(
                title: 'Coming up',
                meta: 'Recurring',
                actionLabel: '+ Add rule',
                onAction: () => V3Sheets.openRecurring(context),
              ),
              const _EmptyRecurringBanner(),
            ],
            if (s.isFamily && s.byMember.isNotEmpty) ...[
              V3SectionHeader(
                title: 'Who spent',
                actionLabel: 'Members',
                onAction: () => context.read<V3Nav>().goTab(3),
              ),
              const _WhoSpent(),
            ],
            V3SectionHeader(
              title: 'Recent',
              actionLabel: 'See all',
              onAction: () => context.read<V3Nav>().goTab(1),
            ),
            const _Recent(),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: Nocturne.accent900,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('$count',
            style: const TextStyle(fontSize: 11, color: Nocturne.accent200)),
      );
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final unreadDm = context.watch<ChatController?>()?.totalUnread ?? 0;
    final member = s.scopeMember;
    final greetingName = s.me?.name ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => V3Sheets.openScope(context),
              child: Row(
                children: [
                  V3Avatar(
                    initial: member?.initial ?? '',
                    color: member?.color ?? Nocturne.accent700,
                    icon: s.isFamily ? PhRegular.users : null,
                    size: 40,
                    fontSize: 15,
                    ringColor: Nocturne.accent700,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          greetingName.isEmpty
                              ? 'Welcome'
                              : 'Good morning, $greetingName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Nocturne.neutral500),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.scopeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.text),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(PhBold.caretDown,
                                size: 12, color: Nocturne.neutral500),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: s.hidden ? PhRegular.eyeSlash : PhRegular.eye,
            onTap: s.toggleHidden,
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: PhRegular.envelopeSimple,
            onTap: () => context.read<V3Nav>().openChat(),
            showDot: unreadDm > 0,
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: PhRegular.bell,
            onTap: () => context.read<V3Nav>().goPage(V3Page.notifications),
            showDot: s.notifBadge > 0,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Nocturne.neutral800, width: 1),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: Nocturne.neutral300),
            if (showDot)
              Positioned(
                top: 0,
                right: 1,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Nocturne.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Nocturne.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Nocturne.mix(Nocturne.accent, 80),
                          blurRadius: 8),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Scope chips ─────────────────────────────────────────────────────────────

class _ScopeChips extends StatelessWidget {
  const _ScopeChips();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final active = s.members.where((m) => m.isActive).toList();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // The household view is deliberately not a chip here: everything a
          // member adds is their own, so the strip offers people, not the
          // family. The family total is still available from the "View
          // finances for" sheet and on the Family tab.
          for (final m in active) ...[
            if (m != active.first) const SizedBox(width: 6),
            V3Chip(
              label: m.userId == s.myId ? 'Me' : m.name,
              selected: s.scope == m.userId,
              onTap: () => s.setScope(m.userId),
              leading: V3Avatar(
                  initial: m.initial, color: m.color, size: 26, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Hero card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final spent = s.totalSpent;
    final limit = s.budgetLimit;
    final remaining = limit - spent;
    final pct = (s.budgetFraction * 100).round();
    final source = s.sourceById(s.srcFilter);

    // The design layers two backgrounds and a hairline:
    //
    //   background:
    //     radial-gradient(90% 80% at 100% 0%,
    //       color-mix(in oklch,var(--color-accent) 26%,transparent),
    //       transparent 60%),
    //     linear-gradient(170deg,#262840,var(--color-surface) 75%)
    //
    //   plus a 1px top edge:
    //     linear-gradient(90deg,transparent,var(--color-accent-500),transparent)
    //
    // Flutter takes one gradient per decoration, so the radial sits in an
    // overlay above the linear base and below the content.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x61000000), blurRadius: 44, offset: Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // base: linear-gradient(170deg, #262840, surface 75%)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.17, -1),
                    end: Alignment(0.17, 1),
                    colors: [Color(0xFF262840), Nocturne.surface],
                    stops: [0, 0.75],
                  ),
                ),
              ),
            ),
            // accent bloom from the top-right corner
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.15,
                    colors: [
                      Nocturne.mix(Nocturne.accent, 26),
                      Nocturne.accent.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
            // the bright hairline along the top edge
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00968AE0),
                        Nocturne.accent500,
                        Color(0x00968AE0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Nocturne.accent800, width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => V3Sheets.openSources(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.only(left: 8, right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x47000000),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Nocturne.accent700, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(source?.design.icon ?? PhRegular.wallet,
                            size: 14, color: Nocturne.accent300),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            source?.name ?? 'All sources',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Nocturne.accent100),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(PhBold.caretDown,
                            size: 10, color: Nocturne.neutral400),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              V3Segmented(
                labels: const ['7D', '30D'],
                selected: s.period == '7d' ? 0 : 1,
                onChanged: (i) => s.setPeriod(i == 0 ? '7d' : '30d'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.isFamily ? 'FAMILY SPENT' : '${s.scopeName.toUpperCase()} SPENT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Nocturne.accent300, letterSpacing: 0.88),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: V3Num(
                        s.money(spent),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.text,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      source != null ? '${source.name.toUpperCase()} BALANCE' : 'TOTAL BALANCE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: s.balance >= 0 ? NocturneSemantic.income : NocturneSemantic.expense,
                        letterSpacing: 0.88,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: V3Num(
                        s.money(s.balance),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: s.balance >= 0 ? NocturneSemantic.income : NocturneSemantic.expense,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (limit > 0)
            Row(
              children: [
                Icon(
                  remaining >= 0 ? PhRegular.trendDown : PhRegular.trendUp,
                  size: 13,
                  color: remaining >= 0
                      ? NocturneSemantic.income
                      : NocturneSemantic.expense,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    remaining >= 0
                        ? '${s.moneyShort(remaining)} left of ${V3Design.inrShort(limit)}'
                        : '${s.moneyShort(remaining.abs())} over budget',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining >= 0
                          ? NocturneSemantic.income
                          : NocturneSemantic.expense,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text('No budgets set yet',
                style: TextStyle(fontSize: 12, color: Nocturne.neutral500)),
          const SizedBox(height: 16),
          V3ProgressBar(
            fraction: s.budgetFraction,
            fill:
                s.overThreshold ? NocturneSemantic.warning : Nocturne.accent500,
            threshold: limit > 0 ? s.threshold / 100 : null,
            track: const Color(0x52000000),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  limit <= 0
                      ? 'Set a budget to track this'
                      : s.overThreshold
                          ? 'Past the ${s.threshold}% alert mark'
                          : 'On track for ${s.periodLabel.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: s.overThreshold
                        ? NocturneSemantic.warning
                        : Nocturne.neutral500,
                  ),
                ),
              ),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(
                  label: 'Income',
                  value: s.moneyShort(s.totalIncome),
                  color: NocturneSemantic.income),
              const SizedBox(width: 8),
              _HeroStat(
                  label: 'Net saved',
                  value: s.moneyShort(s.totalIncome - spent),
                  color: (s.totalIncome - spent) >= 0
                      ? NocturneSemantic.income
                      : NocturneSemantic.expense),
              const SizedBox(width: 8),
              _HeroStat(
                  label: 'Per day',
                  value: s.moneyShort(spent / s.maxDays),
                  color: Nocturne.text),
            ],
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x3D000000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: Nocturne.neutral500)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: V3Num(
                value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<V3Nav>();
    final actions = <(IconData, String, Color, VoidCallback)>[
      (PhRegular.plus, 'Add', Nocturne.accent, () => V3Sheets.openAdd(context)),
      (
        PhRegular.bellRinging,
        'Detected',
        const Color(0xFF67B5E1),
        () => nav.goPage(V3Page.detected)
      ),
      (
        PhRegular.creditCard,
        'Cards',
        const Color(0xFFA297EB),
        () => nav.goPage(V3Page.cards)
      ),
      (
        PhRegular.notePencil,
        'Notes',
        const Color(0xFF64C897),
        () => nav.goPage(V3Page.notes)
      ),
      (
        PhRegular.envelopeSimple,
        'Chat',
        const Color(0xFFDE82B7),
        () => nav.openChat()
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: V3Press(
                onTap: a.$4,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // The design tints the tile and lifts it with a glow
                        // in the same hue, rather than a flat wash.
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Nocturne.mix(a.$3, 28),
                            Nocturne.mix(a.$3, 12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: Nocturne.mix(a.$3, 26),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(a.$1, size: 22, color: a.$3),
                    ),
                    const SizedBox(height: 7),
                    Text(a.$2,
                        style: const TextStyle(
                            fontSize: 11.5, color: Nocturne.neutral300)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Money sources ───────────────────────────────────────────────────────────

class _MoneySources extends StatelessWidget {
  const _MoneySources();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return SizedBox(
      // Content measures 109pt inside 12pt padding plus the 1pt border.
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: s.sources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final src = s.sources[i];
          final t = s.sourceTotals(src.id);
          final left = src.openingBalance + t.inAmt - t.outAmt;
          final denom = src.openingBalance + t.inAmt;
          final frac = denom <= 0 ? 0.0 : (t.outAmt / denom).clamp(0.0, 1.0);
          final selected = s.srcFilter == src.id;
          final design = src.design;

          return GestureDetector(
            onTap: () => s.setSource(src.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 138,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Nocturne.accent900 : Nocturne.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Nocturne.accent600 : Nocturne.neutral900,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      V3IconTile(
                          icon: design.icon,
                          color: design.color,
                          size: 30,
                          radius: 10,
                          iconSize: 16),
                      if (selected)
                        const Icon(PhFill.checkCircle,
                            size: 16, color: Nocturne.accent300),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(src.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Nocturne.neutral400)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: V3Num(
                      s.moneyShort(left),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: left >= 0
                            ? Nocturne.text
                            : NocturneSemantic.expense,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  V3ProgressBar(
                      fraction: frac,
                      fill: design.color,
                      height: 4,
                      track: Nocturne.neutral900),
                  const SizedBox(height: 6),
                  Text(
                    'In ${s.moneyShort(t.inAmt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: Nocturne.neutral500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Needs you ───────────────────────────────────────────────────────────────

class _AttentionRow {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final String cta;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.cta,
    required this.onTap,
  });
}

class _NeedsYou extends StatelessWidget {
  const _NeedsYou();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    final rows = <_AttentionRow>[
      for (final a in s.approvals)
        _AttentionRow(
          icon: a.kind == 'edit'
              ? PhRegular.pencilSimple
              : a.kind == 'delete'
                  ? PhRegular.trash
                  : PhRegular.plus,
          color: NocturneSemantic.warning,
          title: '${_titleCase(a.kind)} request from '
              '${s.memberName(a.requestedBy)}',
          sub: a.reason ?? 'Tap to review',
          cta: 'Review',
          onTap: () => V3Sheets.openApproval(context, a),
        ),
      for (final d in s.myDebts)
        _AttentionRow(
          icon: PhRegular.handCoins,
          color: Nocturne.accent300,
          title: d.toUser == s.myId
              ? '${s.memberName(d.fromUser)} owes you ${V3Design.inr(d.amount)}'
              : 'You owe ${s.memberName(d.toUser)} ${V3Design.inr(d.amount)}',
          sub: d.note ?? 'Split expense',
          cta: 'Settle',
          onTap: () => s.settleDebt(d.id),
        ),
    ];

    return V3Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            V3Rise(
              index: i,
              child: GestureDetector(
              onTap: rows[i].onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    V3IconTile(
                        icon: rows[i].icon,
                        color: rows[i].color,
                        size: 36,
                        radius: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(rows[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Nocturne.text)),
                          Text(rows[i].sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Nocturne.neutral500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: rows[i].color, width: 1),
                      ),
                      child: Text(rows[i].cta,
                          style:
                              TextStyle(fontSize: 11.5, color: rows[i].color)),
                    ),
                  ],
                ),
              ),
            ),
            ),
            if (i < rows.length - 1) const V3RowDivider(),
          ],
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Where it went ───────────────────────────────────────────────────────────

class _WhereItWent extends StatelessWidget {
  const _WhereItWent();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final cats = s.byCategory;
    final total = s.totalSpent;

    if (cats.isEmpty) {
      return const V3Panel(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No expenses in selected period',
                style: TextStyle(fontSize: 13, color: Nocturne.neutral500)),
          ),
        ),
      );
    }

    if (s.chartStyle == 'bars') {
      return V3Panel(
        child: Column(
          children: [
            for (var i = 0; i < cats.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CatBar(entry: cats[i], total: total),
            ],
          ],
        ),
      );
    }

    final top = cats.take(5).toList();
    return V3Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          V3Donut(
            size: 128,
            thickness: 15,
            slices: [
              for (final e in cats)
                V3DonutSlice(
                  label: s.catStyle(e.key).name,
                  value: e.value,
                  color: s.catStyle(e.key).color,
                ),
            ],
            center: V3DonutCenter(
              amount: s.moneyShort(total),
              categoryCount: cats.length,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in top)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: s.catStyle(e.key).color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.catStyle(e.key).name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: Nocturne.neutral300),
                          ),
                        ),
                        V3Num(
                          '${total <= 0 ? 0 : (e.value / total * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 12.5, color: Nocturne.neutral500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatBar extends StatelessWidget {
  final MapEntry<String, double> entry;
  final double total;

  const _CatBar({required this.entry, required this.total});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final cat = s.catStyle(entry.key);
    final pct = total <= 0 ? 0.0 : entry.value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 16, color: cat.color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13, color: Nocturne.text))),
            V3Num(s.money(entry.value),
                style: const TextStyle(fontSize: 13, color: Nocturne.text)),
            SizedBox(
              width: 34,
              child: V3Num('${(pct * 100).round()}%',
                  align: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, color: Nocturne.neutral500)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        V3ProgressBar(fraction: pct, fill: cat.color, height: 5),
      ],
    );
  }
}

// ── Budgets ─────────────────────────────────────────────────────────────────

class _Budgets extends StatelessWidget {
  const _Budgets();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final rows = s.budgetRows;

    return V3Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _BudgetRow(row: rows[i]),
            if (i < rows.length - 1) const V3RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final ({CategoryRow cat, double limit, double spent, int threshold}) row;

  const _BudgetRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final style = s.catStyle(row.cat.key);
    final frac = row.limit <= 0 ? 0.0 : (row.spent / row.limit).clamp(0.0, 1.0);
    final over = row.spent > row.limit;
    final warn = !over && frac * 100 >= row.threshold;
    final fill = over
        ? NocturneSemantic.expense
        : warn
            ? NocturneSemantic.warning
            : style.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 17, color: style.color),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(row.cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Nocturne.text))),
              V3Num(s.money(row.spent),
                  style: const TextStyle(fontSize: 13, color: Nocturne.text)),
              V3Num(' / ${V3Design.inrShort(row.limit)}',
                  style: const TextStyle(
                      fontSize: 13, color: Nocturne.neutral500)),
            ],
          ),
          const SizedBox(height: 8),
          V3ProgressBar(fraction: frac, fill: fill, height: 5),
          const SizedBox(height: 6),
          Text(
            over
                ? '${V3Design.inrShort(row.spent - row.limit)} over'
                : '${V3Design.inrShort(row.limit - row.spent)} left',
            style: TextStyle(
              fontSize: 11,
              color: over
                  ? NocturneSemantic.expense
                  : warn
                      ? NocturneSemantic.warning
                      : Nocturne.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coming up ───────────────────────────────────────────────────────────────

class _ComingUp extends StatelessWidget {
  const _ComingUp();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final unownedCount =
        s.recurring.where((r) => r.ownerUserId == null).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unownedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GestureDetector(
              onTap: () => V3Sheets.openRecurring(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Nocturne.mix(NocturneSemantic.warning, 12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Nocturne.mix(NocturneSemantic.warning, 35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(PhRegular.warning,
                        size: 15, color: NocturneSemantic.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unownedCount == 1
                            ? '1 recurring rule has no owner — tap to assign'
                            : '$unownedCount recurring rules have no owner — tap to assign',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Nocturne.neutral200,
                        ),
                      ),
                    ),
                    const Icon(PhBold.caretRight,
                        size: 12, color: NocturneSemantic.warning),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: s.recurring.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = s.recurring[i];
              final style = s.catStyle(r.categoryKey);
              final days = r.dueInDays;
              final soon = days <= 3;

              return GestureDetector(
                onTap: () => V3Sheets.openRecurring(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 154,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Nocturne.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Nocturne.neutral900, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          V3IconTile(
                              icon: style.icon,
                              color: style.color,
                              size: 32,
                              radius: 10,
                              iconSize: 16),
                          Text(
                            days <= 0 ? 'Due' : 'in ${days}d',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  soon ? FontWeight.w600 : FontWeight.w400,
                              color: soon
                                  ? NocturneSemantic.warning
                                  : Nocturne.neutral500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Nocturne.text)),
                      V3Num(
                        '${r.isIncome ? '+' : ''}${s.money(r.amount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: r.isIncome
                              ? NocturneSemantic.income
                              : Nocturne.text,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => s.addTransaction(
                          title: r.title,
                          amount: r.amount,
                          type: r.type,
                          categoryKey: r.categoryKey,
                          sourceId: r.sourceId,
                          forUserId: r.ownerUserId,
                          paidBy: r.ownerUserId,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 30,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: r.isIncome
                                ? Nocturne.mix(NocturneSemantic.income, 14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: r.isIncome
                                    ? NocturneSemantic.income
                                    : Nocturne.accent700,
                                width: 1),
                          ),
                          child: Text(
                            r.isIncome ? 'Record credit' : 'Mark paid',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: r.isIncome
                                  ? NocturneSemantic.income
                                  : Nocturne.accent200,
                            ),
                          ),
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
    );
  }
}

class _EmptyRecurringBanner extends StatelessWidget {
  const _EmptyRecurringBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nocturne.neutral800, width: 1),
      ),
      child: Row(
        children: [
          const V3IconTile(
            icon: PhRegular.arrowsClockwise,
            color: Nocturne.accent400,
            size: 38,
            radius: 12,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Recurring transactions',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Nocturne.text)),
                SizedBox(height: 2),
                Text(
                  'Track monthly salary, rent, or EMIs to record on a set date.',
                  style: TextStyle(fontSize: 11.5, color: Nocturne.neutral500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => V3Sheets.openRecurring(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Nocturne.neutral700, width: 1),
              ),
              child: const Text('Set up',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.accent200)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Who spent ───────────────────────────────────────────────────────────────

class _WhoSpent extends StatelessWidget {
  const _WhoSpent();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final shares = s.byMember;
    final total = shares.fold<double>(0, (a, b) => a + b.value);
    if (shares.isEmpty) return const SizedBox.shrink();

    return V3Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `display:flex;gap:3px;height:10px`
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  for (var i = 0; i < shares.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: ((shares[i].value / total) * 1000)
                          .round()
                          .clamp(1, 1000),
                      child: ColoredBox(color: shares[i].key.color),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final e in shares)
            GestureDetector(
              onTap: () => s.setScope(e.key.userId),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    V3Avatar(
                        initial: e.key.initial,
                        color: e.key.color,
                        size: 28,
                        fontSize: 11.5),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13,
                              color: Nocturne.text,
                              fontFamily: Nocturne.fontFamily),
                          children: [
                            TextSpan(text: e.key.name),
                            if (e.key.relationship.isNotEmpty)
                              TextSpan(
                                text: ' · ${e.key.relationship}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Nocturne.neutral500),
                              ),
                          ],
                        ),
                      ),
                    ),
                    V3Num(s.money(e.value),
                        style:
                            const TextStyle(fontSize: 13, color: Nocturne.text)),
                    SizedBox(
                      width: 34,
                      child: V3Num(
                        '${total <= 0 ? 0 : (e.value / total * 100).round()}%',
                        align: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, color: Nocturne.neutral500),
                      ),
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

// ── Recent ──────────────────────────────────────────────────────────────────

class _Recent extends StatelessWidget {
  const _Recent();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final items = s.recent;

    if (items.isEmpty) {
      return const V3Panel(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(PhRegular.receiptX, size: 32, color: Nocturne.neutral600),
              SizedBox(height: 10),
              Text('Nothing here yet',
                  style: TextStyle(fontSize: 14, color: Nocturne.neutral300)),
              SizedBox(height: 4),
              Text('Add your first entry with the + button',
                  style: TextStyle(fontSize: 12, color: Nocturne.neutral500)),
            ],
          ),
        ),
      );
    }

    return V3Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            V3TxnRow(txn: items[i]),
            if (i < items.length - 1) const V3RowDivider(),
          ],
        ],
      ),
    );
  }
}

/// A transaction row. Shared by Home's Recent list and the Activity screen.
class V3TxnRow extends StatelessWidget {
  final TxnRow txn;
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const V3TxnRow({
    super.key,
    required this.txn,
    this.selectable = false,
    this.selected = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final style = s.catStyle(txn.categoryKey);
    final who = s.memberById(txn.userId);
    final isImported = txn.origin == 'import';

    final originIcon = switch (txn.origin) {
      'manual' => PhRegular.pencilSimple,
      'import' => PhRegular.downloadSimple,
      _ => PhFill.bellRinging,
    };

    return GestureDetector(
      onTap: selectable
          ? onToggleSelect
          : () => V3Sheets.openDetail(context, txn),
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: selectable && selected
            ? const EdgeInsets.symmetric(vertical: 2)
            : EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: selectable && selected ? 6 : 0,
        ),
        decoration: selectable && selected
            ? BoxDecoration(
                color: Nocturne.mix(Nocturne.accent, 12),
                borderRadius: BorderRadius.circular(11),
              )
            : null,
        child: Row(
          children: [
            if (selectable) ...[
              Icon(
                selected ? PhFill.checkCircle : PhRegular.circle,
                size: 20,
                color: selected ? Nocturne.accent : Nocturne.neutral500,
              ),
              const SizedBox(width: 10),
            ],
            V3IconTile(icon: style.icon, color: style.color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(txn.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, color: Nocturne.text)),
                      ),
                      if (isImported) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Nocturne.accent900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Imported',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Nocturne.accent200,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        originIcon,
                        size: 11,
                        color: txn.origin == 'manual'
                            ? Nocturne.neutral600
                            : Nocturne.accent300,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${who?.name ?? ''} · ${txn.method} · ${txn.timeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Nocturne.neutral500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                V3Num(
                  '${txn.isExpense ? '' : '+'}${s.money(txn.amount)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color:
                        txn.isExpense ? Nocturne.text : NocturneSemantic.income,
                  ),
                ),
                if (txn.splitWith.isNotEmpty)
                  const Text('Split',
                      style:
                          TextStyle(fontSize: 10.5, color: Nocturne.accent300)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
