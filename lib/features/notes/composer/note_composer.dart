import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/model/note_markdown.dart';
import 'package:devspace/features/notes/composer/attr_controller.dart';
import 'package:devspace/features/notes/note_theme.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

/// WYSIWYG note composer (Google Keep / Samsung Notes / Notion style), shared
/// by the side pane and the modal.
///
/// Everything happens inside the editor — no raw markdown is ever shown:
///  * rich blocks: text, headings, bullets, numbers, checkboxes, quotes, code
///  * inline bold / italic / strike / highlight / code
///  * `@Project` mentions, `#tags`, URLs are detected automatically
///  * `/` command menu and markdown-style typing shortcuts (`# `, `- `, `[] `)
/// Markdown is only the *storage* format (Note.content); tags, projects,
/// links and the checklist are derived from the document on save.
class NoteComposer extends StatefulWidget {
  const NoteComposer({
    super.key,
    required this.state,
    required this.onClose,
    this.existingNote,
    this.initialProjectId,
    this.initialTag,
    this.initialChecklist = false,
    this.dialogMode = false,
  });

  final AppState state;
  final Note? existingNote;
  final String? initialProjectId;
  final String? initialTag;
  final bool initialChecklist;
  final VoidCallback onClose;
  final bool dialogMode;

  @override
  State<NoteComposer> createState() => _NoteComposerState();
}

enum _Save { idle, pending, saved }

class _Block {
  _Block({
    required this.id,
    required this.type,
    required this.indent,
    required this.checked,
    required this.ctrl,
    required this.focus,
    required this.checkId,
  });

  final String id;
  BlockType type;
  int indent;
  bool checked;
  final AttrController ctrl;
  final FocusNode focus;
  final GlobalKey key = GlobalKey();
  String checkId;
  int lastRev = 0;

  bool get isListLike =>
      type == BlockType.bullet || type == BlockType.number || type == BlockType.todo;
}

typedef _Sugg = ({String title, List<_Chip> chips, String key, bool popup});

