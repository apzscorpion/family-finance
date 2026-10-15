import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../../theme/nocturne_palette.dart';
import '../data/bill_scan.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../screens/categories_manager_v3.dart';
import '../screens/sources_manager_v3.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import '../../services/category_memory_service.dart';
import 'calc_engine.dart';
import 'faith_suite_sheet.dart';
import 'goals_sheet.dart';
import 'guardian_sheet.dart';
import 'household_suite_sheet.dart';
import 'magic_ai_sheet.dart';
import 'receipt_splitter_sheet.dart';
import 'recurring_sheet_v3.dart';
import 'refund_watchdog_sheet.dart';
import 'spend_roast_sheet.dart';
import 'spending_calendar_sheet.dart';
import 'voice_quick_add_sheet.dart';

/// Bottom sheets, matching the design's single sheet container:
///   `border-radius:28px 28px 0 0; background:var(--color-surface);
///    box-shadow:0 -1px 0 var(--color-neutral-700), 0 -20px 50px rgba(0,0,0,.4);
///    padding:10px 16px 26px; animation:ftUp .3s cubic-bezier(.2,.8,.2,1)`
class V3Sheets {
  V3Sheets._();

  /// When true (set by the web shell), mutating money sheets are suppressed
  /// and transaction details render without Edit/Delete actions.
  static bool readOnly = false;

  static Future<void> _notifyReadOnly(BuildContext context) async {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Expenses are read-only on web — use the mobile app to add or edit.',
        ),
      ),
    );
  }

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

  static Future<void> openSources(BuildContext context) => readOnly
      ? _notifyReadOnly(context)
      : _show(context, const V3SourceSheet());

  static Future<void> openAdd(
    BuildContext context, {
    TxnRow? edit,
    BillScan? prefill,
    Future<BillScan?>? refine,
  }) => readOnly
      ? _notifyReadOnly(context)
      : _show(
          context,
          V3AddSheet(edit: edit, prefill: prefill, refine: refine),
        );

  static Future<void> openDetail(BuildContext context, TxnRow txn) =>
      _show(context, V3DetailSheet(txn: txn));

  static Future<void> openInvite(BuildContext context) => readOnly
      ? _notifyReadOnly(context)
      : _show(context, const V3InviteSheet());

  static Future<void> openApproval(BuildContext context, ApprovalRow a) =>
      readOnly
      ? _notifyReadOnly(context)
      : _show(context, V3ApprovalSheet(approval: a));

  static Future<void> openRecurring(BuildContext context) => readOnly
      ? _notifyReadOnly(context)
      : _show(context, const V3RecurringSheet());

  static Future<void> openGoals(BuildContext context) =>
      GoalsSheet.open(context);

  static Future<void> openVoiceAdd(BuildContext context) => readOnly
      ? _notifyReadOnly(context)
      : VoiceQuickAddSheet.show(context);

  static Future<void> openSpendingCalendar(BuildContext context) =>
      SpendingCalendarSheet.show(context);

  static Future<void> openFaithSuite(BuildContext context) =>
      FaithSuiteSheet.show(context);

  static Future<void> openHouseholdSuite(
    BuildContext context, {
    int initialTab = 0,
  }) =>
      HouseholdSuiteSheet.show(context, initialTab: initialTab);

  static Future<void> openGuardian(
    BuildContext context, {
    int initialTab = 0,
  }) =>
      GuardianSheet.show(context, initialTab: initialTab);

  static Future<void> openReceiptSplitter(BuildContext context) => readOnly
      ? _notifyReadOnly(context)
      : ReceiptSplitterSheet.show(context);

  static Future<void> openRefundWatchdog(BuildContext context) =>
      RefundWatchdogSheet.show(context);

  static Future<void> openSpendRoast(BuildContext context, {int initialTab = 0}) =>
      SpendRoastSheet.show(context, initialTab: initialTab);

  static Future<void> openMagicAi(BuildContext context, {int initialTab = 0}) =>
      MagicAiSheet.show(context, initialTab: initialTab);
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 50,
            offset: Offset(0, -20),
          ),
        ],
        border: Border(top: BorderSide(color: palette.edge, width: 1)),
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
          // the grab handle: 38×4
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: palette.edge,
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
  Widget build(BuildContext context) {
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: palette.text,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ],
    );
  }
}

// ── Scope sheet ─────────────────────────────────────────────────────────────

class V3ScopeSheet extends StatelessWidget {
  const V3ScopeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final members = s.members.where((m) => m.isActive).toList();

