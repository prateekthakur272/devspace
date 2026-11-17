import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/note_pane_editor.dart';
import 'package:devspace/features/notes/note_theme.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

enum _PaneFilter { all, pinned, checklist, project }

class NotesPane extends StatefulWidget {
  const NotesPane({super.key, required this.state});
  final AppState state;

  @override
  State<NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends State<NotesPane> {
  String _searchQuery = '';
  _PaneFilter _filter = _PaneFilter.all;
  String? _selectedProjectId;
  late final TextEditingController _searchCtrl;

  // Inline Quick-Note Creator State (Google Keep / Samsung Notes)
  bool _isCreating = false;
  bool _checklistMode = false;
  final TextEditingController _createTitleCtrl = TextEditingController();
  final TextEditingController _createContentCtrl = TextEditingController();
  final TextEditingController _createChecklistCtrl = TextEditingController();
  final List<ChecklistItem> _createChecklist = [];
  final List<String> _createProjectIds = [];
  bool _createPinned = false;
  Color? _createColor;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _createTitleCtrl.dispose();
    _createContentCtrl.dispose();
    _createChecklistCtrl.dispose();
    super.dispose();
  }

  void _resetCreator() {
    setState(() {
      _isCreating = false;
      _checklistMode = false;
      _createTitleCtrl.clear();
      _createContentCtrl.clear();
      _createChecklistCtrl.clear();
      _createChecklist.clear();
      _createProjectIds.clear();
      _createPinned = false;
      _createColor = null;
    });
  }

  void _submitInlineNote() {
    final title = _createTitleCtrl.text.trim();
    final content = _createContentCtrl.text.trim();

    if (title.isEmpty && content.isEmpty && _createChecklist.isEmpty) {
      _resetCreator();
      return;
    }

    final newNote = Note(
      id: 'note_${DateTime.now().microsecondsSinceEpoch}',
      title: title.isEmpty ? (content.isNotEmpty ? '' : 'Untitled Note') : title,
      content: content,
      checklist: List.from(_createChecklist),
      projectIds: List.from(_createProjectIds),
      pinned: _createPinned,
      color: _createColor,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.state.addNote(newNote);
    _resetCreator();
  }

  void _addInlineChecklistItem() {
    final text = _createChecklistCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _createChecklist.add(ChecklistItem(
        id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        checked: false,
      ));
      _createChecklistCtrl.clear();
    });
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _copyNoteAsMarkdown(Note note) {
    final buffer = StringBuffer();
    if (note.title.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }
    if (note.content.isNotEmpty) {
      buffer.writeln(note.content);
      buffer.writeln();
    }
    if (note.checklist.isNotEmpty) {
      buffer.writeln('### Checklist');
      for (final item in note.checklist) {
        buffer.writeln('- [${item.checked ? 'x' : ' '}] ${item.text}');
      }
      buffer.writeln();
    }
    if (note.links.isNotEmpty) {
      buffer.writeln('### Links');
      for (final link in note.links) {
        buffer.writeln('- $link');
      }
      buffer.writeln();
    }
    if (note.tags.isNotEmpty) {
      buffer.writeln(note.tags.join(' '));
    }
    Platform.copy(buffer.toString().trim());
  }

