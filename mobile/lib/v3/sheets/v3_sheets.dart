import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../screens/sources_manager_v3.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import '../widgets/v3_motion.dart';

/// Bottom sheets, matching the design's single sheet container:
///   `border-radius:28px 28px 0 0; background:var(--color-surface);
///    box-shadow:0 -1px 0 var(--color-neutral-700), 0 -20px 50px rgba(0,0,0,.4);
///    padding:10px 16px 26px; animation:ftUp .3s cubic-bezier(.2,.8,.2,1)`
class V3Sheets {
  V3Sheets._();

  static Future<T?> _show<T>(BuildContext context, Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      // rgba(6,7,14,.64)
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => _SheetShell(child: child),
    );
  }

  static Future<void> openScope(BuildContext context) =>
      _show(context, const V3ScopeSheet());

  static Future<void> openSources(BuildContext context) =>
      _show(context, const V3SourceSheet());

  static Future<void> openAdd(BuildContext context, {TxnRow? edit}) =>
      _show(context, V3AddSheet(edit: edit));

  static Future<void> openDetail(BuildContext context, TxnRow txn) =>
      _show(context, V3DetailSheet(txn: txn));

  static Future<void> openInvite(BuildContext context) =>
      _show(context, const V3InviteSheet());

  static Future<void> openApproval(BuildContext context, ApprovalRow a) =>
      _show(context, V3ApprovalSheet(approval: a));
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 50, offset: Offset(0, -20)),
        ],
        border: Border(top: BorderSide(color: Nocturne.neutral700, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 26 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // the grab handle: 38×4, neutral-700
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Nocturne.neutral700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SheetTitle(this.title, [this.subtitle]);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Nocturne.text)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style:
                    const TextStyle(fontSize: 12, color: Nocturne.neutral500)),
          ],
        ],
      );
}

// ── Scope sheet ─────────────────────────────────────────────────────────────

class V3ScopeSheet extends StatelessWidget {
  const V3ScopeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final members = s.members.where((m) => m.isActive).toList();

