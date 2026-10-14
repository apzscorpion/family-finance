import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_catalog.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Manage categories: add, rename, delete, reorder, and subcategories.
///
/// The order set here is the order the add-entry screen shows them in, so the
/// most-used categories can sit first.
class CategoriesManagerV3 extends StatefulWidget {
  const CategoriesManagerV3({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CategoriesManagerV3()),
      );

  /// Name, icon and colour for a category. Returns null when cancelled or
  /// the name is left blank.
  static Future<({String name, String icon, String color})?> promptCategory(
    BuildContext context,
    String title, {
    String name = '',
    String? icon,
    String? color,
  }) async {
    final controller = TextEditingController(text: name);
    var pickedIcon = icon ?? 'sparkle';
    var pickedColor = color ?? V3Design.customCategoryColors.first;
    var query = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final tint = V3Design.parseHex(pickedColor) ?? Nocturne.accent;
          return AlertDialog(
            backgroundColor: Nocturne.surface,
            title: Text(title,
                style: const TextStyle(fontSize: 17, color: Nocturne.text)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      V3IconTile(
                          icon: V3Design.iconFromName(pickedIcon),
                          color: tint,
                          size: 40,
                          radius: 12),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: name.isEmpty,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                              fontSize: 14, color: Nocturne.text),
                          cursorColor: Nocturne.accent,
                          decoration: InputDecoration(
                            hintText: 'Name',
                            hintStyle: const TextStyle(
                                fontSize: 14, color: Nocturne.neutral600),
                            filled: true,
                            fillColor: Nocturne.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setLocal(() => query = v),
                    style: const TextStyle(fontSize: 13, color: Nocturne.text),
                    cursorColor: Nocturne.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(PhRegular.magnifyingGlass,
                          size: 16, color: Nocturne.neutral500),
                      hintText: 'Search icons (e.g. car, pill, coffee)',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Nocturne.neutral600),
                      filled: true,
                      fillColor: Nocturne.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final names = iconMatches(query);
                    if (names.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No icons match',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Nocturne.neutral500)),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 220,
                      width: double.maxFinite,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 44,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemCount: names.length,
                        itemBuilder: (_, i) {
                          final name = names[i];
                          final sel = pickedIcon == name;
                          return GestureDetector(
                            onTap: () => setLocal(() => pickedIcon = name),
                            behavior: HitTestBehavior.opaque,
                            child: Semantics(
                              button: true,
                              selected: sel,
                              label: name.replaceAll('-', ' '),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Nocturne.mix(tint, 22)
                                      : Nocturne.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        sel ? tint : Nocturne.neutral800,
                                  ),
                                ),
                                child: Icon(V3Design.iconFromName(name),
                                    size: 18,
                                    color: sel
                                        ? tint
                                        : Nocturne.neutral400),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in V3Design.customCategoryColors)
                        GestureDetector(
                          onTap: () => setLocal(() => pickedColor = hex),
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            button: true,
                            selected: pickedColor == hex,
                            label: 'Colour $hex',
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: V3Design.parseHex(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pickedColor == hex
                                      ? Nocturne.text
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Nocturne.neutral400))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save',
                      style: TextStyle(color: Nocturne.accent300))),
            ],
          );
        },
      ),
    );
    final v = controller.text.trim();
    return ok == true && v.isNotEmpty
        ? (name: v, icon: pickedIcon, color: pickedColor)
        : null;
  }

  /// Icon names for the picker: the curated set first, then every Phosphor
  /// icon. A search matches words in the name ("credit card" → credit-card).
  static List<String> iconMatches(String query) {
    final all = [
      ...V3Design.categoryIconRegistry.keys,
      for (final n in phosphorCatalog.keys)
        if (!V3Design.categoryIconRegistry.containsKey(n)) n,
    ];
    final words = query
        .toLowerCase()
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return all;
    return [
      for (final n in all)
        if (words.every(n.contains)) n,
    ];
  }

  @override
  State<CategoriesManagerV3> createState() => _CategoriesManagerV3State();
}

