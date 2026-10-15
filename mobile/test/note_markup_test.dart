import 'package:family_finance/v3/screens/note_markup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextEditingValue sel(String text, int start, int end) => TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );

  /// (marker kind, inner text) for each top-level match.
  List<(String, String)> parse(String s) => [
    for (final m in MarkupController.pattern.allMatches(s))
      m[1] != null
          ? ('link', '${m[1]}|${m[2]}')
          : m[3] != null
          ? ('bold+italic', m[3]!)
          : m[4] != null
          ? ('bold', m[4]!)
          : m[5] != null
          ? ('strike', m[5]!)
          : m[6] != null
          ? ('underline', m[6]!)
          : ('italic', m[7]!),
  ];

  group('pattern', () {
    test('finds every marker kind', () {
      expect(parse('**b** *i* ~~s~~ __u__ [site](https://a.com)'), [
        ('bold', 'b'),
        ('italic', 'i'),
        ('strike', 's'),
        ('underline', 'u'),
        ('link', 'site|https://a.com'),
      ]);
    });

    test('underline and italic/bold do not interfere', () {
      expect(parse('__a__ and **b**'), [('underline', 'a'), ('bold', 'b')]);
      expect(parse('**__both__**'), [('bold', '__both__')]);
      expect(parse('*x* __y__'), [('italic', 'x'), ('underline', 'y')]);
      // Single underscores (snake_case) are left alone.
      expect(parse('my_var and other_thing'), isEmpty);
    });

    test('markers inside a URL do not start formatting', () {
      expect(parse('[doc](https://x.com/a__b__c*d*)'), [
        ('link', 'doc|https://x.com/a__b__c*d*'),
      ]);
    });

    test('AI-style text with existing markers still parses', () {
      expect(parse('Buy **milk** and ~~eggs~~, *maybe* bread'), [
        ('bold', 'milk'),
        ('strike', 'eggs'),
        ('italic', 'maybe'),
      ]);
    });
  });

  group('toggleMark', () {
    test('underline wraps and unwraps', () {
      final u = toggleMark(sel('buy milk', 4, 8), '__');
      expect(u.text, 'buy __milk__');
      expect(toggleMark(u, '__').text, 'buy milk');
    });

    test('unwraps when the selection sits just inside hidden markers', () {
      // "milk" selected inside **milk**.
      expect(toggleMark(sel('buy **milk** now', 6, 10), '**').text,
          'buy milk now');
      expect(toggleMark(sel('a __u__ b', 4, 5), '__').text, 'a u b');
    });

    test('italic does not eat half of a bold marker; *** toggles apart', () {
      final both = toggleMark(sel('**milk**', 2, 6), '*');
      expect(both.text, '***milk***');
      expect(parse(both.text), [('bold+italic', 'milk')]);
      expect(toggleMark(sel('***milk***', 3, 7), '*').text, '**milk**');
      expect(toggleMark(sel('***milk***', 3, 7), '**').text, '*milk*');
    });

    test('collapsed caret inside an empty pair removes it', () {
      final r = toggleMark(
        const TextEditingValue(
          text: 'a____b',
          selection: TextSelection.collapsed(offset: 3),
        ),
        '__',
      );
      expect(r.text, 'ab');
    });
  });

  group('links', () {
    test('insertLink uses the selection as label', () {
      final r = insertLink(sel('see docs here', 4, 8), 'example.com');
      expect(r.text, 'see [docs](https://example.com) here');
      expect(r.selection.baseOffset, 'see [docs](https://example.com)'.length);
    });

    test('insertLink with no selection uses the URL as label', () {
      final r = insertLink(
        const TextEditingValue(
          text: 'x ',
          selection: TextSelection.collapsed(offset: 2),
        ),
        'https://a.com',
      );
      expect(r.text, 'x [https://a.com](https://a.com)');
    });

    test('empty URL changes nothing', () {
      final v = sel('abc', 0, 1);
      expect(insertLink(v, '  ').text, 'abc');
    });

    test('linkAt finds the link under an offset, also when nested', () {
      const t = 'go **[here](https://a.com)** or [there](b.org)';
      expect(linkAt(t, t.indexOf('here')), 'https://a.com');
      expect(linkAt(t, t.indexOf('ere')), 'https://a.com');
      expect(linkAt(t, t.indexOf('there') + 4), 'b.org');
      expect(linkAt(t, 0), isNull);
      // The hidden (url) part is not a tap target.
      expect(linkAt(t, t.indexOf('https')), isNull);
    });

    test('normalizeUrl and safeLinkUri', () {
      expect(normalizeUrl(' kinpurse.app '), 'https://kinpurse.app');
      expect(normalizeUrl('mailto:a@b.c'), 'mailto:a@b.c');
      expect(safeLinkUri('https://a.com'), isNotNull);
      expect(safeLinkUri('tel:123'), isNotNull);
      expect(safeLinkUri('javascript:alert(1)'), isNull);
      expect(safeLinkUri('file:///etc/passwd'), isNull);
    });
  });

  testWidgets('renders every marker kind, nested, without errors', (t) async {
    final c = MarkupController(
      text: '**b __u ~~s~~__** ***bi*** [l](https://a.com) [x](javascript:y)',
    );
    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: TextField(controller: c))),
    );
    expect(t.takeException(), isNull);
    final span = c.buildTextSpan(
      context: t.element(find.byType(EditableText)),
      withComposing: false,
    );
    final plain = span.toPlainText();
    // Markers stay in the text (hidden), so offsets match the stored string.
    expect(plain, c.text);
    c.dispose();
  });
}
