import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_motion.dart';

/// The change a batch edit applies. Null fields are left untouched.
class BatchEdit {
  const BatchEdit({this.sourceId, this.categoryKey, this.isIncome});

  final String? sourceId;
  final String? categoryKey;
  final bool? isIncome;

  bool get isEmpty => sourceId == null && categoryKey == null && isIncome == null;
}

class BatchEditSheet extends StatefulWidget {
  const BatchEditSheet({super.key, required this.count});

  final int count;

  static Future<BatchEdit?> open(BuildContext context, {required int count}) =>
      showModalBottomSheet<BatchEdit>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => BatchEditSheet(count: count),
      );

  @override
  State<BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<BatchEditSheet> {
  String? _sourceId;
  String? _categoryKey;
  bool? _isIncome;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final edit = BatchEdit(
        sourceId: _sourceId, categoryKey: _categoryKey, isIncome: _isIncome);
    final keys = [
      ...V3Design.expenseCats,
      ...V3Design.incomeCats,
      for (final c in s.categories)
        if (!V3Design.cats.containsKey(c.key)) c.key,
    ].where((k) => s.categoryByKey(k) != null).toList();

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral700, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${widget.count} transaction${widget.count == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.text),
            ),
            const SizedBox(height: 4),
            const Text('Only what you pick changes; the rest stays as it is.',
                style: TextStyle(fontSize: 12, color: Nocturne.neutral500)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('ACCOUNT'),
                    _Wrap([
                      for (final src in s.sources)
                        _Chip(
                          label: src.name,
                          icon: src.design.icon,
                          selected: _sourceId == src.id,
                          onTap: () => setState(() => _sourceId =
                              _sourceId == src.id ? null : src.id),
                        ),
                    ]),
                    const _Label('TYPE'),
                    _Wrap([
                      _Chip(
                        label: 'Expense',
                        icon: PhRegular.trendDown,
                        selected: _isIncome == false,
                        onTap: () => setState(() =>
                            _isIncome = _isIncome == false ? null : false),
                      ),
                      _Chip(
                        label: 'Income',
                        icon: PhRegular.trendUp,
                        selected: _isIncome == true,
                        onTap: () => setState(
                            () => _isIncome = _isIncome == true ? null : true),
                      ),
                    ]),
                    const _Label('CATEGORY'),
                    _Wrap([
                      for (final k in keys)
                        _Chip(
                          label: s.catStyle(k).name,
                          icon: s.catStyle(k).icon,
                          selected: _categoryKey == k,
                          onTap: () => setState(() =>
                              _categoryKey = _categoryKey == k ? null : k),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            V3Press(
              onTap: edit.isEmpty ? null : () => Navigator.pop(context, edit),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: edit.isEmpty ? Nocturne.neutral800 : Nocturne.accent700,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: edit.isEmpty
                          ? Nocturne.neutral700
                          : Nocturne.accent400),
                ),
                child: Text(
                  'Apply to ${widget.count}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color:
                        edit.isEmpty ? Nocturne.neutral500 : Nocturne.accent100,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: Nocturne.neutral400)),
      );
}

class _Wrap extends StatelessWidget {
  const _Wrap(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Nocturne.accent900 : Nocturne.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected ? Nocturne.accent400 : Nocturne.neutral800),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? Nocturne.accent200 : Nocturne.neutral400),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? Nocturne.accent100 : Nocturne.neutral300)),
            ],
          ),
        ),
      );
}