class _Chip {
  const _Chip(this.label, this.onTap, {this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
}

class _NoteComposerState extends State<NoteComposer> {
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;
  late final TextEditingController _findCtrl;
  late final TextEditingController _replaceCtrl;
  late final FocusNode _findFocus;

  final List<_Block> _blocks = [];
  _Block? _lastFocused;
  int _idSeq = 0;
  bool _pinned = false;
  Color? _color;

  String? _noteId;
  late DateTime _createdAt;
  DateTime? _updatedAt;
  List<ChecklistItem> _origChecklist = const [];

  bool _showColors = false;
  bool _showFind = false;
  double _fontSize = 14;

  _Save _saveState = _Save.idle;
  Timer? _debounce;
  bool _dirty = false;
  final Set<String> _seedTexts = {};
  RegExp? _mentionRe;
  late String _lastTitle;

  // Autocomplete popup
  int _selIdx = 0;
  String _suggKey = '';
  String? _dismissed;
  final LayerLink _link = LayerLink();

  // Find
  int _matchTotal = 0;
  int _matchActive = -1;

  // Undo / redo (document level)
  final List<String> _hist = [];
  int _hIdx = -1;
  Timer? _histTimer;

  bool get _isNew => widget.existingNote == null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _noteId = note?.id;
    _createdAt = note?.createdAt ?? DateTime.now();
    _updatedAt = note?.updatedAt;
    _origChecklist = note?.checklist ?? const [];
    _pinned = note?.pinned ?? false;
    _color = note?.color;

    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _titleFocus = FocusNode();
    _findCtrl = TextEditingController();
    _replaceCtrl = TextEditingController();
    _findFocus = FocusNode();
    _lastTitle = _titleCtrl.text;
    _titleCtrl.addListener(() {
      if (_titleCtrl.text != _lastTitle) {
        _lastTitle = _titleCtrl.text;
        _markDirty();
      }
    });
    _findCtrl.addListener(_refreshFind);

    _buildMentionRe();
    _setBlocks(_initialBlocks(note));
    _snap(now: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isNew) {
        _titleFocus.requestFocus();
      } else {
        _focusBlock(_blocks.last);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _histTimer?.cancel();
    if (_dirty) {
      if (!_hasContent) {
        if (_noteId != null) {
          final id = _noteId!;
          final state = widget.state;
          Future.microtask(() => state.deleteNote(id));
        }
      } else {
        final note = _buildNote();
        if (note != null && !note.isEmpty) {
          final isNew = _noteId == null;
          final state = widget.state;
          Future.microtask(() => isNew ? state.addNote(note) : state.updateNote(note));
        }
      }
    }
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    _findFocus.dispose();
    for (final b in _blocks) {
      b.ctrl.dispose();
      b.focus.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Document <-> blocks
  // ---------------------------------------------------------------------------

  void _buildMentionRe() {
    final names = widget.state.projects.map((p) => p.name).where((n) => n.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _mentionRe = names.isEmpty
        ? null
        : RegExp('@(?:${names.map(RegExp.escape).join('|')})(?![\\w-])');
  }

  /// Parses the note and migrates data from older editor versions (separate
  /// checklist, tags, projects, links) into the document body.
  List<ParsedBlock> _initialBlocks(Note? note) {
    if (note == null) {
      final seed = <ParsedBlock>[
        if (widget.initialChecklist)
          ParsedBlock(type: BlockType.todo)
        else
          ParsedBlock(),
      ];
      final extra = <String>[];
      if (widget.initialTag != null) extra.add(_normTag(widget.initialTag!));
      for (final p in widget.state.projects) {
        if (p.id == widget.initialProjectId) extra.add('@${p.name}');
      }
      if (extra.isNotEmpty) {
        final line = extra.join(' ');
        _seedTexts.add(line);
        for (final item in extra) {
          _seedTexts.add(item);
        }
        seed.add(ParsedBlock(text: line));
      }
      return seed;
    }
    final blocks = NoteMarkdown.parse(note.content);
    if (blocks.length == 1 &&
        blocks.first.text.isEmpty &&
        blocks.first.type == BlockType.paragraph) {
      blocks.clear();
    }
    if (!blocks.any((b) => b.type == BlockType.todo)) {
      for (final c in note.checklist) {
        blocks.add(ParsedBlock(type: BlockType.todo, checked: c.checked, text: c.text));
      }
    }
    final bodyText = blocks.map((b) => b.text).join('\n');
    for (final l in note.links.where((l) => !bodyText.contains(l))) {
      blocks.add(ParsedBlock(text: l));
    }
    final chips = <String>[];
    for (final pid in note.projectIds) {
      for (final p in widget.state.projects) {
        if (p.id == pid && !bodyText.contains('@${p.name}')) chips.add('@${p.name}');
      }
    }
    chips.addAll(note.tags.where((t) => !bodyText.contains(t)));
    if (chips.isNotEmpty) blocks.add(ParsedBlock(text: chips.join(' ')));
    if (blocks.isEmpty) blocks.add(ParsedBlock());
    return blocks;
  }

  static String _normTag(String t) {
    t = t.trim().replaceAll(RegExp(r'\s+'), '-');
    if (t.isEmpty) return '';
    return t.startsWith('#') ? t : '#$t';
  }

  _Block _mk(ParsedBlock pb, {String? checkId}) {
    final id = 'b${_idSeq++}';
    late final _Block b;
    final ctrl = AttrController(text: pb.text, marks: pb.marks)
      ..mentionRe = _mentionRe
      ..plainCode = pb.type == BlockType.code;
    final focus = FocusNode(onKeyEvent: (n, e) => _onKey(b, e));
    b = _Block(
      id: id,
      type: pb.type,
      indent: pb.indent,
      checked: pb.checked,
      ctrl: ctrl,
      focus: focus,
      checkId: checkId ?? 'chk_${DateTime.now().microsecondsSinceEpoch}_$id',
    );
    b.lastRev = ctrl.revision;
    ctrl.addListener(() => _onCtrl(b));
    focus.addListener(() {
      if (focus.hasFocus) _lastFocused = b;
      if (mounted) setState(() {});
    });
    return b;
  }

  void _disposeBlock(_Block b) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      b.ctrl.dispose();
      b.focus.dispose();
    });
  }

  void _setBlocks(List<ParsedBlock> parsed) {
    final old = List<_Block>.of(_blocks);
    final ids = old.where((b) => b.type == BlockType.todo).map((b) => b.checkId).toList();
    final orig = _origChecklist.map((c) => c.id).toList();
    var ti = 0;
    _blocks.clear();
    for (final pb in parsed) {
      String? cid;
      if (pb.type == BlockType.todo) {
        cid = ti < ids.length ? ids[ti] : (ti < orig.length ? orig[ti] : null);
        ti++;
      }
      _blocks.add(_mk(pb, checkId: cid));
    }
    if (_blocks.isEmpty) _blocks.add(_mk(ParsedBlock()));
    for (final b in old) {
      _disposeBlock(b);
    }
    _lastFocused = null;
  }

  List<ParsedBlock> _toParsed() => [
        for (final b in _blocks)
          ParsedBlock(
            type: b.type,
            indent: b.indent,
            checked: b.checked,
            text: b.ctrl.text,
            marks: b.type == BlockType.code ? null : List.of(b.ctrl.marks),
          ),
      ];

  String _bodyMd() => NoteMarkdown.serialize(_toParsed());

  _Block get _target {
    for (final b in _blocks) {
      if (b.focus.hasFocus) return b;
    }
    if (_lastFocused != null && _blocks.contains(_lastFocused)) return _lastFocused!;
    return _blocks.last;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _markDirty() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _autosave);
    if (_saveState != _Save.pending && mounted) {
      setState(() => _saveState = _Save.pending);
    }
  }

  bool get _hasContent {
    if (_titleCtrl.text.trim().isNotEmpty) return true;
    for (final b in _blocks) {
      final t = b.ctrl.text.trim();
      if (t.isEmpty) continue;
      if (b.type == BlockType.todo) {
        return true;
      }
      if (_seedTexts.contains(t)) continue;
      var stripped = t;
      for (final seed in _seedTexts) {
        stripped = stripped.replaceAll(seed, '');
      }
      if (stripped.trim().isNotEmpty) return true;
    }
    return false;
  }

  Note? _buildNote() {
    if (!_hasContent) return null;
    final title = _titleCtrl.text.trim();
    final md = _bodyMd();
    final like = [
      for (final b in _blocks) ParsedBlockLike(b.ctrl.text, isCode: b.type == BlockType.code),
    ];
    final allText = like.where((b) => !b.isCode).map((b) => b.text).join('\n');
    final projectIds = <String>[
      for (final p in widget.state.projects)
        if (RegExp('@${RegExp.escape(p.name)}(?![\\w-])').hasMatch(allText)) p.id,
    ];
    final checklist = [
      for (final b in _blocks)
        if (b.type == BlockType.todo && b.ctrl.text.trim().isNotEmpty)
          ChecklistItem(id: b.checkId, text: b.ctrl.text, checked: b.checked),
    ];
    final now = DateTime.now();
    final note = Note(
      id: _noteId ?? 'note_${now.microsecondsSinceEpoch}',
      title: title,
      content: md,
      checklist: checklist,
      projectIds: projectIds,
      tags: NoteMarkdown.extractTags(like),
      links: NoteMarkdown.extractUrls(like),
      pinned: _pinned,
      color: _color,
      createdAt: _createdAt,
      updatedAt: now,
    );
    if (note.isEmpty) return null;
    return note;
  }

  void _autosave() {
    _commit();
    if (mounted) setState(() => _saveState = _Save.saved);
  }

  void _commit() {
    _debounce?.cancel();
    if (!_dirty) return;
    if (!_hasContent) {
      if (_noteId != null) {
        widget.state.deleteNote(_noteId!);
        _noteId = null;
      }
      _dirty = false;
      return;
    }
    final note = _buildNote();
    if (note == null || note.isEmpty) {
      if (_noteId != null) {
        widget.state.deleteNote(_noteId!);
        _noteId = null;
      }
      _dirty = false;
      return;
    }
    if (_noteId == null) {
      _noteId = note.id;
      widget.state.addNote(note);
    } else {
      widget.state.updateNote(note);
    }
    _updatedAt = note.updatedAt;
    _dirty = false;
  }

  void _saveAndClose() {
    _commit();
    widget.onClose();
  }

  void _deleteNote() {
    _debounce?.cancel();
    _dirty = false;
    if (_noteId != null) widget.state.deleteNote(_noteId!);
    widget.onClose();
  }

  void _duplicate() {
    _commit();
    final src = _buildNote();
    if (src == null) return;
    final now = DateTime.now();
    final copy = src.copyWith(
      id: 'note_${now.microsecondsSinceEpoch}',
      title: src.title.isEmpty ? 'Copy' : '${src.title} (copy)',
      checklist: [
        for (final c in src.checklist) c.copyWith(id: 'chk_${now.microsecondsSinceEpoch}_${c.id}'),
      ],
      createdAt: now,
      updatedAt: now,
    );
    widget.state.addNote(copy);
    widget.state.openNoteInPane(copy);
    if (widget.dialogMode) widget.onClose();
  }

  String _markdown() {
    final title = _titleCtrl.text.trim();
    final body = _bodyMd();
    return [if (title.isNotEmpty) '# $title', if (body.isNotEmpty) body].join('\n\n');
  }

  Future<void> _saveMarkdownFile() async {
    try {
      final title = _titleCtrl.text.trim();
      final safe = (title.isEmpty ? 'note' : title)
          .replaceAll(RegExp(r'[^\w\- ]+'), '')
          .trim()
          .replaceAll(' ', '-');
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export note as Markdown',
        fileName: '${safe.isEmpty ? 'note' : safe}.md',
        bytes: Uint8List.fromList(utf8.encode(_markdown())),
      );
      if (path != null) {
        final f = File(path.toFilePath());
        if (!await f.exists() || (await f.length()) == 0) {
          await f.writeAsString(_markdown());
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  void _snap({bool now = false}) {
    _histTimer?.cancel();
    void run() {
      final md = _bodyMd();
      if (_hIdx >= 0 && _hist[_hIdx] == md) return;
      _hist.removeRange(_hIdx + 1, _hist.length);
      _hist.add(md);
      _hIdx = _hist.length - 1;
      if (_hist.length > 100) {
        _hist.removeAt(0);
        _hIdx--;
      }
      if (mounted) setState(() {});
    }

    if (now) {
      run();
    } else {
      _histTimer = Timer(const Duration(milliseconds: 500), run);
    }
  }

  void _restore(String md) {
    final at = _blocks.indexOf(_target);
    setState(() => _setBlocks(NoteMarkdown.parse(md)));
    _markDirty();
    _focusBlock(_blocks[at.clamp(0, _blocks.length - 1)]);
  }

  void _undo() {
    _snap(now: true);
    if (_hIdx > 0) {
      _hIdx--;
      _restore(_hist[_hIdx]);
    }
  }

  void _redo() {
    if (_hIdx < _hist.length - 1) {
      _hIdx++;
      _restore(_hist[_hIdx]);
    }
  }

  // ---------------------------------------------------------------------------
  // Editing: events
  // ---------------------------------------------------------------------------

  void _onCtrl(_Block b) {
    if (!mounted) return;
    if (b.ctrl.revision != b.lastRev) {
      b.lastRev = b.ctrl.revision;
      _afterEdit(b);
    }
    setState(() {});
  }

  void _afterEdit(_Block b) {
    final c = b.ctrl;
    final t = c.text;
    if (t.contains('\n') && b.type != BlockType.code) {
      _splitPaste(b);
      return;
    }
    if (b.type == BlockType.paragraph && c.selection.isValid) {
      final caret = c.selection.baseOffset;
      BlockType? to;
      var plen = 0;
      const triggers = <String, BlockType>{
        '# ': BlockType.h1,
        '## ': BlockType.h2,
        '### ': BlockType.h2,
        '- ': BlockType.bullet,
        '* ': BlockType.bullet,
        '[] ': BlockType.todo,
        '[ ] ': BlockType.todo,
        '> ': BlockType.quote,
      };
      for (final e in triggers.entries) {
        if (t.startsWith(e.key) && caret == e.key.length) {
          to = e.value;
          plen = e.key.length;
        }
      }
      final num = RegExp(r'^\d+\. ').firstMatch(t);
      if (to == null && num != null && caret == num.end) {
        to = BlockType.number;
        plen = num.end;
      }
      if (to == null && t == '```') {
        to = BlockType.code;
        plen = 3;
      }
      if (to != null) {
        final rest = t.substring(plen);
        final marks = c.marks.length == t.length ? c.marks.sublist(plen) : null;
        b.type = to;
        b.lastRev = c.revision + 1;
        c
          ..plainCode = to == BlockType.code
          ..setContent(rest, marks ?? List.filled(rest.length, 0), caret: 0);
        _snap(now: true);
      }
    }
    _markDirty();
    _snap();
    if (_showFind) _refreshFind(active: _matchActive);
  }

  void _splitPaste(_Block b) {
    final c = b.ctrl;
    final lines = c.text.split('\n');
    final first = NoteMarkdown.parseInline(lines.first);
    final rest = lines.skip(1).join('\n');
    final idx = _blocks.indexOf(b);
    final newBlocks = NoteMarkdown.parse(rest).map(_mk).toList();
    b.lastRev = c.revision + 1;
    c.setContent(first.$1, first.$2);
    setState(() => _blocks.insertAll(idx + 1, newBlocks));
    _markDirty();
    _snap(now: true);
    if (newBlocks.isNotEmpty) _focusBlock(newBlocks.last);
  }

  KeyEventResult _onKey(_Block b, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final kb = HardwareKeyboard.instance;
    final mod = kb.isMetaPressed || kb.isControlPressed;
    final shift = kb.isShiftPressed;
    final c = b.ctrl;
    final sel = c.selection;
    final isDown = e is KeyDownEvent;

    if (mod) {
      if (!isDown) return KeyEventResult.ignored;
      if (k == LogicalKeyboardKey.keyB) {
        c.toggleMark(Fmt.bold);
      } else if (k == LogicalKeyboardKey.keyI) {
        c.toggleMark(Fmt.italic);
      } else if (k == LogicalKeyboardKey.keyE) {
        c.toggleMark(Fmt.code);
      } else if (k == LogicalKeyboardKey.keyX && shift) {
        c.toggleMark(Fmt.strike);
      } else if (k == LogicalKeyboardKey.keyH && shift) {
        c.toggleMark(Fmt.mark);
      } else if (k == LogicalKeyboardKey.keyZ) {
        shift ? _redo() : _undo();
      } else if (k == LogicalKeyboardKey.keyY) {
        _redo();
      } else if (k == LogicalKeyboardKey.arrowUp && shift) {
        _moveBlock(b, -1);
      } else if (k == LogicalKeyboardKey.arrowDown && shift) {
        _moveBlock(b, 1);
      } else if (k == LogicalKeyboardKey.equal) {
        setState(() => _fontSize = (_fontSize + 1).clamp(10, 26));
      } else if (k == LogicalKeyboardKey.minus) {
        setState(() => _fontSize = (_fontSize - 1).clamp(10, 26));
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    final sg = _suggestions();
    if (sg != null && sg.popup && sg.chips.isNotEmpty) {
      final n = sg.chips.length;
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() => _selIdx = (_selIdx + 1) % n);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        setState(() => _selIdx = (_selIdx - 1 + n) % n);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter ||
          k == LogicalKeyboardKey.tab) {
        if (isDown) sg.chips[_selIdx.clamp(0, n - 1)].onTap();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        setState(() => _dismissed = sg.key);
        return KeyEventResult.handled;
      }
    }

    final idx = _blocks.indexOf(b);
    final collapsed = sel.isValid && sel.isCollapsed;

    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (isDown) _enter(b);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace && collapsed && sel.start == 0) {
      return _backspaceAtStart(b, idx) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.delete &&
        collapsed &&
        sel.start == c.text.length &&
        idx < _blocks.length - 1) {
      _mergeNextInto(b, idx);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      if (isDown && b.isListLike) {
        setState(() => b.indent = (b.indent + (shift ? -1 : 1)).clamp(0, 3));
        _markDirty();
        _snap(now: true);
      }
      return KeyEventResult.handled;
    }
    if (collapsed && !shift) {
      if ((k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowLeft) &&
          sel.start == 0 &&
          idx > 0) {
        _focusBlock(_blocks[idx - 1]);
        return KeyEventResult.handled;
      }
      if ((k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowRight) &&
          sel.start == c.text.length &&
          idx < _blocks.length - 1) {
        _focusBlock(_blocks[idx + 1], offset: 0);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Editing: structure
  // ---------------------------------------------------------------------------

  void _focusBlock(_Block b, {int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_blocks.contains(b)) return;
      b.focus.requestFocus();
      final len = b.ctrl.text.length;
      b.ctrl.selection = TextSelection.collapsed(offset: (offset ?? len).clamp(0, len));
      final ctx = b.key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 120), alignment: 0.3);
      }
    });
  }

  void _enter(_Block b) {
    final c = b.ctrl;
    final sel = c.selection.isValid ? c.selection : TextSelection.collapsed(offset: c.text.length);
    final idx = _blocks.indexOf(b);

    if (b.type == BlockType.code) {
      if (sel.isCollapsed && sel.start == c.text.length && c.text.endsWith('\n')) {
        c.replaceRange(c.text.length - 1, c.text.length, '');
        final nb = _mk(ParsedBlock());
        setState(() => _blocks.insert(idx + 1, nb));
        _markDirty();
        _snap(now: true);
        _focusBlock(nb);
      } else {
        c.replaceRange(sel.start, sel.end, '\n');
      }
      return;
    }

    if (c.text.isEmpty && b.type != BlockType.paragraph) {
      setState(() {
        if (b.indent > 0 && b.isListLike) {
          b.indent--;
        } else {
          b.type = BlockType.paragraph;
          b.indent = 0;
          b.checked = false;
        }
      });
      _markDirty();
      _snap(now: true);
      return;
    }

    final okMarks = c.marks.length == c.text.length;
    final head = c.text.substring(0, sel.start);
    final tail = c.text.substring(sel.end);
    final headMarks = okMarks ? c.marks.sublist(0, sel.start) : null;
    final tailMarks = okMarks ? c.marks.sublist(sel.end) : null;

    final nextType = switch (b.type) {
      BlockType.h1 || BlockType.h2 => BlockType.paragraph,
      final t => t,
    };
    final nb = _mk(ParsedBlock(
      type: nextType,
      indent: nextType == BlockType.paragraph ? 0 : b.indent,
      text: tail,
      marks: tailMarks,
    ));
    b.lastRev = c.revision + 1;
    c.setContent(head, headMarks ?? List.filled(head.length, 0));
    setState(() => _blocks.insert(idx + 1, nb));
    _markDirty();
    _snap(now: true);
    _focusBlock(nb, offset: 0);
  }

  bool _backspaceAtStart(_Block b, int idx) {
    if (b.isListLike && b.indent > 0) {
      setState(() => b.indent--);
    } else if (b.type != BlockType.paragraph) {
      setState(() {
        b.type = BlockType.paragraph;
        b.indent = 0;
        b.checked = false;
        b.ctrl.plainCode = false;
      });
    } else if (idx > 0) {
      final prev = _blocks[idx - 1];
      final joinAt = prev.ctrl.text.length;
      prev.lastRev = prev.ctrl.revision + 1;
      prev.ctrl.setContent(
        prev.ctrl.text + b.ctrl.text,
        [...prev.ctrl.marks, ...b.ctrl.marks],
        caret: joinAt,
      );
      setState(() => _blocks.removeAt(idx));
      _disposeBlock(b);
      _markDirty();
      _snap(now: true);
      _focusBlock(prev, offset: joinAt);
      return true;
    } else {
      return false;
    }
    _markDirty();
    _snap(now: true);
    return true;
  }

  void _mergeNextInto(_Block b, int idx) {
    final next = _blocks[idx + 1];
    final joinAt = b.ctrl.text.length;
    b.lastRev = b.ctrl.revision + 1;
    b.ctrl.setContent(
      b.ctrl.text + next.ctrl.text,
      [...b.ctrl.marks, ...next.ctrl.marks],
      caret: joinAt,
    );
    setState(() => _blocks.removeAt(idx + 1));
    _disposeBlock(next);
    _markDirty();
    _snap(now: true);
  }

  void _moveBlock(_Block b, int dir) {
    final i = _blocks.indexOf(b);
    final j = i + dir;
    if (j < 0 || j >= _blocks.length) return;
    setState(() {
      _blocks.removeAt(i);
      _blocks.insert(j, b);
    });
    _markDirty();
    _snap(now: true);
    _focusBlock(b, offset: b.ctrl.selection.baseOffset);
  }

  void _setType(_Block b, BlockType t) {
    setState(() {
      if (b.type == t) {
        b.type = BlockType.paragraph;
        b.indent = 0;
      } else {
        b.type = t;
        if (!b.isListLike) b.indent = 0;
      }
      if (b.type != BlockType.todo) b.checked = false;
      b.ctrl.plainCode = b.type == BlockType.code;
    });
    _markDirty();
    _snap(now: true);
    _focusBlock(b, offset: b.ctrl.selection.isValid ? b.ctrl.selection.baseOffset : null);
  }

  void _toggleCheck(_Block b) {
    setState(() => b.checked = !b.checked);
    _markDirty();
    _snap(now: true);
  }

  void _setAllChecked(bool v) {
    setState(() {
      for (final b in _blocks) {
        if (b.type == BlockType.todo) b.checked = v;
      }
    });
    _markDirty();
    _snap(now: true);
  }

  void _clearCompleted() {
    final gone = _blocks.where((b) => b.type == BlockType.todo && b.checked).toList();
    setState(() {
      _blocks.removeWhere(gone.contains);
      if (_blocks.isEmpty) _blocks.add(_mk(ParsedBlock()));
    });
    for (final b in gone) {
      _disposeBlock(b);
    }
    _markDirty();
    _snap(now: true);
  }

  void _tapBelow() {
    final last = _blocks.last;
    if (last.ctrl.text.isNotEmpty || last.type != BlockType.paragraph) {
      final nb = _mk(ParsedBlock());
      setState(() => _blocks.add(nb));
      _markDirty();
      _snap(now: true);
      _focusBlock(nb);
    } else {
      _focusBlock(last);
    }
  }

  // ---------------------------------------------------------------------------
  // Find & replace
  // ---------------------------------------------------------------------------

  void _toggleFind() {
    setState(() => _showFind = !_showFind);
    if (_showFind) {
      final t = _target;
      final s = t.ctrl.selection;
      if (s.isValid && !s.isCollapsed) {
        _findCtrl.text = t.ctrl.text.substring(s.start, s.end);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _findFocus.requestFocus());
    } else {
      _findCtrl.clear();
      for (final b in _blocks) {
        b.ctrl.setFind('', -1);
      }
      _matchTotal = 0;
      _matchActive = -1;
      _focusBlock(_target);
    }
  }

  void _refreshFind({int active = -1}) {
    final q = _findCtrl.text;
    var total = 0;
    final counts = <int>[];
    for (final b in _blocks) {
      b.ctrl.findQuery = q;
      final n = b.ctrl.matches.length;
      counts.add(n);
      total += n;
    }
    if (active >= total) active = total == 0 ? -1 : 0;
    var offset = 0;
    for (var i = 0; i < _blocks.length; i++) {
      final local = (active >= offset && active < offset + counts[i]) ? active - offset : -1;
      _blocks[i].ctrl.setFind(q, local);
      if (local >= 0) {
        final ctx = _blocks[i].key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 120), alignment: 0.3);
        }
      }
      offset += counts[i];
    }
    if (mounted) {
      setState(() {
        _matchTotal = total;
        _matchActive = active;
      });
    }
  }

  void _stepFind(int dir) {
    if (_matchTotal == 0) return;
    final next = _matchActive < 0
        ? (dir > 0 ? 0 : _matchTotal - 1)
        : (_matchActive + dir + _matchTotal) % _matchTotal;
    _refreshFind(active: next);
  }

  void _replaceCurrent() {
    if (_matchTotal == 0) return;
    final active = _matchActive < 0 ? 0 : _matchActive;
    var offset = 0;
    for (final b in _blocks) {
      final m = b.ctrl.matches;
      if (active < offset + m.length) {
        final r = m[active - offset];
        b.ctrl.replaceRange(r.start, r.end, _replaceCtrl.text);
        break;
      }
      offset += m.length;
    }
    _refreshFind(active: active);
  }

  void _replaceAll() {
    for (final b in _blocks) {
      if (b.ctrl.matches.isNotEmpty) b.ctrl.replaceAllMatches(_replaceCtrl.text);
    }
    _refreshFind();
    _snap(now: true);
  }

  // ---------------------------------------------------------------------------
  // Suggestions (@project, #tag, /command, link)
  // ---------------------------------------------------------------------------

  List<String> get _knownTags {
    final all = <String, int>{};
    for (final n in widget.state.notes) {
      for (final t in n.tags) {
        all[t] = (all[t] ?? 0) + 1;
      }
    }
    final keys = all.keys.toList()..sort((a, b) => all[b]!.compareTo(all[a]!));
    return keys;
  }

  _Sugg? _suggestions() {
    _Block? b;
    for (final x in _blocks) {
      if (x.focus.hasFocus) b = x;
    }
    if (b == null) return null;
    final target = b;
    final c = target.ctrl;
    if (!c.selection.isValid || !c.selection.isCollapsed) return null;
    final t = c.text;
    final caret = c.selection.baseOffset.clamp(0, t.length);
    var s = caret;
    while (s > 0 && !RegExp(r'\s').hasMatch(t[s - 1])) {
      s--;
    }
    final word = t.substring(s, caret);
    if (word.isEmpty) return null;

    void replaceWord(String rep) {
      c.value = TextEditingValue(
        text: t.replaceRange(s, caret, rep),
        selection: TextSelection.collapsed(offset: s + rep.length),
      );
      target.focus.requestFocus();
    }

    if (word.startsWith('@')) {
      final q = word.substring(1).toLowerCase();
      final list =
          widget.state.projects.where((pr) => pr.name.toLowerCase().contains(q)).take(8).toList();
      if (list.isEmpty) return null;
      final key = '${target.id}|$s|$word';
      if (key == _dismissed) return null;
      return (
        key: key,
        popup: true,
        title: 'Mention project',
        chips: [
          for (final pr in list)
            _Chip(pr.name, () => replaceWord('@${pr.name} '), icon: AppIcons.project),
        ],
      );
    }
    if (word.startsWith('#') && !word.startsWith('##') && target.type != BlockType.code) {
      final q = word.substring(1).toLowerCase();
      final used = NoteMarkdown.extractTags(
        [for (final x in _blocks) ParsedBlockLike(x.ctrl.text, isCode: x.type == BlockType.code)],
      );
      final list = {..._knownTags, ...used}
          .where((x) => x.substring(1).toLowerCase().startsWith(q) && x != word)
          .take(8)
          .toList();
      if (list.isEmpty) return null;
      final key = '${target.id}|$s|$word';
      if (key == _dismissed) return null;
      return (
        key: key,
        popup: true,
        title: 'Tag',
        chips: [
          for (final tag in list) _Chip(tag, () => replaceWord('$tag '), icon: Icons.tag_rounded),
        ],
      );
    }
    if (word.startsWith('/') && s == 0) {
      final q = word.substring(1).toLowerCase();
      final cmds = <(String, IconData, BlockType)>[
        ('Heading 1', Icons.title_rounded, BlockType.h1),
        ('Heading 2', Icons.text_fields_rounded, BlockType.h2),
        ('Checklist', AppIcons.checklist, BlockType.todo),
        ('Bullet list', Icons.format_list_bulleted_rounded, BlockType.bullet),
        ('Numbered list', Icons.format_list_numbered_rounded, BlockType.number),
        ('Quote', Icons.format_quote_rounded, BlockType.quote),
        ('Code block', Icons.data_object_rounded, BlockType.code),
        ('Text', Icons.notes_rounded, BlockType.paragraph),
      ].where((e) => e.$1.toLowerCase().contains(q)).toList();
      if (cmds.isEmpty) return null;
      final key = '${target.id}|$s|$word';
      if (key == _dismissed) return null;
      return (
        key: key,
        popup: true,
        title: 'Turn into',
        chips: [
          for (final e in cmds)
            _Chip(e.$1, () {
              c.value = TextEditingValue(
                text: t.replaceRange(s, caret, ''),
                selection: TextSelection.collapsed(offset: s),
              );
              setState(() {
                target.type = e.$3;
                target.checked = false;
                target.ctrl.plainCode = e.$3 == BlockType.code;
              });
              _markDirty();
              _snap(now: true);
              target.focus.requestFocus();
            }, icon: e.$2),
        ],
      );
    }
    if (word.startsWith('http') && kUrlRegex.hasMatch(word)) {
      final url = word.replaceAll(RegExp(r'[.,;:!?]+$'), '');
      return (
        key: 'link',
        popup: false,
        title: 'Link',
        chips: [
          _Chip('Open', () => Platform.openUrl(url), icon: AppIcons.external),
          _Chip('Copy', () => Platform.copy(url), icon: AppIcons.copy),
        ],
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  void _showMoreMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset(box.size.width - 190, box.size.height + 4));
    final hasTodos = _blocks.any((b) => b.type == BlockType.todo);
    ContextMenu.show(ctx, pos, [
      ContextMenuItem(
        label: 'Find & replace',
        icon: AppIcons.search,
        shortcut: Platform.isMac ? '⌘F' : 'Ctrl+F',
        action: _toggleFind,
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Copy as Markdown',
        icon: AppIcons.copy,
        action: () => Platform.copy(_markdown()),
      ),
      ContextMenuItem(
        label: 'Export as .md file…',
        icon: AppIcons.download,
        action: _saveMarkdownFile,
      ),
      ContextMenuItem(label: 'Duplicate note', icon: Icons.copy_all_rounded, action: _duplicate),
      if (hasTodos) ...[
        const ContextMenuItem(label: ''),
        ContextMenuItem(
            label: 'Check all', icon: Icons.done_all_rounded, action: () => _setAllChecked(true)),
        ContextMenuItem(
            label: 'Uncheck all',
            icon: Icons.remove_done_rounded,
            action: () => _setAllChecked(false)),
        ContextMenuItem(
            label: 'Delete completed items', icon: AppIcons.delete, action: _clearCompleted),
      ],
      if (_noteId != null) ...[
        const ContextMenuItem(label: ''),
        ContextMenuItem(
            label: 'Delete note', icon: AppIcons.delete, danger: true, action: _deleteNote),
      ],
    ]);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final theme = getThemeForColor(_color);
    final surface = theme != null ? theme.surface(p.dark) : p.panel;
    final accent = _color ?? p.accent;
    final codeBg = p.dark ? const Color(0x33FFFFFF) : const Color(0x14000000);
    for (final b in _blocks) {
      b.ctrl.setTheme(accent: accent, muted: p.muted, codeBg: codeBg);
    }

    final sugg = _suggestions();
    if ((sugg?.key ?? '') != _suggKey) {
      _suggKey = sugg?.key ?? '';
      _selIdx = 0;
    }
    final popup = (sugg != null && sugg.popup && sugg.chips.isNotEmpty)
        ? _popup(p, accent, sugg)
        : null;

    final editorCore = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_showFind) {
            _toggleFind();
          } else {
            _saveAndClose();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleFind,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFind,
      },
      child: Container(
        color: surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(p),
            if (_showColors) _colorBar(p),
            _toolbar(p),
            if (_showFind) _findBar(p),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    widget.dialogMode ? 26 : 16, 16, widget.dialogMode ? 26 : 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleField(p),
                    _metaLine(p),
                    const SizedBox(height: 12),
                    ..._blockWidgets(p, accent),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _tapBelow,
                      child: const SizedBox(height: 160, width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
            if (sugg != null && !sugg.popup) _suggestionBar(p, accent, sugg),
            _statusBar(p),
          ],
        ),
      ),
    );

    final editor = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: editorCore),
        if (popup != null) Positioned(left: 0, top: 0, child: popup),
      ],
    );

    if (!widget.dialogMode) return editor;

    return Center(
      child: ClickableNoRipple(
        onClick: () {},
        child: Container(
          width: 760,
          height: 640,
          constraints: const BoxConstraints(maxWidth: 900),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16)),
            ],
          ),
          child: Material(type: MaterialType.transparency, child: editor),
        ),
      ),
    );
  }

  // --- Header ---------------------------------------------------------------

  Widget _header(Pal p) {
    final status = switch (_saveState) {
      _Save.pending => 'Saving…',
      _Save.saved => 'Saved',
      _Save.idle => _updatedAt != null ? 'Edited ${_formatTime(_updatedAt!)}' : 'New note',
    };
    return DrawBottomBorder(
      color: p.border,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconBtn(
                icon: widget.dialogMode ? AppIcons.close : AppIcons.back,
                tooltip: 'Close (auto-saves)',
                size: 30,
                iconSize: 16,
                onClick: _saveAndClose,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _saveState == _Save.pending ? p.warn : p.ok,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: T(status, size: 11, color: p.muted)),
                  ],
                ),
              ),
              IconBtn(
                icon: _pinned ? AppIcons.pin : AppIcons.unpin,
                tooltip: _pinned ? 'Unpin' : 'Pin to top',
                size: 28,
                iconSize: 15,
                color: _pinned ? p.accent : p.muted,
                onClick: () {
                  setState(() => _pinned = !_pinned);
                  _markDirty();
                },
              ),
              ClickableNoRipple(
                onClick: () => setState(() => _showColors = !_showColors),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color ?? p.field,
                      border: Border.all(color: _showColors ? p.accent : p.border, width: 1.5),
                    ),
                    child: Icon(Icons.palette_outlined,
                        size: 12, color: _color != null ? Colors.white : p.muted),
                  ),
                ),
              ),
              Builder(
                builder: (ctx) => IconBtn(
                  icon: AppIcons.moreVert,
                  tooltip: 'More',
                  size: 28,
                  iconSize: 16,
                  onClick: () => _showMoreMenu(ctx),
                ),
              ),
              const SizedBox(width: 4),
              Btn(label: 'Done', primary: true, height: 26, fontSize: 11.5, onClick: _saveAndClose),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorBar(Pal p) {
    Widget dot(Color? c, String tip, {required bool selected, Color? ring}) {
      return Tooltip(
        message: tip,
        child: ClickableNoRipple(
          onClick: () {
            setState(() {
              _color = c;
              _showColors = false;
            });
            _markDirty();
          },
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c ?? p.panel,
              border: Border.all(
                  color: selected ? (ring ?? p.text) : p.border, width: selected ? 2 : 1),
            ),
            child: c == null
                ? Icon(Icons.format_color_reset_rounded, size: 12, color: p.muted)
                : null,
          ),
        ),
      );
    }

    return DrawBottomBorder(
      color: p.border,
      child: Container(
        height: 38,
        color: p.field.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              dot(null, 'Default', selected: _color == null, ring: p.accent),
              for (final t in kNoteColorThemes)
                dot(t.accent, t.label, selected: _color?.value == t.accent.value),
            ],
          ),
        ),
      ),
    );
  }

  // --- Toolbar ----------------------------------------------------------------

  Widget _toolbar(Pal p) {
    final t = _target;
    final mask = t.ctrl.activeMask;
    final mod = Platform.isMac ? '⌘' : 'Ctrl+';

    Widget sep() => Container(
        width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 5), color: p.border);

    Widget act(IconData i, String tip, VoidCallback op,
            {bool active = false, bool enabled = true}) =>
        IconBtn(
          icon: i,
          tooltip: tip,
          size: 28,
          iconSize: 16,
          active: active,
          onClick: enabled
              ? () {
                  op();
                  t.focus.requestFocus();
                }
              : null,
        );

    Widget mark(IconData i, String tip, int bit) =>
        act(i, tip, () => t.ctrl.toggleMark(bit), active: mask & bit != 0);

    Widget type(IconData i, String tip, BlockType bt) =>
        act(i, tip, () => _setType(t, bt), active: t.type == bt);

    Widget label(String text, String tip, BlockType bt) => Tooltip(
          message: tip,
          child: HoverBuilder(
            cursor: SystemMouseCursors.click,
            onTap: () => _setType(t, bt),
            builder: (_, hovered) => Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.type == bt
                    ? p.accent.withOpacity(0.16)
                    : (hovered ? p.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: T(text,
                  size: 12,
                  weight: FontWeight.w800,
                  color: t.type == bt ? p.accent : (hovered ? p.text : p.muted)),
            ),
          ),
        );

    return DrawBottomBorder(
      color: p.border,
      child: SizedBox(
        height: 38,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              act(Icons.undo_rounded, 'Undo (${mod}Z)', _undo, enabled: _hIdx > 0),
              act(Icons.redo_rounded, 'Redo ($mod⇧Z)', _redo, enabled: _hIdx < _hist.length - 1),
              sep(),
              label('H1', 'Heading 1', BlockType.h1),
              label('H2', 'Heading 2', BlockType.h2),
              sep(),
              mark(Icons.format_bold_rounded, 'Bold (${mod}B)', Fmt.bold),
              mark(Icons.format_italic_rounded, 'Italic (${mod}I)', Fmt.italic),
              mark(Icons.strikethrough_s_rounded, 'Strikethrough ($mod⇧X)', Fmt.strike),
              mark(Icons.border_color_rounded, 'Highlight ($mod⇧H)', Fmt.mark),
              mark(Icons.code_rounded, 'Inline code (${mod}E)', Fmt.code),
              act(Icons.format_clear_rounded, 'Clear formatting', t.ctrl.clearMarks),
              sep(),
              type(AppIcons.checklist, 'Checklist', BlockType.todo),
              type(Icons.format_list_bulleted_rounded, 'Bulleted list', BlockType.bullet),
              type(Icons.format_list_numbered_rounded, 'Numbered list', BlockType.number),
              act(Icons.format_indent_increase_rounded, 'Indent (Tab)', () {
                if (t.isListLike) {
                  setState(() => t.indent = (t.indent + 1).clamp(0, 3));
                  _markDirty();
                }
              }, enabled: t.isListLike),
              act(Icons.format_indent_decrease_rounded, 'Outdent (⇧Tab)', () {
                if (t.isListLike) {
                  setState(() => t.indent = (t.indent - 1).clamp(0, 3));
                  _markDirty();
                }
              }, enabled: t.isListLike),
              type(Icons.format_quote_rounded, 'Quote', BlockType.quote),
              type(Icons.data_object_rounded, 'Code block', BlockType.code),
              sep(),
              IconBtn(
                icon: AppIcons.search,
                tooltip: 'Find & replace (${mod}F)',
                size: 28,
                iconSize: 16,
                active: _showFind,
                onClick: _toggleFind,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Find bar ---------------------------------------------------------------

  Widget _findBar(Pal p) {
    Widget field(TextEditingController c, FocusNode? f, String hint, {VoidCallback? onSubmit}) {
      return Expanded(
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.border),
          ),
          child: TextField(
            controller: c,
            focusNode: f,
            onSubmitted: (_) => onSubmit?.call(),
            style: TextStyle(fontSize: 12, color: p.text),
            cursorColor: p.accent,
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
        ),
      );
    }

    final hasQuery = _findCtrl.text.isNotEmpty;
    return DrawBottomBorder(
      color: p.border,
      child: Container(
        color: p.field.withOpacity(0.45),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Column(
          children: [
            Row(
              children: [
                field(_findCtrl, _findFocus, 'Find', onSubmit: () {
                  _stepFind(1);
                  _findFocus.requestFocus();
                }),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: T(
                    hasQuery
                        ? (_matchTotal == 0
                            ? '0'
                            : '${_matchActive < 0 ? '–' : _matchActive + 1}/$_matchTotal')
                        : '',
                    size: 11,
                    color: p.muted,
                    align: TextAlign.center,
                  ),
                ),
                IconBtn(
                  icon: Icons.keyboard_arrow_up_rounded,
                  size: 26,
                  iconSize: 17,
                  tooltip: 'Previous',
                  onClick: _matchTotal > 0 ? () => _stepFind(-1) : null,
                ),
                IconBtn(
                  icon: Icons.keyboard_arrow_down_rounded,
                  size: 26,
                  iconSize: 17,
                  tooltip: 'Next',
                  onClick: _matchTotal > 0 ? () => _stepFind(1) : null,
                ),
                IconBtn(
                    icon: AppIcons.close,
                    size: 26,
                    iconSize: 14,
                    tooltip: 'Close',
                    onClick: _toggleFind),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                field(_replaceCtrl, null, 'Replace with'),
                const SizedBox(width: 6),
                Btn(
                    label: 'Replace',
                    height: 26,
                    fontSize: 11,
                    onClick: _matchTotal > 0 ? _replaceCurrent : null),
                const SizedBox(width: 4),
                Btn(
                    label: 'All',
                    height: 26,
                    fontSize: 11,
                    onClick: _matchTotal > 0 ? _replaceAll : null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Title / meta -------------------------------------------------------------

  Widget _titleField(Pal p) {
    return TextField(
      controller: _titleCtrl,
      focusNode: _titleFocus,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _focusBlock(_blocks.first, offset: 0),
      onTapOutside: (_) {},
      style: TextStyle(
          fontSize: _fontSize + 8, fontWeight: FontWeight.w800, color: p.text, height: 1.25),
      cursorColor: p.accent,
      maxLines: null,
      decoration: InputDecoration.collapsed(
        hintText: 'Title',
        hintStyle: TextStyle(
            fontSize: _fontSize + 8,
            fontWeight: FontWeight.w800,
            color: p.muted.withOpacity(0.5)),
      ),
    );
  }

  Widget _metaLine(Pal p) {
    final txt = _noteId == null
        ? 'Type / for blocks · @ to mention a project · # to tag'
        : 'Created ${_formatTime(_createdAt)}${_updatedAt != null ? ' · Edited ${_formatTime(_updatedAt!)}' : ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: T(txt, size: 10.5, color: p.muted.withOpacity(0.85)),
    );
  }

  // --- Blocks -------------------------------------------------------------------

  List<Widget> _blockWidgets(Pal p, Color accent) {
    final counters = List<int>.filled(4, 0);
    final out = <Widget>[];
    for (final b in _blocks) {
      var number = 0;
      if (b.type == BlockType.number) {
        counters[b.indent]++;
        for (var i = b.indent + 1; i < 4; i++) {
          counters[i] = 0;
        }
        number = counters[b.indent];
      } else if (b.isListLike) {
        for (var i = b.indent; i < 4; i++) {
          counters[i] = 0;
        }
      } else {
        for (var i = 0; i < 4; i++) {
          counters[i] = 0;
        }
      }
      out.add(_blockRow(p, accent, b, number));
    }
    return out;
  }

  TextStyle _styleFor(Pal p, _Block b) {
    final s = _fontSize;
    switch (b.type) {
      case BlockType.h1:
        return TextStyle(fontSize: s * 1.7, fontWeight: FontWeight.w800, height: 1.3, color: p.text);
      case BlockType.h2:
        return TextStyle(fontSize: s * 1.35, fontWeight: FontWeight.w700, height: 1.3, color: p.text);
      case BlockType.quote:
        return TextStyle(fontSize: s, height: 1.55, fontStyle: FontStyle.italic, color: p.muted);
      case BlockType.code:
        return TextStyle(
          fontSize: s * 0.92,
          height: 1.5,
          color: p.text,
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Consolas', 'Courier New', 'monospace'],
        );
      case BlockType.todo:
        return TextStyle(
          fontSize: s,
          height: 1.55,
          color: b.checked ? p.muted : p.text,
          decoration: b.checked ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: p.muted,
        );
      default:
        return TextStyle(fontSize: s, height: 1.55, color: p.text);
    }
  }

  String? _hint(_Block b) {
    if (!b.focus.hasFocus) {
      return _blocks.length == 1 && b.type == BlockType.paragraph ? 'Start writing…' : null;
    }
    return switch (b.type) {
      BlockType.h1 => 'Heading 1',
      BlockType.h2 => 'Heading 2',
      BlockType.todo => 'To-do',
      BlockType.bullet || BlockType.number => 'List item',
      BlockType.quote => 'Quote',
      BlockType.code => 'Code',
      BlockType.paragraph => "Type '/' for blocks",
    };
  }

  Widget _blockRow(Pal p, Color accent, _Block b, int number) {
    final style = _styleFor(p, b);
    final lineH = (style.fontSize ?? 14) * (style.height ?? 1.5);

    final field = TextField(
      controller: b.ctrl,
      focusNode: b.focus,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      onTapOutside: (_) {},
      style: style,
      cursorColor: accent,
      decoration: InputDecoration.collapsed(
        hintText: _hint(b),
        hintStyle: style.copyWith(
            color: p.muted.withOpacity(0.45),
            decoration: TextDecoration.none,
            fontStyle: FontStyle.normal),
      ),
    );

    Widget leading = const SizedBox.shrink();
    double leadW = 0;
    switch (b.type) {
      case BlockType.bullet:
        leadW = 22;
        leading = Center(
          child: Container(
            width: b.indent == 0 ? 6 : 5,
            height: b.indent == 0 ? 6 : 5,
            decoration: BoxDecoration(
              shape: b.indent == 2 ? BoxShape.rectangle : BoxShape.circle,
              color: b.indent == 1 ? Colors.transparent : p.muted,
              border: b.indent == 1 ? Border.all(color: p.muted, width: 1.3) : null,
            ),
          ),
        );
      case BlockType.number:
        leadW = 26;
        leading = Align(
          alignment: Alignment.centerLeft,
          child: T('$number.', size: _fontSize, color: p.muted, weight: FontWeight.w600),
        );
      case BlockType.todo:
        leadW = 28;
        leading = Align(
          alignment: Alignment.centerLeft,
          child: ClickableNoRipple(
            onClick: () => _toggleCheck(b),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: b.checked ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: b.checked ? accent : p.muted, width: 1.5),
              ),
              child: b.checked
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ),
        );
      default:
        break;
    }

    Widget content = field;
    if (b.type == BlockType.quote) {
      content = Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
        child: field,
      );
    } else if (b.type == BlockType.code) {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.dark ? const Color(0x33000000) : const Color(0x0F000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        child: field,
      );
    }

    final top = switch (b.type) {
      BlockType.h1 => 14.0,
      BlockType.h2 => 10.0,
      _ => 1.0,
    };

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadW > 0) SizedBox(width: leadW, height: lineH, child: leading),
        Expanded(child: content),
      ],
    );
    return Padding(
      key: b.key,
      padding: EdgeInsets.only(top: top, bottom: 1, left: b.indent * 24.0),
      child: b.focus.hasFocus ? CompositedTransformTarget(link: _link, child: row) : row,
    );
  }

  Widget _popup(Pal p, Color accent, _Sugg s) {
    // Flip above the block when there isn't room below.
    var above = false;
    final box = _target.key.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final y = box.localToGlobal(Offset.zero).dy + box.size.height;
      above = y + 290 > MediaQuery.sizeOf(context).height;
    }
    final sel = _selIdx.clamp(0, s.chips.length - 1);
    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
      offset: Offset(24, above ? -4 : 4),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 250,
          constraints: const BoxConstraints(maxHeight: 290),
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 5),
                child: T(s.title.toUpperCase(), size: 9.5, weight: FontWeight.w700, color: p.muted),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  children: [
                    for (var i = 0; i < s.chips.length; i++)
                      MouseRegion(
                        onEnter: (_) {
                          if (_selIdx != i) setState(() => _selIdx = i);
                        },
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: s.chips[i].onTap,
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: i == sel ? accent.withOpacity(0.16) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                if (s.chips[i].icon != null) ...[
                                  Icon(s.chips[i].icon, size: 15, color: i == sel ? accent : p.muted),
                                  const SizedBox(width: 9),
                                ],
                                Expanded(
                                  child: T(
                                    s.chips[i].label,
                                    size: 12.5,
                                    weight: i == sel ? FontWeight.w600 : FontWeight.w400,
                                    color: i == sel ? p.text : p.muted,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
                child: T('↑↓ navigate  ·  ↵ select  ·  esc close', size: 10, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Suggestion strip / status ---------------------------------------------------

  Widget _suggestionBar(Pal p, Color accent, _Sugg s) {
    return DrawTopBorder(
      color: p.border,
      child: Container(
        height: 40,
        color: p.field.withOpacity(0.55),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            T(s.title.toUpperCase(), size: 9.5, weight: FontWeight.w700, color: p.muted),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in s.chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: HoverBuilder(
                          cursor: SystemMouseCursors.click,
                          onTap: c.onTap,
                          builder: (_, hovered) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: hovered ? accent.withOpacity(0.22) : accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.icon != null) ...[
                                  Icon(c.icon, size: 12, color: accent),
                                  const SizedBox(width: 5),
                                ],
                                T(c.label, size: 11.5, weight: FontWeight.w600, color: accent),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(Pal p) {
    var words = 0;
    var chars = 0;
    var todo = 0;
    var done = 0;
    for (final b in _blocks) {
      final t = b.ctrl.text.trim();
      if (t.isNotEmpty) words += t.split(RegExp(r'\s+')).length;
      chars += b.ctrl.text.length;
      if (b.type == BlockType.todo) {
        todo++;
        if (b.checked) done++;
      }
    }
    final mins = (words / 220).ceil();
    return DrawTopBorder(
      color: p.border,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: T(
                [
                  '$words words',
                  '$chars chars',
                  if (todo > 0) '$done/$todo done',
                  if (words > 0) '~${mins < 1 ? 1 : mins} min read',
                ].join(' · '),
                size: 10.5,
                color: p.muted,
              ),
            ),
            IconBtn(
              icon: Icons.remove_rounded,
              size: 22,
              iconSize: 13,
              tooltip: 'Smaller text',
              onClick: () => setState(() => _fontSize = (_fontSize - 1).clamp(10, 26)),
            ),
            SizedBox(
              width: 34,
              child: T('${(_fontSize / 14 * 100).round()}%',
                  size: 10.5, color: p.muted, align: TextAlign.center),
            ),
            IconBtn(
              icon: Icons.add_rounded,
              size: 22,
              iconSize: 13,
              tooltip: 'Larger text',
              onClick: () => setState(() => _fontSize = (_fontSize + 1).clamp(10, 26)),
            ),
          ],
        ),
      ),
    );
  }
}