class _CategoriesManagerV3State extends State<CategoriesManagerV3> {
  String _kind = 'expense';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final cats = s.topCategories(_kind);

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(PhRegular.arrowLeft,
                          size: 22, color: Nocturne.text),
                    ),
                  ),
                  const Expanded(
                    child: Text('Categories',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text)),
                  ),
                  V3Segmented(
                    labels: const ['Expense', 'Income'],
                    selected: _kind == 'expense' ? 0 : 1,
                    onChanged: (i) =>
                        setState(() => _kind = i == 0 ? 'expense' : 'income'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Drag to reorder. The add-entry screen shows categories in '
                'this order, so put the ones you use most at the top.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: Nocturne.neutral500),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                buildDefaultDragHandles: false,
                itemCount: cats.length,
                onReorderItem: (from, to) {
                  final list = [...cats];
                  list.insert(to, list.removeAt(from));
                  s.reorderCategories(list);
                },
                footer: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: () async {
                      final r = await CategoriesManagerV3.promptCategory(
                          context, 'New category');
                      if (r != null) {
                        await s.addCategory(r.name,
                            kind: _kind, icon: r.icon, color: r.color);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Nocturne.accent700, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhRegular.plus,
                              size: 16, color: Nocturne.accent200),
                          SizedBox(width: 8),
                          Text('Add a category',
                              style: TextStyle(
                                  fontSize: 14, color: Nocturne.accent200)),
                        ],
                      ),
                    ),
                  ),
                ),
                itemBuilder: (_, i) => _CategoryTile(
                  key: ValueKey(cats[i].id),
                  cat: cats[i],
                  index: i,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryRow cat;
  final int index;
  const _CategoryTile({super.key, required this.cat, required this.index});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final style = s.catStyle(cat.key);
    final subs = s.subcategoriesOf(cat.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 32,
                  height: 36,
                  child: Icon(PhRegular.dotsSixVertical,
                      size: 18, color: Nocturne.neutral500),
                ),
              ),
              V3IconTile(
                  icon: style.icon, color: style.color, size: 34, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13.5, color: Nocturne.text)),
              ),
              GestureDetector(
                onTap: () => _menu(context, s, cat, canAddSub: true),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(PhRegular.dotsThree,
                      size: 18, color: Nocturne.neutral500),
                ),
              ),
            ],
          ),
          if (subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(76, 6, 0, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sub in subs)
                    V3Chip(
                      label: sub.name,
                      height: 26,
                      icon: s.catStyle(sub.key).icon,
                      iconColor: s.catStyle(sub.key).color,
                      onTap: () => _menu(context, s, sub, canAddSub: false),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static void _menu(BuildContext context, V3State s, CategoryRow c,
      {required bool canAddSub}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(c.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.text)),
            const SizedBox(height: 8),
            if (canAddSub)
              ListTile(
                leading: const Icon(PhRegular.plus,
                    size: 18, color: Nocturne.text),
                title: const Text('Add subcategory',
                    style: TextStyle(fontSize: 14, color: Nocturne.text)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final r = await CategoriesManagerV3.promptCategory(
                      context, 'New subcategory of ${c.name}',
                      icon: c.icon, color: c.color);
                  if (r != null) {
                    await s.addCategory(r.name,
                        kind: c.kind,
                        parentId: c.id,
                        icon: r.icon,
                        color: r.color);
                  }
                },
              ),
            ListTile(
              leading: const Icon(PhRegular.pencilSimple,
                  size: 18, color: Nocturne.text),
              title: const Text('Edit name & icon',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              onTap: () async {
                Navigator.pop(ctx);
                final r = await CategoriesManagerV3.promptCategory(
                    context, 'Edit ${c.name}',
                    name: c.name, icon: c.icon, color: c.color);
                if (r != null) {
                  await s.editCategory(c,
                      name: r.name, icon: r.icon, color: r.color);
                }
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.users,
                  size: 18, color: Nocturne.text),
              title: const Text('Linked people',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              subtitle: Text(
                  _names([
                    for (final m in s.members)
                      if (c.memberIds.contains(m.userId)) m.name,
                  ], 'Picking this category fills in "For" with them'),
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _pickMany(
                  context,
                  'People for ${c.name}',
                  [
                    for (final m in s.members)
                      if (m.isActive) (id: m.userId, label: m.name),
                  ],
                  c.memberIds.toSet(),
                );
                if (picked != null) {
                  await s.setCategoryLinks(c,
                      alsoParentIds: c.alsoParentIds,
                      memberIds: picked.toList());
                }
              },
            ),
            if (!canAddSub)
              ListTile(
                leading: const Icon(PhRegular.link,
                    size: 18, color: Nocturne.text),
                title: const Text('Also show under…',
                    style: TextStyle(fontSize: 14, color: Nocturne.text)),
                subtitle: Text(
                    _names([
                      for (final m in s.topCategories(c.kind))
                        if (c.alsoParentIds.contains(m.id)) m.name,
                    ], 'Use this subcategory in other categories too'),
                    style: const TextStyle(
                        fontSize: 11.5, color: Nocturne.neutral500)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _pickMany(
                    context,
                    'Show ${c.name} under',
                    [
                      for (final m in s.topCategories(c.kind))
                        if (m.id != c.parentId) (id: m.id, label: m.name),
                    ],
                    c.alsoParentIds.toSet(),
                  );
                  if (picked != null) {
                    await s.setCategoryLinks(c,
                        alsoParentIds: picked.toList(),
                        memberIds: c.memberIds);
                  }
                },
              ),
            ListTile(
              leading: const Icon(PhRegular.trash,
                  size: 18, color: NocturneSemantic.expense),
              title: const Text('Delete',
                  style: TextStyle(
                      fontSize: 14, color: NocturneSemantic.expense)),
              subtitle: Text(
                  canAddSub
                      ? 'Past entries stay but lose this category; its subcategories go too'
                      : 'Past entries stay but lose this subcategory',
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500)),
              onTap: () async {
                Navigator.pop(ctx);
                await s.deleteCategory(c.id);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static String _names(List<String> names, String empty) =>
      names.isEmpty ? empty : names.join(', ');

  /// Checkbox list; null when cancelled.
  static Future<Set<String>?> _pickMany(
    BuildContext context,
    String title,
    List<({String id, String label})> options,
    Set<String> initial,
  ) {
    final chosen = {...initial};
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: Nocturne.surface,
          title: Text(title,
              style: const TextStyle(fontSize: 17, color: Nocturne.text)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  CheckboxListTile(
                    value: chosen.contains(o.id),
                    title: Text(o.label,
                        style: const TextStyle(
                            fontSize: 14, color: Nocturne.text)),
                    activeColor: Nocturne.accent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setInner(() =>
                        v == true ? chosen.add(o.id) : chosen.remove(o.id)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, chosen),
              child: const Text('Save',
                  style: TextStyle(color: Nocturne.accent300)),
            ),
          ],
        ),
      ),
    );
  }
}