    double spentFor(String? userId) => s.txns
        .where(
          (t) =>
              t.isExpense &&
              t.ageInDays < s.maxDays &&
              (userId == null || t.userId == userId),
        )
        .fold(0.0, (a, t) => a + t.amount);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetTitle(
            'View finances for',
            "Other members' views are read-only",
          ),
          const SizedBox(height: 12),
          _ScopeOption(
            name: s.family?.name ?? 'Family',
            sub: '${members.length} members',
            amount: s.moneyShort(spentFor(null)),
            color: Nocturne.palette.switchOn,
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
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.tint : p.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? p.tintEdge : p.edge,
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
              fontSize: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.text),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            V3Num(
              amount,
              style: TextStyle(fontSize: 13, color: p.subtle),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: selected
                  ? Icon(
                      PhFill.checkCircle,
                      size: 18,
                      color: p.accent,
                    )
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
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SheetTitle(
                  'Money source',
                  'See what came in and what was spent from each · ${s.periodLabel}',
                ),
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
                    color: p.raised,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: p.edge, width: 1),
                  ),
                  child: Icon(
                    PhRegular.slidersHorizontal,
                    size: 16,
                    color: p.subtle,
                  ),
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
            color: p.accent500,
            icon: PhRegular.wallet,
            selected: s.srcFilter == null,
            onTap: () {
              s.setSource(s.srcFilter);
              Navigator.pop(context);
            },
          ),
          for (final src in s.sources) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (_) {
                final t = s.sourceTotals(src.id);
                final denom = s.openingOf(src.id) + t.inAmt;
                final frac = denom <= 0
                    ? 0.0
                    : (t.outAmt / denom).clamp(0.0, 1.0);
                return _SourceOption(
                  name: src.name,
                  left: s.moneyShort(s.openingOf(src.id) + t.inAmt - t.outAmt),
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
              },
            ),
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
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? p.tint : p.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? p.tintEdge : p.edge,
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
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: p.text,
                          ),
                        ),
                      ),
                      V3Num(
                        left,
                        style: TextStyle(
                          fontSize: 14,
                          color: p.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  V3ProgressBar(fraction: fraction, fill: color, height: 4),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'In $inText',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.muted,
                        ),
                      ),
                      Text(
                        'Spent $outText',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: selected
                  ? Icon(
                      PhFill.checkCircle,
                      size: 18,
                      color: p.accent,
                    )
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

  /// Read from a shared payment screenshot; the user confirms before saving.
  final BillScan? prefill;

  /// The AI's better read of the same receipt, arriving after the sheet is
  /// open; it only replaces fields the user hasn't touched.
  final Future<BillScan?>? refine;
  const V3AddSheet({super.key, this.edit, this.prefill, this.refine});

  /// Who owes the payer what. One other person owes the full amount; with
  /// more, it is split equally, or the payer's own part comes off first.
  /// [nil] records who it was for with nothing owed.
  static Map<String, double>? computeShares({
    required double amount,
    required String? payer,
    required Set<String> selected,
    bool partial = false,
    bool nil = false,
    double myPart = 0,
    bool myPartIsPct = false,
  }) {
    final others = selected.where((m) => m != payer).toList();
    if (others.isEmpty || amount <= 0) return null;
    if (nil) return {for (final m in others) m: 0.0};
    if (selected.length == 1) return {others.first: amount};
    if (!partial) {
      final each = amount / selected.length;
      return {for (final m in selected) m: each};
    }
    final mine = (myPartIsPct ? amount * myPart / 100 : myPart).clamp(
      0.0,
      amount,
    );
    final each = (amount - mine) / others.length;
    return {
      for (final m in others) m: each,
      if (payer != null && selected.contains(payer)) payer: mine,
    };
  }

  @override
  State<V3AddSheet> createState() => _V3AddSheetState();
}

class _V3AddSheetState extends State<V3AddSheet> {
  String _type = 'expense';
  String _expression = '';
  /// True while the AI is still reading a shared receipt.
  bool _refining = false;

  /// The AI read of a shared receipt failed (bad key, offline, …).
  bool _refineFailed = false;

  /// Main category; [_subKey] is the optional sub-category beside it.
  String _catKey = 'groceries';
  String? _subKey;
  String _method = 'UPI';
  String? _sourceId;
  final _note = TextEditingController();

  /// Selected occurrence date (defaults to today or existing transaction date)
  late DateTime _date;

  /// Single "For" selector members. Defaults to logged-in user.
  final Set<String> _selectedMembers = {};

  /// Only used when two or more people are selected:
  /// - 'full': split equally, each owes the payer their part
  /// - 'partial': the payer covers [_myPart] (₹ or %), the rest is split
  ///   equally among the others
  String _splitMode = 'full';
  double _myPart = 0;
  bool _myPartIsPct = false;

  /// Who actually paid. Null means the person logging it. The entry is always
  /// filed under the payer; [_selectedMembers] only decides who owes them.
  String? _payer;

  /// Toggle to repeat monthly on this day of month
  bool _repeatMonthly = false;

  bool _saving = false;

  static const _methods = ['UPI', 'Cash', 'Card', 'Bank', 'Loan'];

  /// Payment methods that make sense for each money-source kind. A source
  /// kind not listed here (or no source) offers every method.
  static const _methodsByKind = {
    'income': ['UPI', 'Cash', 'Bank'],
    'savings': ['UPI', 'Cash', 'Bank'],
    'loan': ['UPI', 'Cash'],
    'card': ['Card'],
    'cash': ['Cash'],
  };

