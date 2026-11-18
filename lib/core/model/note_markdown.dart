/// Internal markdown <-> block conversion for notes.
///
/// The editor never shows markdown syntax: it edits [ParsedBlock]s (text plus
/// a per-character format bitmask) and only (de)serializes to markdown for
/// storage, so notes stay portable and compatible with older plain notes.
library;

/// Inline format bits stored per UTF-16 code unit.
class Fmt {
  static const int bold = 1;
  static const int italic = 2;
  static const int strike = 4;
  static const int code = 8;
  static const int mark = 16;
}

enum BlockType { paragraph, h1, h2, bullet, number, todo, quote, code }

class ParsedBlock {
  ParsedBlock({
    this.type = BlockType.paragraph,
    this.indent = 0,
    this.checked = false,
    this.text = '',
    List<int>? marks,
  }) : marks = marks ?? List<int>.filled(text.length, 0);

  BlockType type;
  int indent;
  bool checked;
  String text;
  List<int> marks;

  bool get isList =>
      type == BlockType.bullet || type == BlockType.number || type == BlockType.todo;
}

final RegExp _tagRe = RegExp(r'(?<![\w&/#])#[A-Za-z][\w-]*');
final RegExp kUrlRegex = RegExp(r'https?://[^\s<>()\[\]]+');
final RegExp _todoLine = RegExp(r'^(\s*)[-*+]\s+\[([ xX])\]\s?(.*)$');

class NoteMarkdown {
  NoteMarkdown._();

  static const String _escapable = r'\*_`~=#[]-+>.';

  // ---------------------------------------------------------------------------
  // Parse
  // ---------------------------------------------------------------------------

