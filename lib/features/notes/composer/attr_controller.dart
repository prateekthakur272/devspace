import 'package:flutter/material.dart';
import 'package:devspace/core/model/note_markdown.dart';

/// Text controller holding *plain* text plus a per-character format bitmask
/// ([Fmt]). No markdown syntax ever appears in the field; bold/italic/etc. are
/// real styles. Marks are kept in sync with edits by diffing old/new text.
class AttrController extends TextEditingController {
  AttrController({String text = '', List<int>? marks})
      : marks = marks != null && marks.length == text.length
            ? List.of(marks)
            : List<int>.filled(text.length, 0),
        super(text: text) {
    _lastCaret = text.length;
  }

  List<int> marks;

  /// Format applied to the next typed characters (caret-only toggles).
  int? pending;

  /// Bumped on every text/format change (not on selection changes).
  int revision = 0;

  bool _suppress = false;
  int _lastCaret = 0;

  Color accent = const Color(0xFF3B82F6);
  Color muted = const Color(0xFF8A8F98);
  Color codeBg = const Color(0x22808080);
  RegExp? mentionRe;
  bool plainCode = false; // code blocks ignore inline marks

  String findQuery = '';
  int activeLocal = -1;

  // ---------------------------------------------------------------------------
  // Value sync
  // ---------------------------------------------------------------------------

  @override
  set value(TextEditingValue v) {
    if (!_suppress) {
      if (v.text != text) {
        _remark(text, v.text);
        revision++;
      } else if (v.selection.isValid && v.selection.baseOffset != _lastCaret) {
        pending = null;
      }
    }
    if (v.selection.isValid) _lastCaret = v.selection.baseOffset;
    super.value = v;
  }

