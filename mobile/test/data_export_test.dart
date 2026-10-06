import 'package:flutter_test/flutter_test.dart';

import 'package:family_finance/v3/data/data_export.dart';
import 'package:family_finance/v3/data/expense_import.dart';
import 'package:family_finance/v3/data/note_blocks.dart';
import 'package:family_finance/v3/data/v3_models.dart';

TxnRow _txn({
  required String title,
  required double amount,
  String type = 'expense',
  String categoryKey = 'food',
  DateTime? at,
  String? note,
}) =>
    TxnRow(
      id: 't-$title',
      familyId: 'f1',
      title: title,
      amount: amount,
      type: type,
      method: 'UPI',
      origin: 'manual',
      categoryKey: categoryKey,
      occurredAt: at ?? DateTime(2026, 1, 3),
      note: note,
    );

void main() {
  group('transactions CSV', () {
    test('writes a header and one line per transaction', () {
      final csv = DataExport.transactionsCsv([
        _txn(title: 'Coffee', amount: 120),
        _txn(title: 'Groceries', amount: 1240.5),
      ]);

      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('Date,Title,Amount'));
      expect(lines, hasLength(3));
    });

    test('a title containing a comma is quoted', () {
      final csv = DataExport.transactionsCsv([
        _txn(title: 'Coffee, large', amount: 120),
      ]);

      expect(csv, contains('"Coffee, large"'));
    });

    test('a title containing a quote is escaped', () {
      final csv = DataExport.transactionsCsv([
        _txn(title: 'He said "hi"', amount: 120),
      ]);

      expect(csv, contains('"He said ""hi"""'));
    });

    test('exported CSV can be read back by the importer', () {
      final original = [
        _txn(title: 'Coffee', amount: 120, at: DateTime(2026, 1, 3)),
        _txn(title: 'Groceries, weekly', amount: 1240.5, at: DateTime(2026, 1, 4)),
      ];

      final rows = ExpenseImport.parseCsv(DataExport.transactionsCsv(original));

      expect(rows, hasLength(2));
      expect(rows[0].title, 'Coffee');
      expect(rows[0].amount, 120);
      expect(rows[0].date, DateTime(2026, 1, 3));
      expect(rows[1].title, 'Groceries, weekly');
      expect(rows[1].amount, 1240.5);
    });

    test('income survives the round trip as income', () {
      final rows = ExpenseImport.parseCsv(DataExport.transactionsCsv([
        _txn(title: 'Salary', amount: 50000, type: 'income'),
      ]));

      expect(rows.single.isIncome, isTrue);
    });

    test('an empty list still yields a usable header', () {
      final csv = DataExport.transactionsCsv([]);

      expect(csv.trim().split('\n'), hasLength(1));
      expect(ExpenseImport.parseCsv(csv), isEmpty);
    });
  });

  group('notes Markdown', () {
    NoteRow note(String title, List<NoteBlock> blocks) => NoteRow(
          id: 'n1',
          title: title,
          content: '',
          pinned: false,
          blocks: blocks,
          updatedAt: DateTime(2026, 1, 3),
        );

    test('the title becomes a heading', () {
      final md = DataExport.noteMarkdown(note('Groceries', const []));

      expect(md, startsWith('# Groceries'));
    });

    test('headings and paragraphs are written', () {
      final md = DataExport.noteMarkdown(note('Trip', const [
        NoteBlock(id: 'b1', kind: NoteBlockKind.heading, text: 'Day one'),
        NoteBlock(id: 'b2', kind: NoteBlockKind.paragraph, text: 'Took a taxi'),
      ]));

      expect(md, contains('## Day one'));
      expect(md, contains('Took a taxi'));
    });

    test('todos keep their checked state', () {
      final md = DataExport.noteMarkdown(note('Chores', const [
        NoteBlock(id: 'b1', kind: NoteBlockKind.todo, items: [
          TodoItem(text: 'Pay rent', done: true),
          TodoItem(text: 'Call bank'),
        ]),
      ]));

      expect(md, contains('- [x] Pay rent'));
      expect(md, contains('- [ ] Call bank'));
    });

    test('tables are written as Markdown tables', () {
      final md = DataExport.noteMarkdown(note('Spend', const [
        NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.table,
          head: ['Item', 'Amount'],
          rows: [
            ['Coffee', '120'],
            ['Taxi', '300'],
          ],
        ),
      ]));

      expect(md, contains('| Item | Amount |'));
      expect(md, contains('| Coffee | 120 |'));
    });

    test('an exported table can be re-imported as expenses', () {
      final md = DataExport.noteMarkdown(note('Spend', const [
        NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.table,
          head: ['Item', 'Amount'],
          rows: [
            ['Coffee', '120'],
            ['Taxi', '300'],
          ],
        ),
      ]));

      final rows = ExpenseImport.parseMarkdown(md);

      expect(rows.map((r) => r.title), containsAll(['Coffee', 'Taxi']));
      expect(rows.map((r) => r.amount), containsAll([120.0, 300.0]));
    });

    test('a pipe inside a cell is escaped so the table stays valid', () {
      final md = DataExport.noteMarkdown(note('Spend', const [
        NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.table,
          head: ['Item', 'Amount'],
          rows: [
            ['Coffee | large', '120'],
          ],
        ),
      ]));

      expect(md, contains(r'Coffee \| large'));
    });

    test('several notes are separated by a rule', () {
      final md = DataExport.notesMarkdown([
        note('One', const [
          NoteBlock(id: 'b1', kind: NoteBlockKind.paragraph, text: 'first')
        ]),
        note('Two', const [
          NoteBlock(id: 'b2', kind: NoteBlockKind.paragraph, text: 'second')
        ]),
      ]);

      expect(md, contains('# One'));
      expect(md, contains('# Two'));
      expect(md, contains('---'));
    });
  });
}
