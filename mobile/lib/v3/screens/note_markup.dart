import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/nocturne.dart';

/// Inline formatting for note text, stored as markdown-style markers:
/// `**bold**`, `*italic*`, `~~strike~~`, `__underline__` and `[text](url)`.
///
/// Markers stay in the text (so storage, sync, search and AI all keep working
/// on plain strings) and are only styled here: dimmed markers, formatted
/// content.
class MarkupController extends TextEditingController {
  MarkupController({super.text});

  /// Groups: 1-2 link text/url, 3 bold+italic, 4 bold, 5 strike,
  /// 6 underline, 7 italic. The link comes first so `_` or `*` inside a URL
  /// never starts a marker.
  static final pattern = RegExp(
    r'\[([^\]\n]+)\]\(([^)\s]+)\)|(?<!\*)\*\*\*(?!\*)(.+?)\*\*\*(?!\*)|\*\*(.+?)\*\*|~~(.+?)~~|__(.+?)__|(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
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
        !text.contains(RegExp(r'[*~_\[]'))) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final caret = selection.isValid ? selection.baseOffset : -1;
    return TextSpan(
      style: style,
      children: _spans(text, 0, caret, const {}),
    );
  }

  List<InlineSpan> _spans(
    String s,
    int base,
    int caret,
    Set<TextDecoration> decos,
  ) {
    final p = Nocturne.palette;
    final marker = TextStyle(color: p.faint);
    // Markers show only around the caret, where they are being edited;
    // elsewhere they take no space, so **bold** reads as bold.
    const hidden = TextStyle(
      color: Color(0x00000000),
      fontSize: 0.1,
      letterSpacing: 0,
    );
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final near = caret >= base + m.start && caret <= base + m.end;
      final edge = near ? marker : hidden;
      if (m[1] != null) {
        // Opening is handled by [LinkTapArea]; span recognizers are not
        // allowed in editable text (semantics asserts).
        out
          ..add(TextSpan(text: '[', style: edge))
          ..add(
            TextSpan(
              text: m[1],
              style: TextStyle(
                color: p.accentLight,
                decoration: TextDecoration.combine([
                  ...decos,
                  TextDecoration.underline,
                ]),
                decorationColor: p.accentLight,
              ),
            ),
          )
          ..add(TextSpan(text: '](${m[2]})', style: edge));
      } else {
        final (mark, inner, deco) = m[3] != null
            ? ('***', m[3]!, null)
            : m[4] != null
            ? ('**', m[4]!, null)
            : m[5] != null
            ? ('~~', m[5]!, TextDecoration.lineThrough)
            : m[6] != null
            ? ('__', m[6]!, TextDecoration.underline)
            : ('*', m[7]!, null);
        final next = deco == null ? decos : {...decos, deco};
        out
          ..add(TextSpan(text: mark, style: edge))
          ..add(
            TextSpan(
              style: TextStyle(
                fontWeight: mark.startsWith('**') ? FontWeight.w700 : null,
                fontStyle: mark == '*' || mark == '***'
                    ? FontStyle.italic
                    : null,
                decoration: deco == null
                    ? null
                    : TextDecoration.combine(next.toList()),
                decorationColor: next.contains(TextDecoration.lineThrough)
                    ? p.subtle
                    : null,
              ),
              // Nested markers (bold inside underline, ...) style too.
              children: _spans(
                inner,
                base + m.start + mark.length,
                caret,
                next,
              ),
            ),
          )
          ..add(TextSpan(text: mark, style: edge));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }
}

final _link = RegExp(r'\[([^\]\n]+)\]\(([^)\s]+)\)');

/// The URL of the `[label](url)` whose label covers [offset], if any. Pure.
String? linkAt(String text, int offset) {
  for (final m in _link.allMatches(text)) {
    final start = m.start + 1;
    if (offset >= start && offset < start + m[1]!.length) return m[2];
  }
  return null;
}

/// Opens a link tapped in the text field inside [child] while that field is
/// not being edited; while editing, taps just move the caret as usual.
/// Listens to raw pointers so the field's own gestures are untouched.
class LinkTapArea extends StatefulWidget {
  final Widget child;

  const LinkTapArea({super.key, required this.child});

  @override
  State<LinkTapArea> createState() => _LinkTapAreaState();
}