  static List<ParsedBlock> parse(String md) {
    final lines = md.replaceAll('\r\n', '\n').split('\n');
    final out = <ParsedBlock>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++;
        out.add(ParsedBlock(type: BlockType.code, text: buf.join('\n')));
        continue;
      }
      i++;
      out.add(_parseLine(line));
    }
    if (out.isEmpty) out.add(ParsedBlock());
    return out;
  }

  static int _indentOf(String ws) {
    final n = ws.replaceAll('\t', '  ').length;
    return (n ~/ 2).clamp(0, 3);
  }

  static ParsedBlock _inline(BlockType t, String s,
      {int indent = 0, bool checked = false}) {
    final r = parseInline(s);
    return ParsedBlock(
      type: t,
      indent: indent,
      checked: checked,
      text: r.$1,
      marks: r.$2,
    );
  }

  static ParsedBlock _parseLine(String line) {
    var m = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (m != null) {
      return _inline(m.group(1)!.length == 1 ? BlockType.h1 : BlockType.h2, m.group(2)!);
    }
    m = _todoLine.firstMatch(line);
    if (m != null) {
      return _inline(BlockType.todo, m.group(3)!,
          indent: _indentOf(m.group(1)!), checked: m.group(2)!.toLowerCase() == 'x');
    }
    m = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
    if (m != null) {
      return _inline(BlockType.bullet, m.group(2)!, indent: _indentOf(m.group(1)!));
    }
    m = RegExp(r'^(\s*)\d+[.)]\s+(.*)$').firstMatch(line);
    if (m != null) {
      return _inline(BlockType.number, m.group(2)!, indent: _indentOf(m.group(1)!));
    }
    m = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
    if (m != null) return _inline(BlockType.quote, m.group(1)!);
    return _inline(BlockType.paragraph, line);
  }

  static bool _isWord(String c) => RegExp(r'\w').hasMatch(c);

  /// Parses inline markers into plain text + per-character marks.
  static (String, List<int>) parseInline(String s) {
    final sb = StringBuffer();
    final marks = <int>[];
    var active = 0;
    void add(String ch, [int extra = 0]) {
      sb.write(ch);
      marks.add(active | extra);
    }

    bool dbl(String tok, int bit, int i) {
      // Returns true when consumed.
      if (!s.startsWith(tok, i)) return false;
      if (active & bit != 0) {
        active &= ~bit;
        return true;
      }
      if (s.indexOf(tok, i + 2) > i + 1) {
        active |= bit;
        return true;
      }
      return false;
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length && _escapable.contains(s[i + 1])) {
        add(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '`') {
        final end = s.indexOf('`', i + 1);
        if (end > i + 1) {
          for (var k = i + 1; k < end; k++) {
            add(s[k], Fmt.code);
          }
          i = end + 1;
          continue;
        }
      }
      if (dbl('**', Fmt.bold, i)) {
        i += 2;
        continue;
      }
      if (dbl('~~', Fmt.strike, i)) {
        i += 2;
        continue;
      }
      if (dbl('==', Fmt.mark, i)) {
        i += 2;
        continue;
      }
      if (c == '*' || c == '_') {
        if (active & Fmt.italic != 0) {
          final next = i + 1 < s.length ? s[i + 1] : '';
          if (c == '*' || next.isEmpty || !_isWord(next)) {
            active &= ~Fmt.italic;
            i++;
            continue;
          }
        } else {
          final prev = i > 0 ? s[i - 1] : '';
          final next = i + 1 < s.length ? s[i + 1] : '';
          final canOpen = next.isNotEmpty &&
              next.trim().isNotEmpty &&
              (c == '*' || prev.isEmpty || !_isWord(prev)) &&
              s.indexOf(c, i + 2) > 0;
          if (canOpen) {
            active |= Fmt.italic;
            i++;
            continue;
          }
        }
      }
      if (c == '[') {
        final lm = RegExp(r'\[([^\]\n]*)\]\(([^)\n]*)\)').matchAsPrefix(s, i);
        if (lm != null) {
          final t = lm.group(1)!, u = lm.group(2)!;
          final shown = (t.isEmpty || t == u) ? u : '$t ($u)';
          for (final ch in shown.split('')) {
            add(ch);
          }
          i = lm.end;
          continue;
        }
      }
      add(c);
      i++;
    }
    return (sb.toString(), marks);
  }

  // ---------------------------------------------------------------------------
  // Serialize
  // ---------------------------------------------------------------------------

  static String serialize(List<ParsedBlock> blocks) {
    final lines = <String>[];
    for (final b in blocks) {
      final pad = '  ' * b.indent;
      switch (b.type) {
        case BlockType.code:
          lines.add('```\n${b.text}\n```');
        case BlockType.h1:
          lines.add('# ${_inlineOut(b)}');
        case BlockType.h2:
          lines.add('## ${_inlineOut(b)}');
        case BlockType.bullet:
          lines.add('$pad- ${_inlineOut(b)}');
        case BlockType.number:
          lines.add('${pad}1. ${_inlineOut(b)}');
        case BlockType.todo:
          lines.add('$pad- [${b.checked ? 'x' : ' '}] ${_inlineOut(b)}');
        case BlockType.quote:
          lines.add('> ${_inlineOut(b)}');
        case BlockType.paragraph:
          var t = _inlineOut(b);
          if (RegExp(r'^(\s*(#{1,6}\s|[-*+]\s|>|\d+[.)]\s)|```)').hasMatch(t)) {
            t = '\\$t';
          }
          lines.add(t);
      }
    }
    return lines.join('\n').trimRight();
  }

  static String _escAt(String t, int i) {
    final c = t[i];
    final prev = i > 0 ? t[i - 1] : '';
    final next = i + 1 < t.length ? t[i + 1] : '';
    if (c == r'\' || c == '*' || c == '`') return '\\$c';
    if ((c == '~' || c == '=') && (next == c || prev == c)) return '\\$c';
    if (c == '_' && (prev.isEmpty || !_isWord(prev)) && next.trim().isNotEmpty) {
      return '\\_';
    }
    return c;
  }

  static const List<(int, String)> _scoped = [
    (Fmt.bold, '**'),
    (Fmt.italic, '*'),
    (Fmt.strike, '~~'),
    (Fmt.mark, '=='),
  ];

  /// Emits scoped open/close markers per format. Markers never touch
  /// whitespace (so other markdown renderers accept them) and a format that
  /// spans several differently-formatted runs stays one scope.
  static String _inlineOut(ParsedBlock b) {
    final t = b.text;
    if (t.isEmpty) return '';
    final marks = b.marks.length == t.length ? b.marks : List<int>.filled(t.length, 0);
    final out = <String>[];
    var lastContent = -1; // index in [out] of the last non-whitespace token
    var open = 0;

    void close(int bit, String marker) {
      out.insert(lastContent + 1, marker);
      lastContent++;
      open &= ~bit;
    }

    var i = 0;
    while (i < t.length) {
      final m = marks[i];
      final isCode = m & Fmt.code != 0;
      var j = i + 1;
      if (isCode) {
        while (j < t.length && marks[j] == m) {
          j++;
        }
      }
      final isWs = !isCode && t[i].trim().isEmpty;

      for (final (bit, marker) in _scoped) {
        final want = m & bit != 0;
        if (!want && open & bit != 0) {
          close(bit, marker);
        } else if (want && open & bit == 0 && !isWs) {
          out.add(marker);
          open |= bit;
        }
      }

      if (isCode) {
        out.add('`${t.substring(i, j).replaceAll('`', "'")}`');
        lastContent = out.length - 1;
      } else {
        out.add(_escAt(t, i));
        if (!isWs) lastContent = out.length - 1;
      }
      i = j;
    }
    for (final (bit, marker) in _scoped.reversed) {
      if (open & bit != 0) close(bit, marker);
    }
    return out.join();
  }

  // ---------------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------------

  static List<String> extractTags(Iterable<ParsedBlockLike> blocks) {
    final out = <String>[];
    for (final b in blocks) {
      if (b.isCode) continue;
      for (final m in _tagRe.allMatches(b.text)) {
        final t = m.group(0)!;
        if (!out.contains(t)) out.add(t);
      }
    }
    return out;
  }

  static List<String> extractUrls(Iterable<ParsedBlockLike> blocks) {
    final out = <String>[];
    for (final b in blocks) {
      if (b.isCode) continue;
      for (final m in kUrlRegex.allMatches(b.text)) {
        final u = m.group(0)!.replaceAll(RegExp(r'[.,;:!?]+$'), '');
        if (!out.contains(u)) out.add(u);
      }
    }
    return out;
  }

  /// Human-readable text (no markers, no checklist lines) for card previews.
  static String plain(String md) {
    final lines = <String>[];
    for (final b in parse(md)) {
      if (b.type == BlockType.todo) continue;
      final t = b.text.trim();
      if (t.isNotEmpty) lines.add(t);
    }
    return lines.join('\n');
  }

  /// True when the markdown already contains checklist lines.
  static bool hasTodoLines(String md) =>
      md.split('\n').any((l) => _todoLine.hasMatch(l));

  /// Toggles the [index]-th checklist line in [md]. Returns null if absent.
  static String? toggleTodoLine(String md, int index) {
    final lines = md.split('\n');
    var n = 0;
    for (var i = 0; i < lines.length; i++) {
      final m = _todoLine.firstMatch(lines[i]);
      if (m == null) continue;
      if (n++ == index) {
        final checked = m.group(2)!.toLowerCase() == 'x';
        lines[i] = lines[i].replaceFirst(
          RegExp(r'\[[ xX]\]'),
          checked ? '[ ]' : '[x]',
        );
        return lines.join('\n');
      }
    }
    return null;
  }

  static int todoLineCount(String md) =>
      md.split('\n').where((l) => _todoLine.hasMatch(l)).length;
}

/// Minimal view of a block for extraction helpers.
class ParsedBlockLike {
  const ParsedBlockLike(this.text, {this.isCode = false});
  final String text;
  final bool isCode;
}