  /// Replaces text and marks wholesale (no diffing).
  void setContent(String t, List<int> m, {int? caret}) {
    marks = m.length == t.length ? List.of(m) : List<int>.filled(t.length, 0);
    pending = null;
    _suppress = true;
    value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: caret ?? t.length),
    );
    _suppress = false;
    revision++;
  }

  void _remark(String old, String nw) {
    if (marks.length != old.length) {
      marks = List<int>.filled(old.length, 0);
    }
    var p = 0;
    final maxP = old.length < nw.length ? old.length : nw.length;
    while (p < maxP && old.codeUnitAt(p) == nw.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < old.length - p &&
        s < nw.length - p &&
        old.codeUnitAt(old.length - 1 - s) == nw.codeUnitAt(nw.length - 1 - s)) {
      s++;
    }
    final removedEnd = old.length - s;
    final insertCount = nw.length - p - s;
    final inherit = pending ?? _maskBefore(p);
    marks = [
      ...marks.sublist(0, p),
      ...List<int>.filled(insertCount < 0 ? 0 : insertCount, inherit),
      ...marks.sublist(removedEnd),
    ];
    if (marks.length != nw.length) {
      marks = List<int>.filled(nw.length, 0);
    }
  }

  int _maskBefore(int o) {
    if (marks.isEmpty) return 0;
    if (o > 0) return marks[(o - 1).clamp(0, marks.length - 1)];
    return marks[0];
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Mask shown as "active" in the toolbar for the current selection.
  int get activeMask {
    final s = selection;
    if (!s.isValid) return 0;
    if (s.isCollapsed) return pending ?? _maskBefore(s.start);
    var m = -1;
    for (var i = s.start; i < s.end && i < marks.length; i++) {
      m &= marks[i];
    }
    return m == -1 ? 0 : m;
  }

  void toggleMark(int bit) {
    final s = selection;
    if (!s.isValid) return;
    if (s.isCollapsed) {
      pending = (pending ?? _maskBefore(s.start)) ^ bit;
      notifyListeners();
      return;
    }
    final all = activeMask & bit != 0;
    for (var i = s.start; i < s.end && i < marks.length; i++) {
      marks[i] = all ? (marks[i] & ~bit) : (marks[i] | bit);
    }
    revision++;
    notifyListeners();
  }

  void clearMarks() {
    final s = selection;
    if (!s.isValid || s.isCollapsed) {
      pending = 0;
    } else {
      for (var i = s.start; i < s.end && i < marks.length; i++) {
        marks[i] = 0;
      }
      revision++;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Find / replace (per block)
  // ---------------------------------------------------------------------------

  List<TextRange> get matches {
    if (findQuery.isEmpty) return const [];
    final hay = text.toLowerCase();
    final needle = findQuery.toLowerCase();
    final out = <TextRange>[];
    var i = 0;
    while (true) {
      final at = hay.indexOf(needle, i);
      if (at < 0) break;
      out.add(TextRange(start: at, end: at + needle.length));
      i = at + needle.length;
    }
    return out;
  }

  void setFind(String q, int active) {
    if (q == findQuery && active == activeLocal) return;
    findQuery = q;
    activeLocal = active;
    notifyListeners();
  }

  void replaceRange(int a, int b, String rep) {
    value = TextEditingValue(
      text: text.replaceRange(a, b, rep),
      selection: TextSelection.collapsed(offset: a + rep.length),
    );
  }

  void replaceAllMatches(String rep) {
    final m = matches.reversed.toList();
    var t = text;
    for (final r in m) {
      t = t.replaceRange(r.start, r.end, rep);
    }
    // Rebuild marks by applying replacements back to front.
    var mk = List<int>.of(marks);
    for (final r in m) {
      final inherit = r.start < mk.length ? mk[r.start] : 0;
      mk = [
        ...mk.sublist(0, r.start),
        ...List<int>.filled(rep.length, inherit),
        ...mk.sublist(r.end),
      ];
    }
    setContent(t, mk, caret: 0);
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  static final RegExp _urlRe = RegExp(r'https?://[^\s<>()\[\]]+');
  static final RegExp _tagRe = RegExp(r'(?<![\w&/#])#[A-Za-z][\w-]*');

  final Map<int, TextStyle> _cache = {};

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final src = text;
    if (src.isEmpty) return TextSpan(style: base, text: src);
    final n = src.length;
    final mk = marks.length == n ? marks : List<int>.filled(n, 0);

    // kind: 0 none, 1 url, 2 tag, 3 mention
    final kind = List<int>.filled(n, 0);
    if (!plainCode) {
      for (final m in _urlRe.allMatches(src)) {
        for (var i = m.start; i < m.end; i++) {
          kind[i] = 1;
        }
      }
      for (final m in _tagRe.allMatches(src)) {
        for (var i = m.start; i < m.end; i++) {
          if (kind[i] == 0) kind[i] = 2;
        }
      }
      final mr = mentionRe;
      if (mr != null) {
        for (final m in mr.allMatches(src)) {
          for (var i = m.start; i < m.end; i++) {
            kind[i] = 3;
          }
        }
      }
    }
    final hl = List<int>.filled(n, 0);
    final found = matches;
    for (var mi = 0; mi < found.length; mi++) {
      for (var i = found[mi].start; i < found[mi].end; i++) {
        hl[i] = mi == activeLocal ? 2 : 1;
      }
    }

    int keyOf(int i) => (plainCode ? 0 : mk[i]) | (kind[i] << 5) | (hl[i] << 8);

    final children = <InlineSpan>[];
    var start = 0;
    var key = keyOf(0);
    for (var i = 1; i <= n; i++) {
      final k = i < n ? keyOf(i) : -1;
      if (k != key) {
        children.add(TextSpan(
          text: src.substring(start, i),
          style: _cache.putIfAbsent(key, () => _styleFor(key)),
        ));
        start = i;
        key = k;
      }
    }
    return TextSpan(style: base, children: children);
  }

  /// Invalidate cached styles when theme colors change.
  void setTheme({required Color accent, required Color muted, required Color codeBg}) {
    if (accent != this.accent || muted != this.muted || codeBg != this.codeBg) {
      this.accent = accent;
      this.muted = muted;
      this.codeBg = codeBg;
      _cache.clear();
    }
  }

  TextStyle _styleFor(int key) {
    final m = key & 31;
    final kind = (key >> 5) & 7;
    final hl = (key >> 8) & 3;
    final deco = <TextDecoration>[];
    if (m & Fmt.strike != 0) deco.add(TextDecoration.lineThrough);
    if (kind == 1) deco.add(TextDecoration.underline);
    Color? bg;
    if (m & Fmt.code != 0) bg = codeBg;
    if (m & Fmt.mark != 0) bg = const Color(0x77FFE066);
    if (kind == 3) bg = accent.withOpacity(0.16);
    if (hl == 1) bg = const Color(0x66FFC107);
    if (hl == 2) bg = const Color(0xCCFF9800);
    return TextStyle(
      fontWeight: m & Fmt.bold != 0 ? FontWeight.w700 : (kind == 2 || kind == 3 ? FontWeight.w600 : null),
      fontStyle: m & Fmt.italic != 0 ? FontStyle.italic : null,
      decoration: deco.isEmpty ? null : TextDecoration.combine(deco),
      decorationColor: kind == 1 ? accent : null,
      color: kind == 0 ? null : accent,
      backgroundColor: bg,
      fontFamily: m & Fmt.code != 0 ? 'Menlo' : null,
      fontFamilyFallback:
          m & Fmt.code != 0 ? const ['Consolas', 'Courier New', 'monospace'] : null,
    );
  }
}