    double spentFor(String? userId) => s.txns
        .where((t) =>
            t.isExpense &&
            t.ageInDays < s.maxDays &&
            (userId == null || t.userId == userId))
        .fold(0.0, (a, t) => a + t.amount);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetTitle(
              'View finances for', "Other members' views are read-only"),
          const SizedBox(height: 12),
          _ScopeOption(
            name: s.family?.name ?? 'Family',
            sub: '${members.length} members',
            amount: s.moneyShort(spentFor(null)),
            color: Nocturne.accent700,
            icon: PhRegular.users,
            selected: s.isFamily,
            onTap: () {
              s.setScope('family');
              Navigator.pop(context);
            },
          ),
          for (final m in members) ...[
            const SizedBox(height: 6),
            _ScopeOption(
              name: m.userId == s.myId ? '${m.name} (you)' : m.name,
              sub: [
                if (m.relationship.isNotEmpty) m.relationship,
                _titleCase(m.role),
              ].join(' · '),
              amount: s.moneyShort(spentFor(m.userId)),
              color: m.color,
              initial: m.initial,
              selected: s.scope == m.userId,
              onTap: () {
                s.setScope(m.userId);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  static String _titleCase(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';
}

class _ScopeOption extends StatelessWidget {
  final String name;
  final String sub;
  final String amount;
  final Color color;
  final String? initial;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.name,
    required this.sub,
    required this.amount,
    required this.color,
    this.initial,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Nocturne.accent900 : Nocturne.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Nocturne.accent600 : Nocturne.neutral900,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            V3Avatar(
                initial: initial ?? '',
                color: color,
                icon: icon,
                size: 38,
                fontSize: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 14, color: Nocturne.text)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            V3Num(amount,
                style:
                    const TextStyle(fontSize: 13, color: Nocturne.neutral300)),
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: selected
                  ? const Icon(PhFill.checkCircle,
                      size: 18, color: Nocturne.accent300)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source sheet ────────────────────────────────────────────────────────────

class V3SourceSheet extends StatelessWidget {
  const V3SourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SheetTitle('Money source',
                    'See what came in and what was spent from each · ${s.periodLabel}'),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  SourcesManagerV3.open(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Nocturne.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Nocturne.neutral800, width: 1),
                  ),
                  child: const Icon(PhRegular.slidersHorizontal,
                      size: 16, color: Nocturne.neutral300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SourceOption(
            name: 'All sources',
            left: s.moneyShort(s.balance),
            inText: s.moneyShort(s.totalIncome),
            outText: s.moneyShort(s.totalSpent),
            fraction: s.budgetFraction,
            color: Nocturne.accent500,
            icon: PhRegular.wallet,
            selected: s.srcFilter == null,
            onTap: () {
              s.setSource(s.srcFilter);
              Navigator.pop(context);
            },
          ),
          for (final src in s.sources) ...[
            const SizedBox(height: 6),
            Builder(builder: (_) {
              final t = s.sourceTotals(src.id);
              final denom = src.openingBalance + t.inAmt;
              final frac =
                  denom <= 0 ? 0.0 : (t.outAmt / denom).clamp(0.0, 1.0);
              return _SourceOption(
                name: src.name,
                left: s.moneyShort(src.openingBalance + t.inAmt - t.outAmt),
                inText: s.moneyShort(t.inAmt),
                outText: s.moneyShort(t.outAmt),
                fraction: frac,
                color: src.design.color,
                icon: src.design.icon,
                selected: s.srcFilter == src.id,
                onTap: () {
                  s.setSource(src.id);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String name;
  final String left;
  final String inText;
  final String outText;
  final double fraction;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.name,
    required this.left,
    required this.inText,
    required this.outText,
    required this.fraction,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Nocturne.accent900 : Nocturne.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Nocturne.accent600 : Nocturne.neutral900,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            V3IconTile(icon: icon, color: color, size: 38, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: Nocturne.text)),
                      ),
                      V3Num(left,
                          style: const TextStyle(
                              fontSize: 14, color: Nocturne.text)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  V3ProgressBar(fraction: fraction, fill: color, height: 4),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('In $inText',
                          style: const TextStyle(
                              fontSize: 11, color: Nocturne.neutral500)),
                      Text('Spent $outText',
                          style: const TextStyle(
                              fontSize: 11, color: Nocturne.neutral500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: selected
                  ? const Icon(PhFill.checkCircle,
                      size: 18, color: Nocturne.accent300)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add sheet (with keypad) ─────────────────────────────────────────────────

class V3AddSheet extends StatefulWidget {
  final TxnRow? edit;
  const V3AddSheet({super.key, this.edit});

  @override
  State<V3AddSheet> createState() => _V3AddSheetState();
}

class _V3AddSheetState extends State<V3AddSheet> {
  String _type = 'expense';
  String _amount = '';
  String _catKey = 'groceries';
  String _method = 'UPI';
  String? _sourceId;
  String? _forUser;
  final _note = TextEditingController();
  bool _split = false;
  final Set<String> _splitWith = {};

  /// Who actually paid. Defaults to me.
  String? _paidBy;

  /// When false the payer takes no share — "I paid this entirely for them".
  bool _payerShares = true;
  bool _saving = false;

  static const _methods = ['UPI', 'Cash', 'Card', 'Bank'];

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _type = e.type;
      _amount = e.amount.toStringAsFixed(0);
      _catKey = e.categoryKey;
      _method = e.method;
      _sourceId = e.sourceId;
      _forUser = e.userId;
      _note.text = e.title;
      _splitWith.addAll(e.splitWith);
      _split = _splitWith.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount) ?? 0;

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount += _amount.isEmpty ? '0.' : '.';
      } else {
        if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
        if (_amount.length >= 9) return;
        _amount = (_amount == '0' ? '' : _amount) + k;
      }
    });
  }

  Future<void> _save() async {
    final s = context.read<V3State>();
    if (_value <= 0 || _saving) return;
    setState(() => _saving = true);

    final payer = _paidBy ?? s.myId;

    // Beneficiaries each owe an equal part. The payer is only included when
    // they are actually sharing the cost — "I paid this entirely for her"
    // leaves the payer owing nothing.
    Map<String, double>? shares;
    if (_split && _splitWith.isNotEmpty) {
      final people = <String>{
        ..._splitWith,
        if (_payerShares && payer != null) payer,
      };
      final each = _value / people.length;
      shares = {for (final p in people) p: each};
    }

    final ok = await s.addTransaction(
      title: _note.text.trim(),
      amount: _value,
      type: _type,
      categoryKey: _catKey,
      method: _method,
      sourceId: _sourceId,
      forUserId: _forUser,
      paidBy: payer,
      shares: shares,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save — check your connection'),
            backgroundColor: Nocturne.neutral800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final keys = const [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '<',
    ];
    final catKeys =
        _type == 'expense' ? V3Design.expenseCats : V3Design.incomeCats;
    final members = s.members.where((m) => m.isActive).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.edit == null ? 'Add entry' : 'Edit entry',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text)),
              V3Segmented(
                labels: const ['Expense', 'Income'],
                selected: _type == 'expense' ? 0 : 1,
                ground: Nocturne.bg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onChanged: (i) => setState(() {
                  _type = i == 0 ? 'expense' : 'income';
                  _catKey = i == 0 ? 'groceries' : 'salary';
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: '₹',
                    style: TextStyle(
                        fontSize: 24,
                        color: Nocturne.neutral500,
                        fontFamily: Nocturne.fontFamily),
                  ),
                  TextSpan(
                    text: _amount.isEmpty ? '0' : _amount,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.84,
                      fontFamily: Nocturne.fontFamily,
                      color: _type == 'income'
                          ? NocturneSemantic.income
                          : Nocturne.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                    controller: _note,
                    style: const TextStyle(
                        fontSize: 13.5, color: Nocturne.text),
                    cursorColor: Nocturne.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Merchant or note (optional)',
                      hintStyle: TextStyle(
                          fontSize: 13.5, color: Nocturne.neutral600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 5-up category grid
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.92,
            children: [
              for (final k in catKeys)
                Builder(builder: (_) {
                  final c = s.catStyle(k);
                  final sel = _catKey == k;
                  return GestureDetector(
                    onTap: () => setState(() => _catKey = k),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? Nocturne.mix(c.color, 16) : Nocturne.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? c.color : Nocturne.neutral900,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(c.icon, size: 19, color: c.color),
                          const SizedBox(height: 4),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              c.short,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: sel
                                    ? Nocturne.text
                                    : Nocturne.neutral500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
          if (s.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChipRow(
              label: _type == 'income' ? 'Into' : 'From',
              children: [
                for (final src in s.sources)
                  V3Chip(
                    label: src.name,
                    height: 28,
                    selected: _sourceId == src.id,
                    icon: src.design.icon,
                    iconColor: src.design.color,
                    onTap: () => setState(() => _sourceId =
                        _sourceId == src.id ? null : src.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _ChipRow(
            label: 'Paid via',
            children: [
              for (final m in _methods)
                V3Chip(
                  label: m,
                  height: 28,
                  selected: _method == m,
                  onTap: () => setState(() => _method = m),
                ),
            ],
          ),
          if (members.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 52,
                  child: Text('For',
                      style: TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral500)),
                ),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final sel = (_forUser ?? s.myId) == m.userId;
                        return GestureDetector(
                          onTap: () => setState(() => _forUser = m.userId),
                          child: V3Avatar(
                            initial: m.initial,
                            color: m.color,
                            size: 30,
                            fontSize: 11.5,
                            opacity: sel ? 1 : 0.45,
                            ringColor: sel ? Nocturne.accent400 : null,
                            ringGround: Nocturne.surface,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
          // With nobody else in the workspace these controls were hidden
          // entirely, which made a built feature look missing rather than
          // inapplicable. Say why instead.
          if (_type == 'expense' && members.length <= 1) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(PhRegular.usersThree,
                      size: 16, color: Nocturne.neutral500),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Invite someone to this workspace to record who an '
                      'expense was for, and whether they owe you back.',
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Nocturne.neutral500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_type == 'expense' && members.length > 1) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _split = !_split),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Nocturne.bg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: _split ? Nocturne.accent600 : Nocturne.neutral800,
                      width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(PhRegular.usersThree,
                        size: 16, color: Nocturne.neutral400),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Paid for someone',
                          style: TextStyle(
                              fontSize: 12.5, color: Nocturne.text)),
                    ),
                    _MiniToggle(on: _split),
                  ],
                ),
              ),
            ),
            if (_split) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Nocturne.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('For',
                        style: TextStyle(
                            fontSize: 11.5, color: Nocturne.neutral500)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final m = members[i];
                            final on = _splitWith.contains(m.userId);
                            return GestureDetector(
                              onTap: () => setState(() => on
                                  ? _splitWith.remove(m.userId)
                                  : _splitWith.add(m.userId)),
                              child: V3Avatar(
                                initial: m.initial,
                                color: m.color,
                                size: 28,
                                fontSize: 11,
                                opacity: on ? 1 : 0.4,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_splitWith.isNotEmpty && _value > 0)
                      V3Num(
                        '${V3Design.inr(_value / (_splitWith.length + (_payerShares ? 1 : 0)))} each',
                        style: const TextStyle(
                            fontSize: 11.5, color: Nocturne.accent200),
                      ),
                  ],
                ),
              ),
            ],
            GestureDetector(
              onTap: () => setState(() => _payerShares = !_payerShares),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    _MiniToggle(on: _payerShares),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _payerShares
                            ? "I'm sharing this too"
                            : 'I paid it entirely for them',
                        style: const TextStyle(
                            fontSize: 12, color: Nocturne.neutral300),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.6,
            children: [
              for (final k in keys)
                _Key(label: k, onTap: () => _press(k)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _value > 0 ? _save : null,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: _value > 0 ? 1 : 0.45,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nocturne.mix(Nocturne.accent, 18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Nocturne.accent, width: 1),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Nocturne.accent100),
                      )
                    : Text(
                        _value <= 0
                            ? 'Enter an amount'
                            : 'Save ${_type == 'income' ? 'income' : 'expense'} · ${V3Design.inr(_value)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.accent100),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _ChipRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: Nocturne.neutral500)),
          ),
          Expanded(
            child: SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => children[i],
              ),
            ),
          ),
        ],
      );
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
  Widget build(BuildContext context) => V3Press(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Nocturne.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: label == '<'
              ? const Icon(PhRegular.backspace,
                  size: 20, color: Nocturne.text)
              : Text(label,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text)),
        ),
      );
}

// ── Detail sheet ────────────────────────────────────────────────────────────

class V3DetailSheet extends StatelessWidget {
  final TxnRow txn;
  const V3DetailSheet({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final style = s.catStyle(txn.categoryKey);
    final who = s.memberById(txn.userId);
    final src = s.sourceById(txn.sourceId);

    final rows = <(String, String)>[
      ('Who', who?.name ?? '—'),
      ('When', '${_dateLabel(txn.occurredAt)} · ${txn.timeLabel}'),
      ('Paid via', txn.method),
      if (src != null) ('Source', src.name),
      ('Added by', txn.origin == 'manual' ? 'Entered manually' : 'Detected'),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              V3IconTile(
                  icon: style.icon,
                  color: style.color,
                  size: 56,
                  radius: 18,
                  iconSize: 26),
              const SizedBox(height: 12),
              Text(txn.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text)),
              Text(style.name,
                  style: const TextStyle(
                      fontSize: 12, color: Nocturne.neutral500)),
              const SizedBox(height: 8),
              V3Num(
                '${txn.isExpense ? '' : '+'}${V3Design.inr(txn.amount)}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.68,
                  color: txn.isExpense
                      ? Nocturne.text
                      : NocturneSemantic.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rows[i].$1,
                            style: const TextStyle(
                                fontSize: 13, color: Nocturne.neutral500)),
                        Flexible(
                          child: Text(rows[i].$2,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Nocturne.text)),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1) const V3RowDivider(),
                ],
              ],
            ),
          ),
          if (txn.splitWith.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Nocturne.accent900,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  for (final id in txn.splitWith)
                    Transform.translate(
                      offset: const Offset(-6, 0),
                      child: V3Avatar(
                        initial: s.memberById(id)?.initial ?? '?',
                        color: s.memberById(id)?.color ?? Nocturne.neutral700,
                        size: 26,
                        fontSize: 10.5,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Split ${txn.splitWith.length + 1} ways · '
                      '${V3Design.inr(txn.amount / (txn.splitWith.length + 1))} each',
                      style: const TextStyle(
                          fontSize: 12.5, color: Nocturne.accent100),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _DetailAction(
                icon: PhRegular.pencilSimple,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  V3Sheets.openAdd(context, edit: txn);
                },
              ),
              _DetailAction(
                icon: PhRegular.usersThree,
                label: 'Split',
                onTap: () {
                  Navigator.pop(context);
                  V3Sheets.openAdd(context, edit: txn);
                },
              ),
              _DetailAction(
                icon: PhRegular.copy,
                label: 'Duplicate',
                onTap: () {
                  s.addTransaction(
                    title: txn.title,
                    amount: txn.amount,
                    type: txn.type,
                    categoryKey: txn.categoryKey,
                    method: txn.method,
                    sourceId: txn.sourceId,
                  );
                  Navigator.pop(context);
                },
              ),
              _DetailAction(
                icon: PhRegular.trash,
                label: 'Delete',
                color: NocturneSemantic.expense,
                onTap: () {
                  s.deleteTransaction(txn.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final days =
        DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: color ?? Nocturne.text),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.5, color: color ?? Nocturne.text)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Invite sheet ────────────────────────────────────────────────────────────

class V3InviteSheet extends StatefulWidget {
  const V3InviteSheet({super.key});

  @override
  State<V3InviteSheet> createState() => _V3InviteSheetState();
}

class _V3InviteSheetState extends State<V3InviteSheet> {
  String _role = 'member';
  double? _limit = 2000;
  String? _code;
  bool _busy = false;

  static const _roles = [('admin', 'Admin'), ('member', 'Member'), ('viewer', 'Viewer')];
  static const _limits = [(1000.0, '₹1,000'), (2000.0, '₹2,000'), (null, 'Off')];

  static const _roleDesc = {
    'admin': 'Can add, edit and approve for everyone.',
    'member': 'Can add and edit their own entries.',
    'viewer': 'Can see the workspace but not change it.',
  };

  Future<void> _generate() async {
    setState(() => _busy = true);
    final code = await context.read<V3State>().createInvite(_role, _limit);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTitle('Invite to ${s.family?.name ?? 'your family'}',
              "They'll join with the access you pick below"),
          const SizedBox(height: 16),
          const Text('Role',
              style: TextStyle(fontSize: 12.5, color: Nocturne.text)),
          const SizedBox(height: 6),
          _SegRow(
            options: [for (final r in _roles) r.$2],
            selected: _roles.indexWhere((r) => r.$1 == _role),
            onChanged: (i) => setState(() {
              _role = _roles[i].$1;
              _code = null;
            }),
          ),
          const SizedBox(height: 6),
          Text(_roleDesc[_role] ?? '',
              style:
                  const TextStyle(fontSize: 11.5, color: Nocturne.neutral500)),
          const SizedBox(height: 14),
          const Text('Notify me when they spend over',
              style: TextStyle(fontSize: 12.5, color: Nocturne.text)),
          const SizedBox(height: 6),
          _SegRow(
            options: [for (final l in _limits) l.$2],
            selected: _limits.indexWhere((l) => l.$1 == _limit),
            onChanged: (i) => setState(() {
              _limit = _limits[i].$1;
              _code = null;
            }),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Nocturne.accent700,
                  width: 1,
                  style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Invite code · valid 7 days',
                          style: TextStyle(
                              fontSize: 11, color: Nocturne.neutral500)),
                      const SizedBox(height: 2),
                      Text(
                        _code ?? '— — — —',
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 2.8,
                          fontFamily: 'monospace',
                          color: Nocturne.accent200,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _busy
                      ? null
                      : _code == null
                          ? _generate
                          : () {
                              Clipboard.setData(ClipboardData(text: _code!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Invite code copied'),
                                    backgroundColor: Nocturne.neutral800),
                              );
                            },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Nocturne.accent, width: 1),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Nocturne.accent200),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  _code == null
                                      ? PhRegular.plus
                                      : PhRegular.copy,
                                  size: 14,
                                  color: Nocturne.accent200),
                              const SizedBox(width: 6),
                              Text(_code == null ? 'Create' : 'Copy',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Nocturne.accent200)),
                            ],
                          ),
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

class _SegRow extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Nocturne.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? Nocturne.accent900
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == selected
                            ? Nocturne.accent600
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        color: i == selected
                            ? Nocturne.accent100
                            : Nocturne.neutral400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

// ── Approval sheet ──────────────────────────────────────────────────────────

class V3ApprovalSheet extends StatelessWidget {
  final ApprovalRow approval;
  const V3ApprovalSheet({super.key, required this.approval});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(
          '${approval.kind[0].toUpperCase()}${approval.kind.substring(1)} request',
          'From ${s.memberName(approval.requestedBy)}',
        ),
        const SizedBox(height: 14),
        if (approval.reason != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(approval.reason!,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: Nocturne.neutral300)),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  s.decideApproval(approval.id, false);
                  Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Nocturne.neutral700, width: 1),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(
                          fontSize: 13.5, color: Nocturne.neutral300)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  s.decideApproval(approval.id, true);
                  Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Nocturne.mix(Nocturne.accent, 18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Nocturne.accent, width: 1),
                  ),
                  child: const Text('Approve',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.accent100)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
