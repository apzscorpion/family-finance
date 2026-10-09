import 'package:family_finance/v3/data/note_blocks.dart';
import 'package:family_finance/v3/screens/note_ai_chat.dart';
import 'package:family_finance/v3/screens/note_markup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextEditingValue sel(String text, int start, int end) => TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: start, extentOffset: end),
      );

  test('toggleMark wraps the selection and unwraps it again', () {
    final bold = toggleMark(sel('buy milk now', 4, 8), '**');
    expect(bold.text, 'buy **milk** now');
    expect(bold.selection.textInside(bold.text), '**milk**');
    expect(toggleMark(bold, '**').text, 'buy milk now');
    // Nothing selected: unchanged.
    expect(toggleMark(sel('abc', 1, 1), '~~').text, 'abc');
  });

  test('carryOver keeps ids and ticked-by on untouched blocks and lines', () {
    final old = [
      NoteBlock.heading('Trip'),
      NoteBlock.todoItems(const [
        TodoItem(text: 'Tickets', done: true, byUserId: 'u1'),
        TodoItem(text: 'Hotel'),
      ]),
    ];
    final fromAi = [
      NoteBlock.heading('Trip to Kochi'),
      NoteBlock.todoItems(const [
        TodoItem(text: 'Tickets', done: true),
        TodoItem(text: 'Hotel near beach'),
      ]),
      NoteBlock.paragraph('New'),
    ];
    final merged = carryOver(old, fromAi);

    expect(merged[0].id, old[0].id);
    expect(merged[0].text, 'Trip to Kochi');
    expect(merged[1].id, old[1].id);
    expect(merged[1].items[0].byUserId, 'u1');
    expect(merged[1].items[1].text, 'Hotel near beach');
    expect(merged[2].id, fromAi[2].id);

    expect(sameBlocks(old, carryOver(old, old)), isTrue);
    expect(sameBlocks(old, merged), isFalse);
  });
}
