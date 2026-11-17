import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/note_theme.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class NotePaneEditor extends StatefulWidget {
  const NotePaneEditor({
    super.key,
    required this.state,
    this.existingNote,
    this.initialProjectId,
    this.initialTag,
    required this.onClose,
  });

  final AppState state;
  final Note? existingNote;
  final String? initialProjectId;
  final String? initialTag;
  final VoidCallback onClose;

  @override
  State<NotePaneEditor> createState() => _NotePaneEditorState();
}

class _NotePaneEditorState extends State<NotePaneEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _newChecklistCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _linksCtrl;
  late final FocusNode _newChecklistFocusNode;

  late List<ChecklistItem> _checklist;
  late List<String> _projectIds;
  late bool _pinned;
  Color? _color;
  bool _showColorPicker = false;

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _contentCtrl = TextEditingController(text: note?.content ?? '');
    _newChecklistCtrl = TextEditingController();
    _newChecklistFocusNode = FocusNode();
    _tagsCtrl = TextEditingController(
      text: note != null
          ? note.tags.join(', ')
          : (widget.initialTag != null ? widget.initialTag! : ''),
    );
    _linksCtrl = TextEditingController(text: note?.links.join(', ') ?? '');

    _checklist = note != null ? List.from(note.checklist) : [];
    _projectIds = note != null
        ? List.from(note.projectIds)
        : (widget.initialProjectId != null ? [widget.initialProjectId!] : []);
    _pinned = note?.pinned ?? false;
    _color = note?.color;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _newChecklistCtrl.dispose();
    _newChecklistFocusNode.dispose();
    _tagsCtrl.dispose();
    _linksCtrl.dispose();
    super.dispose();
  }

  void _addChecklistItem() {
    final text = _newChecklistCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(ChecklistItem(
        id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        checked: false,
      ));
      _newChecklistCtrl.clear();
    });
    _newChecklistFocusNode.requestFocus();
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      final item = _checklist[index];
      _checklist[index] = item.copyWith(checked: !item.checked);
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklist.removeAt(index);
    });
  }

  void _saveAndClose() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    // If completely empty and new, simply close without saving an empty card
    if (title.isEmpty && content.isEmpty && _checklist.isEmpty && widget.existingNote == null) {
      widget.onClose();
      return;
    }

    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e : '#$e')
        .toList();

    final links = _linksCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (widget.existingNote != null) {
      final updated = widget.existingNote!.copyWith(
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        checklist: _checklist,
        projectIds: _projectIds,
        tags: tags,
        links: links,
        pinned: _pinned,
        color: _color,
        clearColor: _color == null,
        updatedAt: DateTime.now(),
      );
      widget.state.updateNote(updated);
    } else {
      final newNote = Note(
        id: 'note_${DateTime.now().microsecondsSinceEpoch}',
        title: title.isEmpty ? (content.isNotEmpty ? '' : 'Untitled Note') : title,
        content: content,
        checklist: _checklist,
        projectIds: _projectIds,
        tags: tags,
        links: links,
        pinned: _pinned,
        color: _color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.state.addNote(newNote);
    }

    widget.onClose();
  }

  void _copyMarkdown() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln('# $title\n');
    }
    if (content.isNotEmpty) {
      buffer.writeln('$content\n');
    }
    if (_checklist.isNotEmpty) {
      buffer.writeln('### Checklist');
      for (final item in _checklist) {
        buffer.writeln('- [${item.checked ? 'x' : ' '}] ${item.text}');
      }
      buffer.writeln();
    }
    if (_linksCtrl.text.isNotEmpty) {
      buffer.writeln('### Links');
      for (final l in _linksCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
        buffer.writeln('- $l');
      }
      buffer.writeln();
    }
    if (_tagsCtrl.text.isNotEmpty) {
      buffer.writeln(_tagsCtrl.text.trim());
    }
    Platform.copy(buffer.toString().trim());
  }

  void _deleteNote() {
    if (widget.existingNote != null) {
      widget.state.deleteNote(widget.existingNote!.id);
      widget.onClose();
    }
  }

  void _showAddProjectMenu(BuildContext context, Offset pos) {
    final available = widget.state.projects
        .where((p) => !_projectIds.contains(p.id))
        .toList();

    if (available.isEmpty) return;

    final items = available.map((p) {
      return ContextMenuItem(
        label: p.name,
        icon: AppIcons.project,
        action: () {
          setState(() {
            _projectIds.add(p.id);
          });
        },
      );
    }).toList();

    ContextMenu.show(context, pos, items);
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final theme = getThemeForColor(_color);
    final surfaceBg = theme != null ? theme.surface(p.dark) : p.panel;
    final checkedCount = _checklist.where((c) => c.checked).length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.escape): _saveAndClose,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: surfaceBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Editor Header Toolbar
              DrawBottomBorder(
                color: p.border,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Back to Notes List
                      IconBtn(
                        icon: AppIcons.back,
                        tooltip: 'Back to notes (auto-saves)',
                        size: 30,
                        iconSize: 16,
                        onClick: _saveAndClose,
                      ),
                      const SizedBox(width: 4),
                      T(
                        widget.existingNote != null ? 'Edit Note' : 'New Note',
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      const Spacer(),
                      // Pin Toggle
                      IconBtn(
                        icon: _pinned ? AppIcons.pin : AppIcons.unpin,
                        tooltip: _pinned ? 'Unpin Note' : 'Pin to Top',
                        size: 28,
                        iconSize: 14,
                        color: _pinned ? p.accent : p.muted,
                        onClick: () => setState(() => _pinned = !_pinned),
                      ),
                      const SizedBox(width: 2),
                      // Color Palette Toggle
                      ClickableNoRipple(
                        onClick: () => setState(() => _showColorPicker = !_showColorPicker),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _color ?? p.panel,
                            border: Border.all(
                              color: _showColorPicker ? p.accent : p.border,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.palette_outlined,
                              size: 13,
                              color: _color != null ? Colors.white : p.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Copy as Markdown
                      IconBtn(
                        icon: AppIcons.copy,
                        tooltip: 'Copy as Markdown',
                        size: 28,
                        iconSize: 13,
                        onClick: _copyMarkdown,
                      ),
                      if (widget.existingNote != null) ...[
                        const SizedBox(width: 2),
                        IconBtn(
                          icon: AppIcons.delete,
                          tooltip: 'Delete Note',
                          size: 28,
                          iconSize: 14,
                          color: p.err,
                          onClick: _deleteNote,
                        ),
                      ],
                      const SizedBox(width: 6),
                      // Done / Save Button
                      Btn(
                        label: 'Done',
                        primary: true,
                        height: 26,
                        fontSize: 11.5,
                        onClick: _saveAndClose,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable Color Picker Bar
              if (_showColorPicker)
                DrawBottomBorder(
                  color: p.border,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: p.field.withOpacity(0.5),
                    child: Row(
                      children: [
                        // Default / Reset color dot
                        ClickableNoRipple(
                          onClick: () => setState(() {
                            _color = null;
                            _showColorPicker = false;
                          }),
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.panel,
                              border: Border.all(
                                color: _color == null ? p.accent : p.border,
                                width: _color == null ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.close, size: 10, color: p.muted),
                            ),
                          ),
                        ),
                        // 9 Pastel themes
                        for (final t in kNoteColorThemes) ...[
                          ClickableNoRipple(
                            onClick: () => setState(() {
                              _color = t.accent;
                              _showColorPicker = false;
                            }),
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.accent,
                                border: Border.all(
                                  color: _color == t.accent ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: _color == t.accent
                                    ? [
                                        BoxShadow(
                                          color: t.accent.withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Scrollable Note Editor Form
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Note Title
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                      cursorColor: p.accent,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.muted.withOpacity(0.65),
                        ),
                      ),
                    ),
                    if (widget.existingNote != null) ...[
                      const SizedBox(height: 4),
                      T(
                        'Edited ${_formatTime(widget.existingNote!.updatedAt)}',
                        size: 10.5,
                        color: p.muted,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Associated Projects Section
                    Row(
                      children: [
                        Icon(AppIcons.project, size: 12, color: p.muted),
                        const SizedBox(width: 4),
                        T(
                          'PROJECTS',
                          size: 10,
                          weight: FontWeight.w700,
                          color: p.muted,
                        ),
                        const Spacer(),
                        if (widget.state.projects.any((p) => !_projectIds.contains(p.id)))
                          Builder(
                            builder: (btnCtx) {
                              return ClickableNoRipple(
                                onClick: () {
                                  final box = btnCtx.findRenderObject() as RenderBox?;
                                  if (box != null) {
                                    final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                                    _showAddProjectMenu(context, pos);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: p.field,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: p.border, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 11, color: p.muted),
                                      const SizedBox(width: 2),
                                      T('Tag Project', size: 10, color: p.muted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_projectIds.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final pid in _projectIds)
                            Builder(
                              builder: (_) {
                                final pr = widget.state.projects
                                    .cast<Project?>()
                                    .firstWhere((p) => p?.id == pid, orElse: () => null);
                                if (pr == null) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: pr.techStack.color.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: pr.techStack.color.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: pr.techStack.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      T(
                                        pr.name,
                                        size: 11,
                                        weight: FontWeight.w600,
                                        color: pr.techStack.color,
                                      ),
                                      const SizedBox(width: 4),
                                      ClickableNoRipple(
                                        onClick: () => setState(() => _projectIds.remove(pid)),
                                        child: Icon(Icons.close, size: 11, color: pr.techStack.color),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: T(
                          'No projects tagged',
                          size: 11,
                          color: p.muted.withOpacity(0.7),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Interactive Checklist Section
                    Row(
                      children: [
                        Icon(AppIcons.checklist, size: 13, color: p.muted),
                        const SizedBox(width: 4),
                        T(
                          'CHECKLIST',
                          size: 10,
                          weight: FontWeight.w700,
                          color: p.muted,
                        ),
                        if (_checklist.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: p.accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: T(
                              '$checkedCount/${_checklist.length}',
                              size: 10,
                              weight: FontWeight.w600,
                              color: p.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Existing Checklist Items
                    for (int i = 0; i < _checklist.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClickableNoRipple(
                              onClick: () => _toggleChecklistItem(i),
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: _checklist[i].checked
                                      ? p.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _checklist[i].checked ? p.accent : p.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: _checklist[i].checked
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: _checklist[i].text,
                                onChanged: (val) {
                                  _checklist[i] = _checklist[i].copyWith(text: val);
                                },
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _checklist[i].checked
                                      ? p.muted
                                      : p.text,
                                  decoration: _checklist[i].checked
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                                cursorColor: p.accent,
                                decoration: const InputDecoration.collapsed(hintText: ''),
                              ),
                            ),
                            ClickableNoRipple(
                              onClick: () => _removeChecklistItem(i),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(Icons.close, size: 13, color: p.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Add Checklist Item Input
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 12),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: p.field.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border.withOpacity(0.7), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: p.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _newChecklistCtrl,
                              focusNode: _newChecklistFocusNode,
                              onSubmitted: (_) => _addChecklistItem(),
                              style: TextStyle(fontSize: 12, color: p.text),
                              cursorColor: p.accent,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Add checklist item (press Enter)…',
                                hintStyle: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            ),
                          ),
                          if (_newChecklistCtrl.text.isNotEmpty)
                            ClickableNoRipple(
                              onClick: _addChecklistItem,
                              child: Icon(Icons.check, size: 14, color: p.accent),
                            ),
                        ],
                      ),
                    ),

                    // Freeform Note Body
                    T(
                      'NOTE CONTENT',
                      size: 10,
                      weight: FontWeight.w700,
                      color: p.muted,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.field.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border.withOpacity(0.7), width: 1),
                      ),
                      child: TextField(
                        controller: _contentCtrl,
                        minLines: 5,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: p.text,
                        ),
                        cursorColor: p.accent,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Take a note or paste snippets, markdown, shell commands…',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: p.muted.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tags Section
                    T(
                      'TAGS',
                      size: 10,
                      weight: FontWeight.w700,
                      color: p.muted,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: p.field.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border.withOpacity(0.7), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag_rounded, size: 13, color: p.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _tagsCtrl,
                              style: TextStyle(fontSize: 12, color: p.text),
                              cursorColor: p.accent,
                              decoration: InputDecoration.collapsed(
                                hintText: '#todo, #docs, #deploy (comma separated)',
                                hintStyle: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Links & Paths Section
                    Row(
                      children: [
                        Icon(AppIcons.link, size: 12, color: p.muted),
                        const SizedBox(width: 4),
                        T(
                          'LINKS & PATHS',
                          size: 10,
                          weight: FontWeight.w700,
                          color: p.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: p.field.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border.withOpacity(0.7), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.link, size: 13, color: p.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _linksCtrl,
                              style: TextStyle(fontSize: 12, color: p.text),
                              cursorColor: p.accent,
                              decoration: InputDecoration.collapsed(
                                hintText: 'https://…, /local/path… (comma separated)',
                                hintStyle: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