class _LinkTapAreaState extends State<LinkTapArea> {
  Offset? _down;
  RenderEditable? _editable;

  RenderEditable? _find() {
    RenderEditable? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderEditable) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    final root = context.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      final r = _find();
      // Only when not editing: the caret moving there is the edit gesture.
      _editable = r != null && !r.hasFocus ? r : null;
      _down = e.position;
    },
    onPointerUp: (e) {
      final r = _editable, down = _down;
      _editable = null;
      if (r == null || down == null || !r.attached) return;
      if ((e.position - down).distance > kTouchSlop) return;
      final text = r.text?.toPlainText() ?? '';
      final url = linkAt(text, r.getPositionForPoint(e.position).offset);
      if (url != null) openLink(url);
    },
    child: widget.child,
  );
}

/// Only web, mail and phone links open; anything else (javascript:, file:,
/// ...) written by a collaborator or the AI is shown but inert.
Uri? safeLinkUri(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
          const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme)
      ? uri
      : null;
}

Future<void> openLink(String url) async {
  final uri = safeLinkUri(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Adds `https://` when the user typed a bare domain.
String normalizeUrl(String raw) {
  final url = raw.trim().replaceAll(RegExp(r'\s'), '');
  if (url.isEmpty) return '';
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url)
      ? url
      : 'https://$url';
}

/// Wraps (or unwraps) the selection in [mark]. With no selection it inserts
/// an empty pair and puts the caret inside, so typing continues formatted.
/// Pure, so it can be tested.
TextEditingValue toggleMark(TextEditingValue value, String mark) {
  final sel = value.selection;
  if (!sel.isValid) return value;
  final text = value.text;
  final before = sel.textBefore(text);
  final inner = sel.textInside(text);
  final after = sel.textAfter(text);
  // Markers are hidden, so a selection usually sits just inside them. Only
  // unwrap a run that is exactly this mark, or `***` (bold + italic), so `*`
  // (italic) never eats half of a `**` (bold).
  final c = mark[0];
  var runBefore = 0, runAfter = 0;
  while (runBefore < before.length &&
      before[before.length - 1 - runBefore] == c) {
    runBefore++;
  }
  while (runAfter < after.length && after[runAfter] == c) {
    runAfter++;
  }
  final run = runBefore < runAfter ? runBefore : runAfter;
  if (run >= mark.length && (run == mark.length || run == 3)) {
    final start = sel.start - mark.length;
    return TextEditingValue(
      text: before.substring(0, start) + inner + after.substring(mark.length),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + inner.length,
      ),
    );
  }
  final wrapped =
      inner.length >= mark.length * 2 &&
      inner.startsWith(mark) &&
      inner.endsWith(mark);
  final replaced = wrapped
      ? inner.substring(mark.length, inner.length - mark.length)
      : '$mark$inner$mark';
  return TextEditingValue(
    text: before + replaced + after,
    selection: sel.isCollapsed
        ? TextSelection.collapsed(offset: sel.start + mark.length)
        : TextSelection(
            baseOffset: sel.start,
            extentOffset: sel.start + replaced.length,
          ),
  );
}

/// Replaces the selection with `[label](url)`; the label is the selected
/// text, or the URL itself when nothing is selected. Pure.
TextEditingValue insertLink(TextEditingValue value, String url) {
  final link = normalizeUrl(url);
  if (link.isEmpty) return value;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final picked = sel.textInside(value.text).trim();
  final label = (picked.isEmpty ? link : picked).replaceAll(
    RegExp(r'[\[\]\n]'),
    '',
  );
  final md = '[$label]($link)';
  return TextEditingValue(
    text: sel.textBefore(value.text) + md + sel.textAfter(value.text),
    selection: TextSelection.collapsed(offset: sel.start + md.length),
  );
}

/// Bold / Italic / Underline / Strike buttons for the text selection menu.
/// Going through `userUpdateTextEditingValue` fires the field's `onChanged`,
/// so the block saves like any other edit.
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
  return [
    button('Bold', '**'),
    button('Italic', '*'),
    button('Underline', '__'),
    button('Strike', '~~'),
  ];
}

/// Default selection menu plus the formatting buttons.
Widget formatContextMenu(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [...formatButtons(state), ...state.contextMenuButtonItems],
    );
