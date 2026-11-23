import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/note_markdown.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/note_card.dart';
import 'package:devspace/features/notes/note_pane_editor.dart';
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

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    if (note.checklist.isNotEmpty && !NoteMarkdown.hasTodoLines(note.content)) {
      buffer.writeln('### Checklist');
      for (final item in note.checklist) {
        buffer.writeln('- [${item.checked ? 'x' : ' '}] ${item.text}');
      }
      buffer.writeln();
    }
    if (note.links.any((l) => !note.content.contains(l))) {
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

    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

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
        initialChecklist: widget.state.paneInitialChecklist,
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

          // Quick Note Launcher Bar ("Take a note...")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: _buildQuickNoteBar(context, p),
          ),

          // Notes List
          Expanded(
            child: totalNotesCount == 0
                ? _buildEmpty(context, p)
                : allFiltered.isEmpty
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
                                child: NoteCard(
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
                              child: NoteCard(
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

  // Quick Note Launcher Bar: Starts note creation directly in the Note Editor
  Widget _buildQuickNoteBar(BuildContext context, Pal p) {
    return Container(
      height: 38,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            widget.state.openNewNoteInPane(
              initialProjectId: _selectedProjectId,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                T('Take a note…', size: 12.5, color: p.muted),
                const Spacer(),
                IconBtn(
                  icon: AppIcons.checklist,
                  tooltip: 'New checklist note',
                  size: 26,
                  iconSize: 14,
                  onClick: () {
                    widget.state.openNewNoteInPane(
                      initialProjectId: _selectedProjectId,
                      initialChecklist: true,
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconBtn(
                  icon: AppIcons.project,
                  tooltip: 'New project note',
                  size: 26,
                  iconSize: 13,
                  onClick: () {
                    widget.state.openNewNoteInPane(
                      initialProjectId: _selectedProjectId,
                    );
                  },
                ),
              ],
            ),
          ),
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
              'Capture thoughts, commands, checklists, and project tasks.',
              size: 11.5,
              color: p.muted,
              align: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Btn(
              label: 'Create Note',
              icon: AppIcons.add,
              primary: true,
              height: 30,
              onClick: () {
                widget.state.openNewNoteInPane(
                  initialProjectId: _selectedProjectId,
                );
              },
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
