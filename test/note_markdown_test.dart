import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/core/model/note_markdown.dart';
import 'package:devspace/features/notes/composer/attr_controller.dart';

String rt(String md) => NoteMarkdown.serialize(NoteMarkdown.parse(md));

void main() {
  group('markdown round trip', () {
    for (final md in [
      '# Title\n## Sub\nplain **bold** *it* ~~gone~~ ==hi== `code`',
      '- a\n  - b\n    - c\n1. one\n1. two',
      '- [ ] todo\n- [x] done',
      '> quote here\n```\nlet x = 1;\nlet y = 2;\n```\nafter',
      'snake_case_name and 2*3',
    ]) {
      test(md.split('\n').first, () => expect(rt(md), md.replaceAll('2*3', '2\\*3')));
    }
  });

  test('nested formats survive a round trip semantically', () {
    final a = NoteMarkdown.parse('**bold *and italic* mix**').single;
    final b = NoteMarkdown.parse(rt('**bold *and italic* mix**')).single;
    expect(b.text, a.text);
    expect(b.marks, a.marks);
  });

  test('parse produces real formats, no markers in text', () {
    final b = NoteMarkdown.parse('hello **bold** world').single;
    expect(b.text, 'hello bold world');
    expect(b.marks.sublist(6, 10), everyElement(Fmt.bold));
    expect(b.marks.sublist(0, 6), everyElement(0));
  });

  test('block types and todo state', () {
    final bs = NoteMarkdown.parse('# H\n- [x] t\n- b\n1. n\n> q');
    expect(bs.map((b) => b.type), [
      BlockType.h1, BlockType.todo, BlockType.bullet, BlockType.number, BlockType.quote,
    ]);
    expect(bs[1].checked, isTrue);
    expect(bs[1].text, 't');
  });

  test('plain preview strips markup and checklist lines', () {
    expect(NoteMarkdown.plain('# T\n**b** x\n- [ ] item'), 'T\nb x');
  });

  test('toggleTodoLine flips nth checkbox', () {
    expect(NoteMarkdown.toggleTodoLine('a\n- [ ] x\n- [ ] y', 1), 'a\n- [ ] x\n- [x] y');
  });

  test('tags / urls derived from text', () {
    final like = [const ParsedBlockLike('go #todo see https://a.io/x#frag.')];
    expect(NoteMarkdown.extractTags(like), ['#todo']);
    expect(NoteMarkdown.extractUrls(like), ['https://a.io/x#frag']);
  });

  group('AttrController', () {
    test('typing inherits format and keeps marks in sync', () {
      final c = AttrController(text: 'ab', marks: [Fmt.bold, Fmt.bold]);
      c.value = const TextEditingValue(
          text: 'aXb', selection: TextSelection.collapsed(offset: 2));
      expect(c.marks, [Fmt.bold, Fmt.bold, Fmt.bold]);
      c.value = const TextEditingValue(
          text: 'ab', selection: TextSelection.collapsed(offset: 1));
      expect(c.marks.length, 2);
    });

    test('toggleMark on selection and caret', () {
      final c = AttrController(text: 'hello');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      c.toggleMark(Fmt.italic);
      expect(c.marks, [Fmt.italic, Fmt.italic, 0, 0, 0]);
      c.toggleMark(Fmt.italic);
      expect(c.marks, everyElement(0));
      // caret-only: next typed char is bold
      c.selection = const TextSelection.collapsed(offset: 5);
      c.toggleMark(Fmt.bold);
      c.value = const TextEditingValue(
          text: 'hello!', selection: TextSelection.collapsed(offset: 6));
      expect(c.marks.last, Fmt.bold);
    });

    test('find and replace all keeps lengths consistent', () {
      final c = AttrController(text: 'foo bar foo');
      c.findQuery = 'foo';
      expect(c.matches.length, 2);
      c.replaceAllMatches('x');
      expect(c.text, 'x bar x');
      expect(c.marks.length, c.text.length);
    });
  });
}