  Future<void> _newCategory(V3State s, {CategoryRow? parent}) async {
    final r = await CategoriesManagerV3.promptCategory(
      context,
      parent == null ? 'New category' : 'New subcategory of ${parent.name}',
      icon: parent?.icon,
      color: parent?.color,
    );
    if (r == null) return;
    final created = await s.addCategory(
      r.name,
      kind: _type,
      parentId: parent?.id,
      icon: r.icon,
      color: r.color,
    );
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not add category')));
      return;
    }
    setState(() {
      if (parent == null) {
        _pickMain(s, created.key);
      } else {
        _subKey = created.key;
      }
    });
  }

  void _pickMain(V3State s, String key) {
    _catKey = key;
    _subKey = null;
    _applyPeople(s, s.categoryByKey(key));
  }

  void _pickSub(V3State s, String? key) {
    _subKey = key;
    if (key != null) _applyPeople(s, s.categoryByKey(key));
  }

  /// A category with linked people sets "For" to exactly them.
  void _applyPeople(V3State s, CategoryRow? c) {
    final active = {
      for (final m in s.members)
        if (m.isActive) m.userId,
    };
    final ids = [
      for (final id in c?.memberIds ?? const <String>[])
        if (active.contains(id)) id,
    ];
    if (ids.isEmpty) return;
    _selectedMembers
      ..clear()
      ..addAll(ids);
  }

  /// After "For" changes, selects the sub (under the current main) or else
  /// the main category linked to exactly these people, if there is one.
  void _matchCategory(V3State s) {
    bool same(CategoryRow c) =>
        c.memberIds.isNotEmpty &&
        c.memberIds.length == _selectedMembers.length &&
        _selectedMembers.containsAll(c.memberIds);
    final main = s.categoryByKey(_catKey);
    final sub = main == null
        ? null
        : s.subcategoriesOf(main.id).where(same).firstOrNull;
    if (sub != null) {
      _subKey = sub.key;
      return;
    }
    final other = s.topCategories(_type).where(same).firstOrNull;
    if (other != null) {
      _catKey = other.key;
      _subKey = s.subcategoriesOf(other.id).where(same).firstOrNull?.key;
    }
  }

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _date = e?.occurredAt ?? widget.prefill?.date ?? DateTime.now();
    final p = widget.prefill;
    if (e == null && p != null) {
      if (p.amount != null) _expression = CalcEngine.format(p.amount!);
      _note.text = billNote(p);
      final s = context.read<V3State>();
      if (p.income) {
        // Same as tapping the Income tab.
        _type = 'income';
        _catKey = s.topCategories('income').firstOrNull?.key ?? 'salary';
      }
      // The AI reader's category guess, if it fits the entry's type.
      final guess = p.category == null ? null : s.categoryByKey(p.category!);
      if (guess != null && guess.kind == _type) {
        _pickMain(s, guess.key);
      } else if (_type == 'expense') {
        final learned = CategoryMemoryService.predictCategorySync(_note.text);
        if (learned != null) {
          final cat = s.categoryByKey(learned);
          if (cat != null && cat.kind == _type) _pickMain(s, cat.key);
        }
      }
    }
    final refine = widget.refine;
    if (e == null && p != null && refine != null) {
      _refining = true;
      final seen = (
        expr: _expression,
        note: _note.text,
        date: _date,
        type: _type,
        cat: _catKey,
      );
      refine.then((ai) {
        if (!mounted) return;
        setState(() {
          _refining = false;
          if (ai == null) {
            _refineFailed = true;
            return;
          }
          final s = context.read<V3State>();
          if (ai.amount != null && _expression == seen.expr) {
            _expression = CalcEngine.format(ai.amount!);
          }
          if (_note.text == seen.note) _note.text = billNote(ai);
          if (ai.date != null && _date == seen.date) _date = ai.date!;
          final untouchedCat = _type == seen.type && _catKey == seen.cat;
          if (untouchedCat && ai.income != (_type == 'income')) {
            _type = ai.income ? 'income' : 'expense';
            _catKey = s.topCategories(_type).firstOrNull?.key ??
                (ai.income ? 'salary' : 'groceries');
            _subKey = null;
          }
          final guess =
              ai.category == null ? null : s.categoryByKey(ai.category!);
          if (untouchedCat && guess != null && guess.kind == _type) {
            _pickMain(s, guess.key);
          }
        });
      }, onError: (_) {
        if (mounted) {
          setState(() {
            _refining = false;
            _refineFailed = true;
          });
        }
      });
    }
    if (e != null) {
      _type = e.type;
      _expression = CalcEngine.format(e.amount);
      _catKey = e.categoryKey;
      _subKey = context.read<V3State>().categoryById(e.subCategoryId)?.key;
      _method = e.method;
      _sourceId = e.sourceId;
      _note.text = e.title;
      _payer = e.paidBy ?? e.userId;
      // Income paid_by is who paid you; "me" there means nobody recorded.
      if (e.type == 'income' && _payer == e.userId) _payer = '';
      if (e.shares.isNotEmpty) {
        _selectedMembers.addAll(e.shares.keys);
        final values = e.shares.values.toList();
        final equal = values.every((v) => (v - values.first).abs() < 0.01);
        if (values.every((v) => v == 0)) {
          _splitMode = 'nil';
        } else if (_selectedMembers.length > 1 && !equal) {
          _splitMode = 'partial';
          final othersOwe = e.shares.entries
              .where((x) => x.key != _payer)
              .fold(0.0, (t, x) => t + x.value);
          _myPart = e.amount - othersOwe;
        }
      } else if (e.userId != null) {
        _selectedMembers.add(e.userId!);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Nocturne.palette.accent,
            surface: Nocturne.palette.surface,
          ),
          dialogTheme: DialogThemeData(backgroundColor: Nocturne.palette.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  void dispose() {
    _note.dispose();
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
        // Prevent duplicate dot in the current operand
        final parts = _expression.split(RegExp(r'[\+\-×÷]'));
        final lastPart = parts.isNotEmpty ? parts.last : '';
        if (!lastPart.contains('.')) {
          _expression += lastPart.isEmpty ? '0.' : '.';
        }
      } else if (k == '+' || k == '-' || k == '×' || k == '÷') {
        if (_expression.isNotEmpty) {
          if (_expression.endsWith('+') ||
              _expression.endsWith('-') ||
              _expression.endsWith('×') ||
              _expression.endsWith('÷')) {
            _expression = _expression.substring(0, _expression.length - 1) + k;
          } else {
            _expression += k;
          }
        }
      } else {
        if (_expression.length >= 18) return;
        _expression += k;
      }
    });
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    setState(() => _expression = '');
  }

  Future<void> _save() async {
    final s = context.read<V3State>();
    final amountToSave = _value;
    if (amountToSave <= 0 || _saving) return;
    setState(() => _saving = true);

    // The entry stays under whoever paid; "For" only creates what others owe.
    final isIncome = _type == 'income';
    final payer = isIncome ? s.myId : (_payer ?? s.myId);
    final forUserId = payer;
    // Income: paid_by is who paid you; empty means someone outside the family.
    final paidBy = isIncome
        ? ((_payer?.isNotEmpty ?? false) ? _payer : s.myId)
        : payer;
    final shares = isIncome
        ? null
        : V3AddSheet.computeShares(
            amount: amountToSave,
            payer: payer,
            selected: _selectedMembers,
            partial: _splitMode == 'partial',
            nil: _splitMode == 'nil',
            myPart: _myPart,
            myPartIsPct: _myPartIsPct,
          );

    final title = _note.text.trim();
    final ok = widget.edit != null
        ? await s.updateTransaction(
            id: widget.edit!.id,
            title: title,
            amount: amountToSave,
            type: _type,
            categoryKey: _catKey,
            subCategoryKey: _subKey,
            method: _method,
            sourceId: _sourceId,
            forUserId: forUserId,
            paidBy: paidBy,
            shares: shares,
            occurredAt: _date,
          )
        : await s.addTransaction(
            title: title,
            amount: amountToSave,
            type: _type,
            categoryKey: _catKey,
            subCategoryKey: _subKey,
            method: _method,
            sourceId: _sourceId,
            forUserId: forUserId,
            paidBy: paidBy,
            shares: shares,
            occurredAt: _date,
          );

    if (ok && _repeatMonthly) {
      final now = DateTime.now();
      await s.addRecurring(
        title: title.isEmpty
            ? (s.categoryByKey(_catKey)?.name ?? 'Recurring')
            : title,
        amount: amountToSave,
        cadence: 'monthly',
        nextDue: now,
        type: _type,
        categoryKey: _catKey,
        sourceId: _sourceId,
        autoPost: true,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (_type == 'expense' && title.isNotEmpty) {
        CategoryMemoryService.remember(title, _catKey);
      }
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save — check your connection'),
          backgroundColor: Nocturne.palette.edge,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final keys = const [
      '1',
      '2',
      '3',
      '+',
      '4',
      '5',
      '6',
      '-',
      '7',
      '8',
      '9',
      '×',
      '.',
      '0',
      '<',
      '=',
    ];
    // Settings order; the hardcoded list only covers the first load.
    final topCats = s.topCategories(_type);
    final catKeys = topCats.isNotEmpty
        ? [for (final c in topCats) c.key]
        : (_type == 'expense' ? V3Design.expenseCats : V3Design.incomeCats);
    final parentCat = s.categoryByKey(_catKey);
    final subCats = parentCat == null
        ? const <CategoryRow>[]
        : s.subcategoriesOf(parentCat.id);
    // Payment methods that fit the chosen account; all of them when none is.
    final srcKind = s.sourceById(_sourceId)?.kind;
    final allowed = _methodsByKind[srcKind] ?? _methods;
    final methods = [...allowed, if (!allowed.contains(_method)) _method];
    final members = s.members.where((m) => m.isActive).toList();

    final payer = _type == 'income' ? s.myId : (_payer ?? s.myId);
    final payerIsMe = payer == s.myId;
    final payerName = payerIsMe
        ? 'You'
        : members
                  .where((m) => m.userId == payer)
                  .map((m) => m.name)
                  .firstOrNull ??
              'They';

    // Default the "For" selection to the payer.
    if (_selectedMembers.isEmpty && payer != null) {
      _selectedMembers.add(payer);
    }

    final isMulti = _selectedMembers.length > 1;
    final isOtherSingle =
        _selectedMembers.length == 1 && !_selectedMembers.contains(payer);
    final otherMember = isOtherSingle
        ? members.firstWhere(
            (m) => m.userId == _selectedMembers.first,
            orElse: () => members.first,
          )
        : null;

    final hasMath = CalcEngine.hasOperator(_expression);
    final evaluated = _value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: Add entry + Type toggle + Checkmark Save button ─────────
          Row(
            children: [
              Text(
                widget.edit == null ? 'Add entry' : 'Edit entry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.palette.text,
                ),
              ),
              const Spacer(),
              V3Segmented(
                labels: const ['Expense', 'Income'],
                selected: _type == 'expense' ? 0 : 1,
                ground: Nocturne.palette.bg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                onChanged: (i) => setState(() {
                  _type = i == 0 ? 'expense' : 'income';
                  final first = s.topCategories(_type).firstOrNull;
                  _catKey = first?.key ?? (i == 0 ? 'groceries' : 'salary');
                  _subKey = null;
                  _payer = null;
                }),
              ),
              const SizedBox(width: 8),
              // Voice Entry Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  V3Sheets.openVoiceAdd(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Nocturne.palette.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Nocturne.palette.edge, width: 1),
                  ),
                  child: Icon(
                    PhRegular.sparkle,
                    size: 18,
                    color: Nocturne.palette.accentMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Header Save Checkmark (✓)
              GestureDetector(
                onTap: (evaluated > 0 && !_saving) ? _save : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: evaluated > 0
                        ? (_type == 'income'
                              ? Nocturne.palette.income
                              : Nocturne.palette.accent)
                        : Nocturne.palette.edge,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          PhBold.check,
                          size: 20,
                          color: evaluated > 0
                              ? Colors.white
                              : Nocturne.palette.muted,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Date chip + who paid, on one line ─────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: _pickDate,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Nocturne.palette.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Nocturne.palette.edge, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhRegular.calendar,
                        size: 15,
                        color: Nocturne.palette.accentMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        V3DetailSheet._dateLabel(_date),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.palette.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        PhBold.caretDown,
                        size: 10,
                        color: Nocturne.palette.subtle,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (members.length > 1) ...[
                Text(
                  _type == 'income' ? 'From ' : 'Paid by ',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Nocturne.palette.muted,
                  ),
                ),
                if (_type == 'income')
                  DropdownButton<String>(
                    value:
                        members.any(
                          (m) => m.userId == _payer && m.userId != s.myId,
                        )
                        ? _payer
                        : '',
                    isDense: true,
                    dropdownColor: Nocturne.palette.surface,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Nocturne.palette.accentLight,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Outside family'),
                      ),
                      for (final m in members)
                        if (m.userId != s.myId)
                          DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.name),
                          ),
                    ],
                    onChanged: (v) => setState(() => _payer = v),
                  ),
                if (_type == 'expense')
                  DropdownButton<String>(
                    value: members.any((m) => m.userId == payer) ? payer : null,
                    isDense: true,
                    dropdownColor: Nocturne.palette.surface,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Nocturne.palette.accentLight,
                    ),
                    items: [
                      for (final m in members)
                        DropdownMenuItem(
                          value: m.userId,
                          child: Text(m.userId == s.myId ? 'You' : m.name),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      // Keep the "just for the payer" default following the payer.
                      if (_selectedMembers.length == 1 &&
                          _selectedMembers.contains(payer)) {
                        _selectedMembers
                          ..clear()
                          ..add(v!);
                      }
                      _payer = v;
                    }),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (_refineFailed)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "Couldn't check this receipt with AI (see Settings → AI). "
                'Please check the amount.',
                style: TextStyle(fontSize: 11.5, color: Nocturne.palette.warning),
              ),
            ),
          if (_refining)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Nocturne.palette.accentMuted,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Checking the receipt with AI…',
                    style: TextStyle(fontSize: 11.5, color: Nocturne.palette.subtle),
                  ),
                ],
              ),
            ),

          // ── Note / Merchant text field ────────────────────────────────────
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Nocturne.palette.edge, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  PhRegular.notePencil,
                  size: 16,
                  color: Nocturne.palette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _note,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Nocturne.palette.text,
                    ),
                    cursorColor: Nocturne.palette.accent,
                    onChanged: (text) {
                      if (_type == 'expense' && widget.edit == null) {
                        final predicted = CategoryMemoryService.predictCategorySync(text);
                        if (predicted != null && predicted != _catKey) {
                          final cat = s.categoryByKey(predicted);
                          if (cat != null && cat.kind == _type) {
                            setState(() {
                              _catKey = predicted;
                              _subKey = null;
                            });
                          }
                        }
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: _type == 'income'
                          ? 'What it was for (optional)'
                          : 'Merchant or note (optional)',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: Nocturne.palette.faint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Single-line Categories with horizontal scroll ─────────────────
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: catKeys.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == catKeys.length) {
                  return _NewCatTile(onTap: () => _newCategory(s));
                }
                final k = catKeys[i];
                final c = s.catStyle(k);
                final sel = _catKey == k;
                return GestureDetector(
                  onTap: () => setState(() => _pickMain(s, k)),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      color: sel ? Nocturne.mix(c.color, 18) : Nocturne.palette.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? c.color : Nocturne.palette.edge,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          c.icon,
                          size: 20,
                          color: sel ? c.color : Nocturne.palette.subtle,
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            c.short,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: sel ? Nocturne.palette.text : Nocturne.palette.subtle,
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
          // ── Subcategories of the chosen category ──────────────────────────
          if (parentCat != null) ...[
            const SizedBox(height: 8),
            _ChipRow(
              label: 'Sub',
              children: [
                for (final sub in subCats)
                  V3Chip(
                    label: sub.name,
                    height: 28,
                    icon: s.catStyle(sub.key).icon,
                    iconColor: s.catStyle(sub.key).color,
                    selected: _subKey == sub.key,
                    // Tapping the chosen one again clears it.
                    onTap: () => setState(
                      () => _pickSub(s, _subKey == sub.key ? null : sub.key),
                    ),
                  ),
                V3Chip(
                  label: 'New',
                  icon: PhRegular.plus,
                  height: 28,
                  onTap: () => _newCategory(s, parent: parentCat),
                ),
              ],
            ),
          ],
          // ── From / Into Source chips with explanation ─────────────────────
          if (s.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        onTap: () => setState(() {
                          _sourceId = _sourceId == src.id ? null : src.id;
                          final ok =
                              _methodsByKind[s.sourceById(_sourceId)?.kind] ??
                              _methods;
                          if (!ok.contains(_method)) _method = ok.first;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // ── Paid via chips with explanation ───────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChipRow(
                label: 'Paid via',
                children: [
                  for (final m in methods)
                    V3Chip(
                      label: m,
                      height: 28,
                      selected: _method == m,
                      onTap: () => setState(() => _method = m),
                    ),
                ],
              ),
            ],
          ),

          // ── ONLY ONE "For" selector (default: you, multi-selectable) ───────
          if (members.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    'For',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Nocturne.palette.muted,
                    ),
                  ),
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
                        final isMe = m.userId == s.myId;
                        final sel = _selectedMembers.contains(m.userId);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              if (_selectedMembers.length > 1) {
                                _selectedMembers.remove(m.userId);
                              }
                            } else {
                              _selectedMembers.add(m.userId);
                            }
                            _matchCategory(s);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Nocturne.mix(m.color, 20)
                                  : Nocturne.palette.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sel ? m.color : Nocturne.palette.edge,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                V3Avatar(
                                  initial: m.initial,
                                  color: m.color,
                                  size: 22,
                                  fontSize: 10,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isMe ? 'You' : m.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel
                                        ? Nocturne.palette.text
                                        : Nocturne.palette.subtle,
                                  ),
                                ),
                                if (sel) ...[
                                  const SizedBox(width: 4),
                                  Icon(PhBold.check, size: 12, color: m.color),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_type == 'expense') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Nocturne.palette.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Nocturne.palette.edge, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    PhRegular.usersThree,
                    size: 15,
                    color: Nocturne.palette.muted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invite members in More to split expenses and track who owes what.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Nocturne.palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Split / Paying for someone section ─────────────────────────────
          if (_type == 'expense' && isOtherSingle && otherMember != null) ...[
            const SizedBox(height: 10),
            _splitBox(
              icon: PhRegular.user,
              title: 'Paid for ${otherMember.name}',
              children: [
                Row(
                  children: [
                    // Partial only applies with two or more people, so any
                    // mode but Nil means Full here.
                    _splitChip(
                      'Full',
                      'full',
                      selectedOverride: _splitMode != 'nil',
                    ),
                    const SizedBox(width: 6),
                    _splitChip('Nil', 'nil'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _splitMode == 'nil'
                      ? 'Paid for ${otherMember.name}. Nothing owed.'
                      : '${otherMember.name} owes ${payerIsMe ? 'you' : payerName} the full ${V3Design.inr(evaluated)}.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Nocturne.palette.accentLight,
                  ),
                ),
              ],
            ),
          ] else if (_type == 'expense' && isMulti) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final preview =
                    V3AddSheet.computeShares(
                      amount: evaluated,
                      payer: payer,
                      selected: _selectedMembers,
                      partial: _splitMode == 'partial',
                      nil: _splitMode == 'nil',
                      myPart: _myPart,
                      myPartIsPct: _myPartIsPct,
                    ) ??
                    const <String, double>{};
                final owed = preview.entries.where((e) => e.key != payer);
                final each = owed.isEmpty ? 0.0 : owed.first.value;
                return _splitBox(
                  icon: PhRegular.usersThree,
                  title: 'Split among ${_selectedMembers.length} people',
                  children: [
                    Row(
                      children: [
                        _splitChip('Full', 'full'),
                        const SizedBox(width: 6),
                        _splitChip('Partial', 'partial'),
                        const SizedBox(width: 6),
                        _splitChip('Nil', 'nil'),
                      ],
                    ),
                    if (_splitMode == 'partial') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            payerIsMe ? 'Your part' : '$payerName\'s part',
                            style: TextStyle(
                              fontSize: 12,
                              color: Nocturne.palette.subtle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Nocturne.palette.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Nocturne.palette.faint,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Nocturne.palette.text,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Nocturne.palette.faint,
                                  ),
                                ),
                                onChanged: (v) => setState(
                                  () => _myPart = double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          V3Segmented(
                            labels: const ['₹', '%'],
                            selected: _myPartIsPct ? 1 : 0,
                            onChanged: (i) =>
                                setState(() => _myPartIsPct = i == 1),
                          ),
                        ],
                      ),
                    ],
                    if (_splitMode == 'nil') ...[
                      const SizedBox(height: 6),
                      Text(
                        'Records who it was for. Nobody owes anything.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.palette.accentLight,
                        ),
                      ),
                    ] else if (evaluated > 0 && owed.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Each of ${owed.length} owes ${payerIsMe ? 'you' : payerName} ${V3Design.inr(each)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.palette.accentLight,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],

          // ── Repeat monthly (Recurring) toggle ─────────────────────────────
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _repeatMonthly = !_repeatMonthly),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Nocturne.palette.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _repeatMonthly
                      ? Nocturne.palette.tintEdge
                      : Nocturne.palette.edge,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhRegular.arrowsClockwise,
                    size: 16,
                    color: _repeatMonthly
                        ? Nocturne.palette.accentMuted
                        : Nocturne.palette.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Repeat monthly on the ${_daySuffix(DateTime.now().day)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _repeatMonthly
                            ? Nocturne.palette.text
                            : Nocturne.palette.subtle,
                      ),
                    ),
                  ),
                  _MiniToggle(on: _repeatMonthly),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Calculator Input Display (attached directly to keypad) ────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.edge, width: 1),
            ),
            child: Row(
              children: [
                Text(
                  '₹',
                  style: TextStyle(fontSize: 20, color: p.muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _expression.isEmpty ? '0' : _expression,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: _type == 'income'
                          ? p.income
                          : p.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (hasMath && evaluated > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.tintEdge, width: 1),
                    ),
                    child: Text(
                      '= ₹${CalcEngine.format(evaluated)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.accent,
                      ),
                    ),
                  ),
                ],
                if (_type == 'expense' && evaluated > 0) ...[
                  Builder(
                    builder: (ctx) {
                      final monthlyBase = s.totalIncome > 0
                          ? s.totalIncome
                          : (s.budgetLimit > 0 ? s.budgetLimit : 50000.0);
                      final hourlyRate = monthlyBase / 160.0;
                      final workHours = evaluated / hourlyRate;
                      final workLabel = workHours >= 8.0
                          ? '${(workHours / 8.0).toStringAsFixed(1)}d work'
                          : (workHours >= 1.0
                              ? '${workHours.toStringAsFixed(1)}h work'
                              : '${(workHours * 60).round()}m work');
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Nocturne.palette.edge,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhRegular.clock,
                              size: 11,
                              color: Nocturne.palette.subtle,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '≈ $workLabel',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Nocturne.palette.neutral300,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── 4-column Calculator Keypad ────────────────────────────────────
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.85,
            children: [
              for (final k in keys)
                _CalcKey(
                  label: k,
                  onTap: () => _press(k),
                  onLongPress: k == '<' ? _clearAll : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _splitBox({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.edge, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: p.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _splitChip(String label, String mode, {bool? selectedOverride}) {
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final sel = selectedOverride ?? _splitMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _splitMode = mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? p.tint : p.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? p.tintEdge : p.edge,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? p.accent : p.muted,
          ),
        ),
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

class _CalcKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CalcKey({required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final isOp = ['+', '-', '×', '÷', '='].contains(label);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOp ? p.tint : p.raised,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isOp ? p.tintEdge : p.edge,
            width: 1,
          ),
        ),
        child: label == '<'
            ? Icon(PhRegular.backspace, size: 19, color: p.text)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isOp ? FontWeight.w600 : FontWeight.w500,
                  color: isOp ? p.accent : p.text,
                ),
              ),
      ),
    );
  }
}

