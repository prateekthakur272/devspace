import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

enum NoteFilterType { all, pinned, checklist, tagged }

enum NoteSortType {
  updated('Recently Updated', Icons.schedule_rounded),
  created('Date Created', Icons.fiber_new_rounded),
  title('Title (A–Z)', Icons.sort_by_alpha_rounded);

  const NoteSortType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class NotesView extends StatefulWidget {
  const NotesView({super.key, required this.state});
  final AppState state;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  String _searchQuery = '';
  NoteFilterType _filter = NoteFilterType.all;
  NoteSortType _sortBy = NoteSortType.updated;
  String? _selectedProjectId;
  String? _selectedTag;
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
      case NoteFilterType.pinned:
        list = list.where((n) => n.pinned).toList();
        break;
      case NoteFilterType.checklist:
        list = list.where((n) => n.checklist.isNotEmpty).toList();
        break;
      case NoteFilterType.tagged:
        list = list.where((n) => n.projectIds.isNotEmpty).toList();
        break;
      case NoteFilterType.all:
        break;
    }

    // 3. Project Filter
    if (_selectedProjectId != null) {
      list = list.where((n) => n.projectIds.contains(_selectedProjectId)).toList();
    }

    // 4. Tag Filter
    if (_selectedTag != null) {
      list = list.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    // 5. Sorting
    list.sort((a, b) {
      // Pinned notes always on top
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;

      return switch (_sortBy) {
        NoteSortType.updated => b.updatedAt.compareTo(a.updatedAt),
        NoteSortType.created => b.createdAt.compareTo(a.createdAt),
        NoteSortType.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final notes = _getFilteredNotes();
    final allNotesCount = widget.state.notes.length;
    final pinnedCount = widget.state.notes.where((n) => n.pinned).length;
    final checklistCount =
        widget.state.notes.where((n) => n.checklist.isNotEmpty).length;

    return Container(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Controls
          DrawBottomBorder(
            color: p.border,
            child: Container(
              color: p.panel,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(AppIcons.note, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  const T('Notes & Checklists', size: 15, weight: FontWeight.w700),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: p.accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: T(
                      '$allNotesCount',
                      size: 11,
                      weight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const Spacer(),
                  // Search Box
                  SizedBox(
                    width: 220,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.border, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(AppIcons.search, size: 14, color: p.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Center(
                              child: Transform.translate(
                                offset: const Offset(0, -2.0),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                  maxLines: 1,
                                  cursorHeight: 14,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(color: p.text, fontSize: 12.5),
                                  decoration: InputDecoration.collapsed(
                                    hintText: 'Search notes & tasks…',
                                    hintStyle: TextStyle(
                                      color: p.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            IconBtn(
                              icon: AppIcons.close,
                              size: 20,
                              iconSize: 11,
                              onClick: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort Dropdown
                  Builder(
                    builder: (btnCtx) => Btn(
                      icon: _sortBy.icon,
                      label: _sortBy.label,
                      outlined: true,
                      height: 34,
                      fontSize: 12,
                      onClick: () {
                        final box = btnCtx.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final pos =
                              box.localToGlobal(Offset(0, box.size.height + 4));
                          ContextMenu.show(context, pos, [
                            for (final opt in NoteSortType.values)
                              ContextMenuItem(
                                label: opt.label,
                                icon: opt.icon,
                                leading: opt == _sortBy
                                    ? Icon(Icons.check_rounded,
                                        size: 14, color: p.accent)
                                    : const SizedBox(width: 14),
                                action: () => setState(() => _sortBy = opt),
                              ),
                          ]);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // New Note Button
                  Btn(
                    label: 'New Note',
                    icon: AppIcons.add,
                    primary: true,
                    height: 34,
                    onClick: () {
                      widget.state.openNewNoteInPane(
                        initialProjectId: _selectedProjectId,
                        initialTag: _selectedTag,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Secondary Filter Strip
          Container(
            color: p.panel.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                _FilterPill(
                  label: 'All Notes',
                  count: allNotesCount,
                  selected: _filter == NoteFilterType.all &&
                      _selectedProjectId == null &&
                      _selectedTag == null,
                  onClick: () => setState(() {
                    _filter = NoteFilterType.all;
                    _selectedProjectId = null;
                    _selectedTag = null;
                  }),
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Pinned',
                  icon: AppIcons.pin,
                  count: pinnedCount,
                  selected: _filter == NoteFilterType.pinned,
                  onClick: () => setState(() => _filter = NoteFilterType.pinned),
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Checklists',
                  icon: AppIcons.checklist,
                  count: checklistCount,
                  selected: _filter == NoteFilterType.checklist,
                  onClick: () =>
                      setState(() => _filter = NoteFilterType.checklist),
                ),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Project Tagged',
                  icon: AppIcons.project,
                  selected: _filter == NoteFilterType.tagged,
                  onClick: () => setState(() => _filter = NoteFilterType.tagged),
                ),
                if (_selectedProjectId != null) ...[
                  const SizedBox(width: 8),
                  _ActiveFilterBadge(
                    label: widget.state.projects
                        .cast<Project?>()
                        .firstWhere((p) => p?.id == _selectedProjectId,
                            orElse: () => null)
                        ?.name ??
                        'Project',
                    onClear: () => setState(() => _selectedProjectId = null),
                  ),
                ],
                if (_selectedTag != null) ...[
                  const SizedBox(width: 6),
                  _ActiveFilterBadge(
                    label: _selectedTag!,
                    onClear: () => setState(() => _selectedTag = null),
                  ),
                ],
              ],
            ),
          ),

          // Main Notes Area
          Expanded(
            child: allNotesCount == 0
                ? _buildEmptyState(context)
                : notes.isEmpty
                    ? _buildNoResultsState(context)
                    : _buildNotesGrid(context, notes),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(AppIcons.note, size: 26, color: p.accent),
              ),
            ),
            const SizedBox(height: 16),
            const T('No notes yet', size: 16, weight: FontWeight.w700),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: T(
                'Create developer scratchpads, interactive checklists, deployment steps, and URLs tagged directly to your local projects.',
                size: 13,
                color: p.muted,
                align: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Btn(
              label: 'Create First Note',
              icon: AppIcons.add,
              primary: true,
              height: 34,
              onClick: () => widget.state.openNewNoteInPane(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.search, size: 32, color: p.muted),
          const SizedBox(height: 12),
          const T('No matching notes found', size: 15, weight: FontWeight.w600),
          const SizedBox(height: 6),
          T(
            'Try adjusting your search terms or clearing active filters',
            size: 12.5,
            color: p.muted,
          ),
          const SizedBox(height: 16),
          Btn(
            label: 'Reset Filters',
            icon: AppIcons.refresh,
            outlined: true,
            height: 34,
            onClick: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _filter = NoteFilterType.all;
                _selectedProjectId = null;
                _selectedTag = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(BuildContext context, List<Note> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width > 1100 ? 3 : (width > 680 ? 2 : 1);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 260,
          ),
          itemCount: notes.length,
          itemBuilder: (context, i) {
            final note = notes[i];
            return _NoteCard(
              note: note,
              state: widget.state,
              formatTime: _formatTime,
              onCopy: () => _copyNoteAsMarkdown(note),
              onSelectProject: (pid) => setState(() => _selectedProjectId = pid),
              onSelectTag: (tag) => setState(() => _selectedTag = tag),
            );
          },
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    this.icon,
    this.count,
    required this.selected,
    required this.onClick,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClickableNoRipple(
      onClick: onClick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? p.accent.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? p.accent : p.border.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12.5, color: selected ? p.accent : p.muted),
              const SizedBox(width: 5),
            ],
            T(
              label,
              size: 11.5,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? p.accent : p.muted,
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 5),
              T(
                '$count',
                size: 10.5,
                weight: FontWeight.w600,
                color: selected ? p.accent : p.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterBadge extends StatelessWidget {
  const _ActiveFilterBadge({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          T(label, size: 11, weight: FontWeight.w600, color: p.accent),
          const SizedBox(width: 4),
          ClickableNoRipple(
            onClick: onClear,
            child: Icon(AppIcons.close, size: 11, color: p.accent),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.state,
    required this.formatTime,
    required this.onCopy,
    required this.onSelectProject,
    required this.onSelectTag,
  });

  final Note note;
  final AppState state;
  final String Function(DateTime) formatTime;
  final VoidCallback onCopy;
  final ValueChanged<String> onSelectProject;
  final ValueChanged<String> onSelectTag;

  void _showContextMenu(BuildContext context, Offset pos) {
    ContextMenu.show(context, pos, [
      ContextMenuItem(
        label: 'Edit Note…',
        icon: AppIcons.edit,
        action: () => state.openNoteInPane(note),
      ),
      ContextMenuItem(
        label: note.pinned ? 'Unpin Note' : 'Pin Note to Top',
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

  void _openLink(String rawLink) {
    final link = rawLink.trim();
    if (link.startsWith('http://') || link.startsWith('https://')) {
      Platform.openUrl(link);
    } else if (link.startsWith('/') || link.contains(':\\')) {
      Platform.reveal(link);
    } else {
      Platform.openUrl('https://$link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final totalChecklist = note.checklist.length;
    final checkedCount = note.checklist.where((c) => c.checked).length;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => state.openNoteInPane(note),
      builder: (context, hovered) {
        return GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: Container(
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovered ? p.accent.withOpacity(0.55) : p.border,
                width: 1,
              ),
              boxShadow: hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(p.dark ? 0.3 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Accent Strip
                  if (note.color != null)
                    Container(height: 3, color: note.color!),

                  // Card Header
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8, top: 10),
                    child: Row(
                      children: [
                        // Project Tag Badges
                        if (note.projectIds.isNotEmpty) ...[
                          for (final pid in note.projectIds.take(2)) ...[
                            Builder(
                              builder: (_) {
                                final project = state.projects
                                    .cast<Project?>()
                                    .firstWhere((pr) => pr?.id == pid,
                                        orElse: () => null);
                                if (project == null) return const SizedBox.shrink();

                                return ClickableNoRipple(
                                  onClick: () => onSelectProject(project.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: project.techStack.color.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: project.techStack.color.withOpacity(0.3),
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
                                            color: project.techStack.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        T(
                                          project.name,
                                          size: 10.5,
                                          weight: FontWeight.w600,
                                          color: project.techStack.color,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ] else ...[
                          Icon(AppIcons.note, size: 13, color: p.muted),
                        ],
                        const Spacer(),
                        // Pin Toggle Button
                        IconBtn(
                          icon: note.pinned ? AppIcons.pin : AppIcons.unpin,
                          size: 24,
                          iconSize: 13,
                          color: note.pinned ? p.accent : p.muted,
                          tooltip: note.pinned ? 'Unpin' : 'Pin to top',
                          onClick: () => state.togglePinNote(note.id),
                        ),
                        // Context Menu Trigger
                        IconBtn(
                          icon: AppIcons.dots,
                          size: 24,
                          iconSize: 13,
                          onClick: () => _showContextMenu(
                            context,
                            Offset(
                              MediaQuery.of(context).size.width - 200,
                              200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Title & Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T(
                          note.title.isNotEmpty ? note.title : 'Untitled Note',
                          size: 13.5,
                          weight: FontWeight.w700,
                          maxLines: 1,
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          T(
                            note.content,
                            size: 11.5,
                            color: p.muted,
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Checklist Snippet
                  if (totalChecklist > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              T(
                                'Checklist ($checkedCount/$totalChecklist)',
                                size: 10.5,
                                weight: FontWeight.w600,
                                color: p.muted,
                              ),
                              const Spacer(),
                              if (totalChecklist > 0)
                                SizedBox(
                                  width: 60,
                                  height: 4,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
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
                          const SizedBox(height: 4),
                          // Up to 3 checklist items with interactive toggle
                          for (final item in note.checklist.take(3)) ...[
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
                                      size: 14,
                                      color: item.checked ? p.accent : p.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: T(
                                      item.text,
                                      size: 11,
                                      color: item.checked ? p.muted : p.text,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (totalChecklist > 3)
                            T(
                              '+${totalChecklist - 3} more items…',
                              size: 10,
                              color: p.muted,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Detected / Attached Links
                  if (note.links.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 6),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final link in note.links.take(2))
                            ClickableNoRipple(
                              onClick: () => _openLink(link),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.field,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: p.border.withOpacity(0.7), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.link, size: 10, color: p.accent),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 120),
                                      child: T(
                                        link,
                                        size: 10,
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

                  const Spacer(),

                  // Card Footer
                  DrawTopBorder(
                    color: p.border.withOpacity(0.6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          // Tags
                          if (note.tags.isNotEmpty) ...[
                            for (final tag in note.tags.take(2)) ...[
                              ClickableNoRipple(
                                onClick: () => onSelectTag(tag),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: T(
                                    tag,
                                    size: 10.5,
                                    weight: FontWeight.w500,
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const Spacer(),
                          T(
                            formatTime(note.updatedAt),
                            size: 10.5,
                            color: p.muted,
                          ),
                          const SizedBox(width: 6),
                          IconBtn(
                            icon: AppIcons.copy,
                            tooltip: 'Copy as Markdown',
                            size: 20,
                            iconSize: 11,
                            onClick: onCopy,
                          ),
                        ],
                      ),
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
