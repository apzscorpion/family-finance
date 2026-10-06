import 'package:family_finance/v3/data/note_blocks.dart';
import 'package:family_finance/v3/data/note_structure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<NoteBlock> parse(String raw) => NoteStructure.parse(raw);

  /// The headline behaviour: separate lines become separate checkboxes.
  group('bare lines become a checklist', () {
    test('a plain shopping list', () {
      final blocks = parse('Milk\nEggs\nBread');

      expect(blocks, hasLength(1));
      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(
        blocks.single.items.map((i) => i.text),
        ['Milk', 'Eggs', 'Bread'],
      );
      expect(blocks.single.items.every((i) => !i.done), isTrue);
    });

    test('an itinerary with colons', () {
      final blocks = parse(
        'Day 1: Arrive at Tokyo NRT\n'
        'Day 2: Tokyo-Modern Tokyo\n'
        'Day 3: Tokyo-Traditional Tokyo',
      );

      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(blocks.single.items, hasLength(3));
      expect(blocks.single.items.first.text, 'Day 1: Arrive at Tokyo NRT');
    });

    test('a single line stays a paragraph', () {
      final blocks = parse('Just one thing');

      expect(blocks.single.kind, NoteBlockKind.paragraph);
    });

    test('prose is not shredded into checkboxes', () {
      final blocks = parse(
        'Started the day feeling like I might bail on everything, but '
        'somehow ended up on a date that did not implode.\n'
        'I picked ice cream because it felt easy, not romantic, and the '
        'sunset showed up like it had something to prove.',
      );

      expect(blocks.single.kind, NoteBlockKind.paragraph);
    });

    test('lines ending in full stops are treated as prose', () {
      final blocks = parse(
        'The meeting went well.\n'
        'We agreed on the budget.\n'
        'Next review is in March.',
      );

      expect(blocks.single.kind, NoteBlockKind.paragraph);
    });

    test('a blank line separates two checklists', () {
      final blocks = parse('Milk\nEggs\n\nHammer\nNails');

      expect(blocks, hasLength(2));
      expect(blocks.every((b) => b.kind == NoteBlockKind.todo), isTrue);
      expect(blocks.first.items, hasLength(2));
      expect(blocks.last.items.map((i) => i.text), ['Hammer', 'Nails']);
    });

    test('strips zero-width and non-breaking characters from web copies', () {
      final blocks = parse('​Milk​\nEggs \nBread');

      expect(blocks.single.items.map((i) => i.text), ['Milk', 'Eggs', 'Bread']);
    });

    test('handles Windows line endings', () {
      final blocks = parse('Milk\r\nEggs\r\nBread');

      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(blocks.single.items, hasLength(3));
    });
  });

  group('marked lists', () {
    test('markdown checkboxes keep their done state', () {
      final blocks = parse('- [x] Book flights\n- [ ] Pack bags\n- [X] Visa');

      final items = blocks.single.items;
      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(items.map((i) => i.text), ['Book flights', 'Pack bags', 'Visa']);
      expect(items.map((i) => i.done), [true, false, true]);
    });

    test('bullets of several shapes', () {
      final blocks = parse('- One\n* Two\n• Three\n+ Four');

      expect(blocks.single.items.map((i) => i.text),
          ['One', 'Two', 'Three', 'Four']);
    });

    test('numbered lists drop the numbering', () {
      final blocks = parse('1. First\n2) Second\n(3) Third');

      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(blocks.single.items.map((i) => i.text),
          ['First', 'Second', 'Third']);
    });

    test('a bulleted item longer than the bare-line limit still counts', () {
      final long = 'x' * 200;
      final blocks = parse('- $long\n- short');

      expect(blocks.single.kind, NoteBlockKind.todo);
      expect(blocks.single.items.first.text, long);
    });
  });

  group('headings', () {
    test('markdown headings at every level', () {
      final blocks = parse('# Title\nsome words here that run on a while\n'
          '### Sub');

      expect(blocks.first.kind, NoteBlockKind.heading);
      expect(blocks.first.text, 'Title');
      expect(blocks.last.kind, NoteBlockKind.heading);
      expect(blocks.last.text, 'Sub');
    });

    test('setext underlines', () {
      final blocks = parse('Japan Itinerary\n===============');

      expect(blocks.single.kind, NoteBlockKind.heading);
      expect(blocks.single.text, 'Japan Itinerary');
    });
  });

  group('tables', () {
    test('a markdown pipe table', () {
      final blocks = parse(
        '| Item | Amount |\n'
        '|------|--------|\n'
        '| Rice | 120 |\n'
        '| Oil  | 240 |',
      );

      final table = blocks.single;
      expect(table.kind, NoteBlockKind.table);
      expect(table.head, ['Item', 'Amount']);
      expect(table.rows, [
        ['Rice', '120'],
        ['Oil', '240'],
      ]);
    });

    test('a tab-separated paste from a spreadsheet', () {
      final blocks = parse('Item\tAmount\nRice\t120\nOil\t240');

      expect(blocks.single.kind, NoteBlockKind.table);
      expect(blocks.single.head, ['Item', 'Amount']);
      expect(blocks.single.rows, hasLength(2));
    });

    test('CSV needs three fields before it counts as a table', () {
      final blocks = parse('Rice, 120, Kg\nOil, 240, L');

      expect(blocks.single.kind, NoteBlockKind.table);
      expect(blocks.single.head, ['Rice', '120', 'Kg']);
    });

    test('a sentence with two commas is not a table', () {
      final blocks = parse('I bought rice, oil\nand then went home');

      expect(blocks.single.kind, isNot(NoteBlockKind.table));
    });

    test('ragged rows are padded to the header width', () {
      final blocks = parse('| A | B | C |\n| 1 | 2 |\n| 3 | 4 | 5 |');

      expect(blocks.single.rows.every((r) => r.length == 3), isTrue);
      expect(blocks.single.rows.first, ['1', '2', '']);
    });
  });

  group('mixed documents', () {
    test('a heading, prose and a checklist in one paste', () {
      final blocks = parse(
        '# Trip plan\n'
        '\n'
        'We should sort the flights out before the end of the month, '
        'otherwise prices climb.\n'
        '\n'
        '- [ ] Book flights\n'
        '- [ ] Hotel\n',
      );

      expect(blocks.map((b) => b.kind), [
        NoteBlockKind.heading,
        NoteBlockKind.paragraph,
        NoteBlockKind.todo,
      ]);
    });

    test('empty input still yields one editable block', () {
      expect(parse('').single.kind, NoteBlockKind.paragraph);
      expect(parse('   \n  \n').single.kind, NoteBlockKind.paragraph);
    });
  });

  group('conversions', () {
    test('a colon-separated checklist becomes a two-column table', () {
      final todo = parse('Day 1: Tokyo\nDay 2: Kyoto\nDay 3: Osaka').single;
      final table = NoteStructure.toTable(todo);

      expect(table.kind, NoteBlockKind.table);
      expect(table.head, ['Item', 'Detail']);
      expect(table.rows, [
        ['Day 1', 'Tokyo'],
        ['Day 2', 'Kyoto'],
        ['Day 3', 'Osaka'],
      ]);
    });

    test('a dash-separated checklist splits on the dash', () {
      final todo = parse('Rice - 120\nOil - 240').single;
      final table = NoteStructure.toTable(todo);

      expect(table.rows, [
        ['Rice', '120'],
        ['Oil', '240'],
      ]);
    });

    test('a plain checklist becomes a single column', () {
      final todo = parse('Milk\nEggs\nBread').single;
      final table = NoteStructure.toTable(todo);

      expect(table.head, ['Item']);
      expect(table.rows, [
        ['Milk'],
        ['Eggs'],
        ['Bread'],
      ]);
    });

    test('a table converts back to a checklist', () {
      final table = parse('Item\tAmount\nRice\t120\nOil\t240').single;
      final todo = NoteStructure.toTodo(table);

      expect(todo.kind, NoteBlockKind.todo);
      expect(todo.items.map((i) => i.text),
          ['Rice · 120', 'Oil · 240']);
    });

    test('round-tripping a separable checklist preserves the text', () {
      final original = parse('Day 1: Tokyo\nDay 2: Kyoto').single;
      final back = NoteStructure.toTodo(NoteStructure.toTable(original));

      expect(back.items.map((i) => i.text),
          ['Day 1 · Tokyo', 'Day 2 · Kyoto']);
    });

    test('a paragraph splits into one item per line', () {
      final paragraph = NoteBlock.paragraph('Alpha\nBeta\nGamma');
      final todo = NoteStructure.toTodo(paragraph);

      expect(todo.items.map((i) => i.text), ['Alpha', 'Beta', 'Gamma']);
    });

    test('anything flattens back to a paragraph', () {
      final todo = parse('Milk\nEggs').single;

      expect(NoteStructure.toParagraph(todo).kind, NoteBlockKind.paragraph);
      expect(NoteStructure.toParagraph(todo).text, contains('Milk'));
    });

    test('converting an empty checklist yields an empty table', () {
      final empty = NoteBlock.todoItems(const [TodoItem(text: '')]);

      expect(NoteStructure.toTable(empty).kind, NoteBlockKind.table);
    });
  });
}