/// Trailing "+ New" tile in the add sheet's category strip.
class _NewCatTile extends StatelessWidget {
  final VoidCallback onTap;
  const _NewCatTile({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 62,
      decoration: BoxDecoration(
        color: Nocturne.palette.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Nocturne.palette.switchOn, width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhRegular.plus, size: 20, color: Nocturne.palette.accentMuted),
          SizedBox(height: 3),
          Text(
            'New',
            style: TextStyle(fontSize: 10, color: Nocturne.palette.accentLight),
          ),
        ],
      ),
    ),
  );
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
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, color: Nocturne.palette.muted),
        ),
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
      color: on ? Nocturne.palette.tintEdge : Nocturne.palette.edge,
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
          color: on ? Nocturne.palette.accentLight : Nocturne.palette.muted,
          shape: BoxShape.circle,
        ),
      ),
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
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final style = s.catStyle(txn.categoryKey);
    final who = s.memberById(txn.userId);
    final src = s.sourceById(txn.sourceId);

    final rows = <(String, String)>[
      ('Who', who?.name ?? '—'),
      ('When', '${_dateLabel(txn.occurredAt)} · ${txn.timeLabel}'),
      if (txn.paidBy != null && txn.paidBy != txn.userId)
        (txn.isExpense ? 'Paid by' : 'From', s.memberName(txn.paidBy)),
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
                iconSize: 26,
              ),
              const SizedBox(height: 12),
              Text(
                txn.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: p.text,
                ),
              ),
              Text(
                style.name,
                style: TextStyle(
                  fontSize: 12,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 8),
              V3Num(
                '${txn.isExpense ? '' : '+'}${V3Design.inr(txn.amount)}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.68,
                  color: txn.isExpense
                      ? p.text
                      : p.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.edge, width: 1),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rows[i].$1,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.muted,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            rows[i].$2,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: p.text,
                            ),
                          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.tintEdge, width: 1),
              ),
              child: Row(
                children: [
                  for (final id in txn.splitWith)
                    Transform.translate(
                      offset: const Offset(-6, 0),
                      child: V3Avatar(
                        initial: s.memberById(id)?.initial ?? '?',
                        color: s.memberById(id)?.color ?? p.faint,
                        size: 26,
                        fontSize: 10.5,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      txn.splitWith.every((id) => txn.shareOf(id) == 0)
                          ? 'Paid for ${txn.splitWith.map(s.memberName).join(', ')} · nothing owed'
                          : 'Owes ${s.memberName(txn.paidBy)}: '
                                '${txn.splitWith.map((id) => '${s.memberName(id)} ${V3Design.inr(txn.shareOf(id))}').join(' · ')}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: p.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (!V3Sheets.readOnly)
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
                if ((txn.paidBy ?? txn.userId) != s.myId)
                  _DetailAction(
                    icon: PhRegular.chatCircleDots,
                    label: 'Ask',
                    color: Nocturne.palette.accentMuted,
                    onTap: () {
                      final payerId = txn.paidBy ?? txn.userId;
                      final nav = context.read<V3Nav?>();
                      Navigator.pop(context);
                      if (nav != null && payerId != null) {
                        final question = 'Hey! What was this expense for? "${txn.title}" (${V3Design.inr(txn.amount)}) on ${_dateLabel(txn.occurredAt)}';
                        nav.openChat(payerId, question);
                      }
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
                  color: Nocturne.palette.expense,
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
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
            border: Border.all(color: Nocturne.palette.edge, width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color ?? Nocturne.palette.text),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11.5, color: color ?? Nocturne.palette.text),
              ),
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

  static const _roles = [
    ('admin', 'Admin'),
    ('member', 'Member'),
    ('viewer', 'Viewer'),
  ];
  static const _limits = [
    (1000.0, '₹1,000'),
    (2000.0, '₹2,000'),
    (null, 'Off'),
  ];

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
          _SheetTitle(
            'Invite to ${s.family?.name ?? 'your family'}',
            "They'll join with the access you pick below",
          ),
          const SizedBox(height: 16),
          Text(
            'Role',
            style: TextStyle(fontSize: 12.5, color: Nocturne.palette.text),
          ),
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
          Text(
            _roleDesc[_role] ?? '',
            style: TextStyle(fontSize: 11.5, color: Nocturne.palette.muted),
          ),
          const SizedBox(height: 14),
          Text(
            'Notify me when they spend over',
            style: TextStyle(fontSize: 12.5, color: Nocturne.palette.text),
          ),
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
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Nocturne.palette.switchOn,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Invite code · valid 7 days',
                        style: TextStyle(
                          fontSize: 11,
                          color: Nocturne.palette.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _code ?? '— — — —',
                        style: TextStyle(
                          fontSize: 20,
                          letterSpacing: 2.8,
                          fontFamily: 'monospace',
                          color: Nocturne.palette.accentLight,
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
                            SnackBar(
                              content: Text('Invite code copied'),
                              backgroundColor: Nocturne.palette.edge,
                            ),
                          );
                        },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Nocturne.palette.accent, width: 1),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Nocturne.palette.accentLight,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _code == null ? PhRegular.plus : PhRegular.copy,
                                size: 14,
                                color: Nocturne.palette.accentLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _code == null ? 'Create' : 'Copy',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Nocturne.palette.accentLight,
                                ),
                              ),
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
      color: Nocturne.palette.bg,
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
                      ? Nocturne.palette.tint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == selected
                        ? Nocturne.palette.tintEdge
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    color: i == selected
                        ? Nocturne.palette.accentLight
                        : Nocturne.palette.subtle,
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
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              approval.reason!,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Nocturne.palette.neutral300,
              ),
            ),
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
                    border: Border.all(color: Nocturne.palette.faint, width: 1),
                  ),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Nocturne.palette.neutral300,
                    ),
                  ),
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
                    color: Nocturne.mix(Nocturne.palette.accent, 18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Nocturne.palette.accent, width: 1),
                  ),
                  child: Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.palette.accentLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