  List<Note> _getFilteredNotes() {
    var list = widget.state.notes.toList();

    // 1. Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((n) {
        final titleMatch = n.title.toLowerCase().contains(q);
        final contentMatch = n.content.toLowerCase().contains(q);
        final tagMatch = n.tags.any((t) => t.toLowerCase().contains(q));
        final linkMatch = n.links.any((l) => l.toLowerCase().contains(q));
        final checklistMatch =
            n.checklist.any((c) => c.text.toLowerCase().contains(q));
        final projectMatch = n.projectIds.any((pid) {
          final pr = widget.state.projects.cast<Project?>().firstWhere(
                (p) => p?.id == pid,
                orElse: () => null,
              );
          return pr != null && pr.name.toLowerCase().contains(q);
        });
        return titleMatch ||
            contentMatch ||
            tagMatch ||
            linkMatch ||
            checklistMatch ||
            projectMatch;
      }).toList();
    }

    // 2. Filter Pills
    switch (_filter) {
      case _PaneFilter.pinned:
        list = list.where((n) => n.pinned).toList();
        break;
      case _PaneFilter.checklist:
        list = list.where((n) => n.checklist.isNotEmpty).toList();
        break;
      case _PaneFilter.project:
        if (_selectedProjectId != null) {
          list = list.where((n) => n.projectIds.contains(_selectedProjectId)).toList();
        } else {
          list = list.where((n) => n.projectIds.isNotEmpty).toList();
        }
        break;
      case _PaneFilter.all:
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.paneEditingNote != null || widget.state.paneCreatingNote) {
      return NotePaneEditor(
        state: widget.state,
        existingNote: widget.state.paneEditingNote,
        initialProjectId: widget.state.paneInitialProjectId ?? _selectedProjectId,
        initialTag: widget.state.paneInitialTag,
        onClose: () => widget.state.closePaneNoteEditor(),
      );
    }

    final p = context.pal;
    final allFiltered = _getFilteredNotes();
    final pinnedNotes = allFiltered.where((n) => n.pinned).toList();
    final otherNotes = allFiltered.where((n) => !n.pinned).toList();
    final totalNotesCount = widget.state.notes.length;

    return Container(
      color: p.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pane Header
          DrawBottomBorder(
            color: p.border,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(AppIcons.note, size: 16, color: p.accent),
                  const SizedBox(width: 8),
                  const T('Notes & Tasks', size: 13, weight: FontWeight.w700),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: p.accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: T(
                      '$totalNotesCount',
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const Spacer(),
                  IconBtn(
                    icon: AppIcons.add,
                    tooltip: 'New Note',
                    size: 28,
                    iconSize: 15,
                    onClick: () {
                      widget.state.openNewNoteInPane(
                        initialProjectId: _selectedProjectId,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconBtn(
                    icon: AppIcons.close,
                    tooltip: 'Close Notes Pane',
                    size: 28,
                    iconSize: 14,
                    onClick: () => widget.state.toggleNotesPane(),
                  ),
                ],
              ),
            ),
          ),

          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search box
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.search, size: 13, color: p.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, -2.0),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              maxLines: 1,
                              cursorHeight: 13,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: p.text, fontSize: 12),
                              decoration: InputDecoration.collapsed(
                                hintText: 'Search notes…',
                                hintStyle: TextStyle(color: p.muted, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconBtn(
                          icon: AppIcons.close,
                          size: 18,
                          iconSize: 10,
                          onClick: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PaneChip(
                        label: 'All',
                        selected: _filter == _PaneFilter.all && _selectedProjectId == null,
                        onClick: () => setState(() {
                          _filter = _PaneFilter.all;
                          _selectedProjectId = null;
                        }),
                      ),
                      const SizedBox(width: 4),
                      _PaneChip(
                        label: 'Pinned',
                        icon: AppIcons.pin,
                        selected: _filter == _PaneFilter.pinned,
                        onClick: () => setState(() => _filter = _PaneFilter.pinned),
                      ),
                      const SizedBox(width: 4),
                      _PaneChip(
                        label: 'Checklists',
                        icon: AppIcons.checklist,
                        selected: _filter == _PaneFilter.checklist,
                        onClick: () => setState(() => _filter = _PaneFilter.checklist),
                      ),
                      const SizedBox(width: 4),
                      _PaneChip(
                        label: 'Projects',
                        icon: AppIcons.project,
                        selected: _filter == _PaneFilter.project,
                        onClick: () => setState(() => _filter = _PaneFilter.project),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Google Keep / Samsung Notes Inline Note Creator ("Take a note...")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: _buildInlineCreator(context, p),
          ),

          // Notes List (Google Keep & Samsung Notes Layout)
          Expanded(
            child: totalNotesCount == 0 && !_isCreating
                ? _buildEmpty(context, p)
                : allFiltered.isEmpty && !_isCreating
                    ? Center(
                        child: T('No matching notes found', size: 12, color: p.muted),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        children: [
                          // PINNED SECTION (Google Keep pattern)
                          if (pinnedNotes.isNotEmpty) ...[
                            if (otherNotes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
                                child: T(
                                  'PINNED',
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: p.muted,
                                ),
                              ),
                            for (final note in pinnedNotes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _KeepNoteCard(
                                  note: note,
                                  state: widget.state,
                                  formatTime: _formatTime,
                                  onCopy: () => _copyNoteAsMarkdown(note),
                                ),
                              ),
                          ],

                          // OTHERS SECTION
                          if (pinnedNotes.isNotEmpty && otherNotes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 6, top: 10),
                              child: T(
                                'OTHERS',
                                size: 10,
                                weight: FontWeight.w700,
                                color: p.muted,
                              ),
                            ),
                          for (final note in otherNotes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _KeepNoteCard(
                                note: note,
                                state: widget.state,
                                formatTime: _formatTime,
                                onCopy: () => _copyNoteAsMarkdown(note),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // Google Keep / Samsung Notes Inline Creator Bar
  Widget _buildInlineCreator(BuildContext context, Pal p) {
    if (!_isCreating) {
      // Collapsed State: "Take a note…"
      return ClickableNoRipple(
        onClick: () => setState(() => _isCreating = true),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border.withOpacity(0.8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(p.dark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              T('Take a note…', size: 12.5, color: p.muted),
              const Spacer(),
              IconBtn(
                icon: AppIcons.checklist,
                tooltip: 'New checklist',
                size: 26,
                iconSize: 14,
                onClick: () {
                  setState(() {
                    _isCreating = true;
                    _checklistMode = true;
                  });
                },
              ),
              const SizedBox(width: 4),
              IconBtn(
                icon: AppIcons.project,
                tooltip: 'Link project',
                size: 26,
                iconSize: 13,
                onClick: () {
                  setState(() {
                    _isCreating = true;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    // Expanded State: Full Rich Inline Note Creator
    final theme = getThemeForColor(_createColor);
    final creatorBg = theme != null ? theme.surface(p.dark) : p.field;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _submitInlineNote();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _resetCreator();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: creatorBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _createColor ?? p.accent.withOpacity(0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(p.dark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Pin
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _createTitleCtrl,
                    autofocus: true,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Title',
                      hintStyle: TextStyle(
                        color: p.muted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconBtn(
                  icon: _createPinned ? AppIcons.pin : AppIcons.unpin,
                  size: 24,
                  iconSize: 13,
                  color: _createPinned ? p.accent : p.muted,
                  tooltip: _createPinned ? 'Unpin' : 'Pin to top',
                  onClick: () => setState(() => _createPinned = !_createPinned),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Freeform Note Content
            Container(
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 120),
              child: TextField(
                controller: _createContentCtrl,
                maxLines: null,
                style: TextStyle(color: p.text, fontSize: 12.5, height: 1.35),
                decoration: InputDecoration.collapsed(
                  hintText: 'Take a note…',
                  hintStyle: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ),
            ),

            // Live Checklist Items if in Checklist Mode
            if (_checklistMode || _createChecklist.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (int i = 0; i < _createChecklist.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      ClickableNoRipple(
                        onClick: () {
                          setState(() {
                            _createChecklist[i] = _createChecklist[i].copyWith(
                              checked: !_createChecklist[i].checked,
                            );
                          });
                        },
                        child: Icon(
                          _createChecklist[i].checked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 14,
                          color: _createChecklist[i].checked ? p.accent : p.muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _createChecklist[i].text,
                          style: TextStyle(
                            fontSize: 12,
                            color: _createChecklist[i].checked ? p.muted : p.text,
                            decoration: _createChecklist[i].checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      IconBtn(
                        icon: AppIcons.close,
                        size: 18,
                        iconSize: 10,
                        onClick: () => setState(() => _createChecklist.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ],
              // Add checklist item field
              Row(
                children: [
                  Icon(Icons.add_rounded, size: 14, color: p.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _createChecklistCtrl,
                      onSubmitted: (_) => _addInlineChecklistItem(),
                      style: TextStyle(color: p.text, fontSize: 12),
                      decoration: InputDecoration.collapsed(
                        hintText: 'List item (Press Enter to add)…',
                        hintStyle: TextStyle(color: p.muted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Project Selector Chips
            if (widget.state.projects.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final pr in widget.state.projects) ...[
                      ClickableNoRipple(
                        onClick: () {
                          setState(() {
                            if (_createProjectIds.contains(pr.id)) {
                              _createProjectIds.remove(pr.id);
                            } else {
                              _createProjectIds.add(pr.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: _createProjectIds.contains(pr.id)
                                ? p.accent.withOpacity(0.2)
                                : p.panel,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _createProjectIds.contains(pr.id)
                                  ? p.accent
                                  : p.border.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: pr.techStack.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              T(
                                pr.name,
                                size: 10,
                                weight: _createProjectIds.contains(pr.id)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _createProjectIds.contains(pr.id) ? p.text : p.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Bottom Action Bar (Colors + Checklist Toggle + Done Button)
            Row(
              children: [
                // Color dots (Keep Palette)
                for (final cOption in kNoteColorThemes.take(6)) ...[
                  ClickableNoRipple(
                    onClick: () => setState(() => _createColor = cOption.accent),
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: cOption.surface(p.dark),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _createColor?.value == cOption.accent.value
                              ? p.accent
                              : cOption.accent.withOpacity(0.5),
                          width: _createColor?.value == cOption.accent.value ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ],
                // Reset color dot
                ClickableNoRipple(
                  onClick: () => setState(() => _createColor = null),
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: p.panel,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _createColor == null ? p.accent : p.border,
                        width: _createColor == null ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.close, size: 9, color: p.muted),
                    ),
                  ),
                ),
                // Checklist toggle
                IconBtn(
                  icon: AppIcons.checklist,
                  size: 22,
                  iconSize: 13,
                  active: _checklistMode,
                  tooltip: 'Checklist mode',
                  onClick: () => setState(() => _checklistMode = !_checklistMode),
                ),
                const Spacer(),
                Btn(
                  label: 'Cancel',
                  height: 26,
                  onClick: _resetCreator,
                ),
                const SizedBox(width: 6),
                Btn(
                  label: 'Done',
                  primary: true,
                  height: 26,
                  onClick: _submitInlineNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Pal p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(AppIcons.note, size: 22, color: p.accent),
              ),
            ),
            const SizedBox(height: 12),
            const T('Notes & scratchpad', size: 14, weight: FontWeight.w600),
            const SizedBox(height: 6),
            T(
              'Capture thoughts, commands, checklists, and project tasks using the bar above.',
              size: 11.5,
              color: p.muted,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneChip extends StatelessWidget {
  const _PaneChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onClick,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClickableNoRipple(
      onClick: onClick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: selected ? p.accent.withOpacity(0.16) : p.field,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? p.accent : p.border.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: selected ? p.accent : p.muted),
              const SizedBox(width: 4),
            ],
            T(
              label,
              size: 11,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? p.accent : p.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// Google Keep & Samsung Notes Card
class _KeepNoteCard extends StatelessWidget {
  const _KeepNoteCard({
    required this.note,
    required this.state,
    required this.formatTime,
    required this.onCopy,
  });

  final Note note;
  final AppState state;
  final String Function(DateTime) formatTime;
  final VoidCallback onCopy;

  void _openLink(String raw) {
    final link = raw.trim();
    if (link.startsWith('http://') || link.startsWith('https://')) {
      Platform.openUrl(link);
    } else if (link.startsWith('/') || link.contains(':\\')) {
      Platform.reveal(link);
    } else {
      Platform.openUrl('https://$link');
    }
  }

  void _showMenu(BuildContext context, Offset pos) {
    ContextMenu.show(context, pos, [
      ContextMenuItem(
        label: 'Edit Note…',
        icon: AppIcons.edit,
        action: () => state.openNoteInPane(note),
      ),
      ContextMenuItem(
        label: note.pinned ? 'Unpin Note' : 'Pin to Top',
        icon: note.pinned ? AppIcons.unpin : AppIcons.pin,
        action: () => state.togglePinNote(note.id),
      ),
      ContextMenuItem(
        label: 'Copy as Markdown',
        icon: AppIcons.copy,
        action: onCopy,
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Delete Note',
        icon: AppIcons.delete,
        danger: true,
        action: () => state.deleteNote(note.id),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final theme = getThemeForColor(note.color);
    final cardBg = theme != null ? theme.surface(p.dark) : p.panel;
    final cardBorder = theme != null
        ? theme.accent.withOpacity(0.35)
        : p.border;
    final totalChecklist = note.checklist.length;
    final checkedCount = note.checklist.where((c) => c.checked).length;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => state.openNoteInPane(note),
      builder: (context, hovered) {
        return GestureDetector(
          onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovered ? p.accent.withOpacity(0.7) : cardBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    hovered ? (p.dark ? 0.35 : 0.09) : (p.dark ? 0.2 : 0.04),
                  ),
                  blurRadius: hovered ? 8 : 3,
                  offset: Offset(0, hovered ? 3 : 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header: Project Badges & Pin
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 8, top: 8),
                    child: Row(
                      children: [
                        // Tagged projects
                        if (note.projectIds.isNotEmpty) ...[
                          for (final pid in note.projectIds.take(2)) ...[
                            Builder(
                              builder: (_) {
                                final pr = state.projects
                                    .cast<Project?>()
                                    .firstWhere((p) => p?.id == pid,
                                        orElse: () => null);
                                if (pr == null) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: pr.techStack.color.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: pr.techStack.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      T(
                                        pr.name,
                                        size: 9.5,
                                        weight: FontWeight.w600,
                                        color: pr.techStack.color,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                        const Spacer(),
                        // Pin Icon Button
                        IconBtn(
                          icon: note.pinned ? AppIcons.pin : AppIcons.unpin,
                          size: 20,
                          iconSize: 12,
                          color: note.pinned ? p.accent : p.muted,
                          tooltip: note.pinned ? 'Unpin' : 'Pin to top',
                          onClick: () => state.togglePinNote(note.id),
                        ),
                        // Quick Context Menu
                        IconBtn(
                          icon: AppIcons.dots,
                          size: 20,
                          iconSize: 11,
                          onClick: () {
                            final box = context.findRenderObject() as RenderBox?;
                            if (box != null) {
                              final pos = box.localToGlobal(
                                  Offset(box.size.width - 100, 20));
                              _showMenu(context, pos);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Title & Content Body
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (note.title.isNotEmpty)
                          T(
                            note.title,
                            size: 13,
                            weight: FontWeight.w700,
                            maxLines: 2,
                          ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          T(
                            note.content,
                            size: 11.5,
                            color: p.text.withOpacity(0.85),
                            maxLines: 4,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Interactive Checklist Items (Google Keep Style)
                  if (totalChecklist > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              T(
                                '$checkedCount/$totalChecklist completed',
                                size: 9.5,
                                weight: FontWeight.w600,
                                color: p.muted,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 45,
                                height: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(1.5),
                                  child: LinearProgressIndicator(
                                    value: checkedCount / totalChecklist,
                                    backgroundColor: p.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      checkedCount == totalChecklist
                                          ? p.ok
                                          : p.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          for (final item in note.checklist.take(4)) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Row(
                                children: [
                                  ClickableNoRipple(
                                    onClick: () => state.toggleChecklistItem(
                                        note.id, item.id),
                                    child: Icon(
                                      item.checked
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      size: 13,
                                      color: item.checked ? p.accent : p.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: item.checked ? p.muted : p.text,
                                        decoration: item.checked
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (totalChecklist > 4)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: T(
                                '+${totalChecklist - 4} more tasks…',
                                size: 9.5,
                                color: p.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Reference Links Chips
                  if (note.links.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final link in note.links.take(2))
                            ClickableNoRipple(
                              onClick: () => _openLink(link),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: p.field.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                      color: p.border.withOpacity(0.5), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.link, size: 9, color: p.accent),
                                    const SizedBox(width: 3),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 100),
                                      child: T(
                                        link,
                                        size: 9.5,
                                        color: p.accent,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Footer: Relative timestamp & Copy action
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 10, right: 8, bottom: 6, top: 4),
                    child: Row(
                      children: [
                        if (note.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: T(
                              note.tags.first,
                              size: 9.5,
                              color: p.muted,
                            ),
                          ),
                        const Spacer(),
                        T(
                          formatTime(note.updatedAt),
                          size: 9.5,
                          color: p.muted,
                        ),
                        const SizedBox(width: 4),
                        IconBtn(
                          icon: AppIcons.copy,
                          tooltip: 'Copy as Markdown',
                          size: 18,
                          iconSize: 10,
                          onClick: onCopy,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
