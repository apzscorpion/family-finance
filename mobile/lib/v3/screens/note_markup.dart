import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';

/// Inline formatting for note text, stored as markdown-style markers:
/// `**bold**`, `*italic*`, `~~strike~~`.
///
/// Markers stay in the text (so storage, sync, search and AI all keep working
/// on plain strings) and are only styled here: dimmed markers, formatted
/// content.
class MarkupController extends TextEditingController {
  MarkupController({super.text});

  static final _pattern = RegExp(
    r'\*\*(.+?)\*\*|~~(.+?)~~|(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // While the keyboard is composing a word, keep the default span so the
    // composing underline still lines up.
    if ((withComposing && value.isComposingRangeValid) ||
        !text.contains(RegExp(r'[*~]'))) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final marker = TextStyle(color: Nocturne.palette.faint);
    // Markers show only around the caret, where they are being edited;
    // elsewhere they take no space, so **bold** reads as bold.
    const hidden = TextStyle(
        color: Color(0x00000000), fontSize: 0.1, letterSpacing: 0);
    final caret = selection.isValid ? selection.baseOffset : -1;
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final (mark, inner, look) = m[1] != null
          ? ('**', m[1]!, const TextStyle(fontWeight: FontWeight.w700))
          : m[2] != null
          ? (
              '~~',
              m[2]!,
              TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationColor: Nocturne.palette.subtle,
              ),
            )
          : ('*', m[3]!, const TextStyle(fontStyle: FontStyle.italic));
      final edge = caret >= m.start && caret <= m.end ? marker : hidden;
      spans
        ..add(TextSpan(text: mark, style: edge))
        ..add(TextSpan(text: inner, style: look))
        ..add(TextSpan(text: mark, style: edge));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}

/// Wraps (or unwraps) the selection in [mark]. Pure, so it can be tested.
TextEditingValue toggleMark(TextEditingValue value, String mark) {
  final sel = value.selection;
  if (!sel.isValid || sel.isCollapsed) return value;
  final inner = sel.textInside(value.text);
  final wrapped =
      inner.length >= mark.length * 2 &&
      inner.startsWith(mark) &&
      inner.endsWith(mark);
  final replaced = wrapped
      ? inner.substring(mark.length, inner.length - mark.length)
      : '$mark$inner$mark';
  return TextEditingValue(
    text: sel.textBefore(value.text) + replaced + sel.textAfter(value.text),
    selection: TextSelection(
      baseOffset: sel.start,
      extentOffset: sel.start + replaced.length,
    ),
  );
}

/// Bold / Italic / Strike buttons for the text selection menu. Going through
/// `userUpdateTextEditingValue` fires the field's `onChanged`, so the block
/// saves like any other edit.
List<ContextMenuButtonItem> formatButtons(EditableTextState state) {
  final sel = state.textEditingValue.selection;
  if (!sel.isValid || sel.isCollapsed) return const [];
  ContextMenuButtonItem button(String label, String mark) =>
      ContextMenuButtonItem(
        label: label,
        onPressed: () {
          state.userUpdateTextEditingValue(
            toggleMark(state.textEditingValue, mark),
            SelectionChangedCause.toolbar,
          );
          ContextMenuController.removeAny();
        },
      );
  return [button('Bold', '**'), button('Italic', '*'), button('Strike', '~~')];
}

/// Default selection menu plus the formatting buttons.
Widget formatContextMenu(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [...formatButtons(state), ...state.contextMenuButtonItems],
    );
