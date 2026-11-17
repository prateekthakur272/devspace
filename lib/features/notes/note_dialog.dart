import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/note_theme.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class NoteDialog extends StatefulWidget {
  const NoteDialog({
    super.key,
    required this.state,
    this.existingNote,
    this.initialProjectId,
    this.initialTag,
  });

  final AppState state;
  final Note? existingNote;
  final String? initialProjectId;
  final String? initialTag;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _newChecklistCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _linksCtrl;

  late List<ChecklistItem> _checklist;
  late List<String> _projectIds;
  late bool _pinned;
  Color? _color;

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _contentCtrl = TextEditingController(text: note?.content ?? '');
    _newChecklistCtrl = TextEditingController();
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
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty && content.isEmpty && _checklist.isEmpty) {
      widget.state.modal = null;
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
      );
      widget.state.updateNote(updated);
    } else {
      final newNote = Note(
        id: 'note_${DateTime.now().microsecondsSinceEpoch}',
        title: title.isEmpty ? 'Untitled Note' : title,
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

    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isEdit = widget.existingNote != null;
    final theme = getThemeForColor(_color);
    final cardBg = theme != null ? theme.surface(p.dark) : p.panel;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ModalScaffold(
        title: isEdit ? 'Edit Note' : 'Create Note',
        width: 580,
        onClose: () => widget.state.modal = null,
        actions: [
          if (isEdit)
            Btn(
              label: 'Delete Note',
              danger: true,
              outlined: true,
              onClick: () {
                widget.state.deleteNote(widget.existingNote!.id);
                widget.state.modal = null;
              },
            ),
          const Spacer(),
          Btn(label: 'Cancel', onClick: () => widget.state.modal = null),
          Btn(
            label: isEdit ? 'Save Changes' : 'Create Note',
            primary: true,
            onClick: _submit,
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Pin Row (Google Keep / Samsung Notes Style)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleCtrl,
                          autofocus: !isEdit,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Title',
                            hintStyle: TextStyle(
                              color: p.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pin Toggle
                      ClickableNoRipple(
                        onClick: () => setState(() => _pinned = !_pinned),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _pinned ? p.accent.withOpacity(0.18) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _pinned ? p.accent : p.border.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _pinned ? AppIcons.pin : AppIcons.unpin,
                                size: 14,
                                color: _pinned ? p.accent : p.muted,
                              ),
                              const SizedBox(width: 4),
                              T(
                                _pinned ? 'Pinned' : 'Pin',
                                size: 11,
                                weight: FontWeight.w600,
                                color: _pinned ? p.accent : p.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Note Body (Freeform Markdown & Links)
                  Container(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      style: TextStyle(color: p.text, fontSize: 13, height: 1.4),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Take a note, write scratchpad commands, or paste URLs…',
                        hintStyle: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checklists Section (Google Keep Interactive Checklist)
                  if (_checklist.isNotEmpty || isEdit) ...[
                    Row(
                      children: [
                        Icon(AppIcons.checklist, size: 14, color: p.accent),
                        const SizedBox(width: 6),
                        T('Checklist', size: 12, weight: FontWeight.w700, color: p.text),
                        if (_checklist.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          T(
                            '(${_checklist.where((c) => c.checked).length}/${_checklist.length} done)',
                            size: 11,
                            color: p.muted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < _checklist.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            ClickableNoRipple(
                              onClick: () {
                                setState(() {
                                  _checklist[i] = _checklist[i].copyWith(
                                    checked: !_checklist[i].checked,
                                  );
                                });
                              },
                              child: Icon(
                                _checklist[i].checked
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 16,
                                color: _checklist[i].checked ? p.accent : p.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _checklist[i].text,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _checklist[i].checked ? p.muted : p.text,
                                  decoration: _checklist[i].checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            IconBtn(
                              icon: AppIcons.close,
                              size: 20,
                              iconSize: 11,
                              onClick: () {
                                setState(() {
                                  _checklist.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],

                  // Add Checklist Item Field (Smooth Keep item adder)
                  Row(
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _newChecklistCtrl,
                          onSubmitted: (_) => _addChecklistItem(),
                          style: TextStyle(color: p.text, fontSize: 12.5),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Add list item…',
                            hintStyle: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                        ),
                      ),
                      if (_newChecklistCtrl.text.isNotEmpty)
                        Btn(
                          label: 'Add',
                          height: 26,
                          onClick: _addChecklistItem,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Project Tagging Chips (Keep-style project labels)
                  T('Link to Project', size: 11.5, weight: FontWeight.w600, color: p.muted),
                  const SizedBox(height: 6),
                  if (widget.state.projects.isEmpty)
                    T('No projects in DevSpace yet.', size: 11, color: p.muted)
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final pr in widget.state.projects)
                          ClickableNoRipple(
                            onClick: () {
                              setState(() {
                                if (_projectIds.contains(pr.id)) {
                                  _projectIds.remove(pr.id);
                                } else {
                                  _projectIds.add(pr.id);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _projectIds.contains(pr.id)
                                    ? p.accent.withOpacity(0.18)
                                    : p.field,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _projectIds.contains(pr.id) ? p.accent : p.border,
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
                                    weight: _projectIds.contains(pr.id)
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _projectIds.contains(pr.id) ? p.text : p.muted,
                                  ),
                                  if (_projectIds.contains(pr.id)) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.check, size: 11, color: p.accent),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),

                  // Tags & Reference Links
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('Tags', size: 11.5, weight: FontWeight.w600, color: p.muted),
                            const SizedBox(height: 5),
                            _ThemedInput(
                              controller: _tagsCtrl,
                              hint: 'todo, deployment, bug…',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('Links', size: 11.5, weight: FontWeight.w600, color: p.muted),
                            const SizedBox(height: 5),
                            _ThemedInput(
                              controller: _linksCtrl,
                              hint: 'https://…, /Users/…',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Keep / Samsung Notes Pastel Color Palette
                  T('Card Color', size: 11.5, weight: FontWeight.w600, color: p.muted),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Default / no color
                      ClickableNoRipple(
                        onClick: () => setState(() => _color = null),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: p.panel,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == null ? p.accent : p.border,
                              width: _color == null ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.block_rounded,
                              size: 13,
                              color: _color == null ? p.accent : p.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final themeOption in kNoteColorThemes) ...[
                        ClickableNoRipple(
                          onClick: () => setState(() => _color = themeOption.accent),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: themeOption.surface(p.dark),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color?.value == themeOption.accent.value
                                    ? p.accent
                                    : themeOption.accent.withOpacity(0.5),
                                width: _color?.value == themeOption.accent.value ? 2 : 1,
                              ),
                            ),
                            child: _color?.value == themeOption.accent.value
                                ? Icon(Icons.check, size: 14, color: themeOption.accent)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemedInput extends StatelessWidget {
  const _ThemedInput({
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -2.0),
          child: TextField(
            controller: controller,
            maxLines: 1,
            cursorHeight: 14,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(color: p.text, fontSize: 12),
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: TextStyle(color: p.muted, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
