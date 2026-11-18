import 'package:flutter/material.dart';
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

/// Note card shared by the notes page grid and the side pane list.
///
/// * Keep-style tinted surface with a soft accent edge
/// * Title, clean rich-text preview, inline interactive checkboxes
/// * Project and tag pills, link count, relative time
/// * Hover actions (pin / copy / more); pinned notes carry a badge
///
/// Set [fillHeight] when the parent gives a fixed height (grid); otherwise
/// the card sizes to its content (pane list).
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.state,
    required this.formatTime,
    required this.onCopy,
    this.onSelectProject,
    this.onSelectTag,
    this.fillHeight = false,
  });

  final Note note;
  final AppState state;
  final String Function(DateTime) formatTime;
  final VoidCallback onCopy;
  final ValueChanged<String>? onSelectProject;
  final ValueChanged<String>? onSelectTag;
  final bool fillHeight;

  void _menu(BuildContext context, Offset pos) {
    ContextMenu.show(context, pos, [
      ContextMenuItem(
        label: 'Edit note',
        icon: AppIcons.edit,
        action: () => state.openNoteInPane(note),
      ),
      ContextMenuItem(
        label: note.pinned ? 'Unpin' : 'Pin to top',
        icon: note.pinned ? AppIcons.unpin : AppIcons.pin,
        action: () => state.togglePinNote(note.id),
      ),
      ContextMenuItem(label: 'Copy as Markdown', icon: AppIcons.copy, action: onCopy),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Delete note',
        icon: AppIcons.delete,
        danger: true,
        action: () => state.deleteNote(note.id),
      ),
    ]);
  }

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

  Project? _project(String id) {
    for (final p in state.projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final theme = getThemeForColor(note.color);
    final accent = note.color ?? p.accent;
    final bg = theme != null ? theme.surface(p.dark) : p.panel;
    final edge = theme != null ? theme.accent.withOpacity(0.38) : p.border;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => state.openNoteInPane(note),
      builder: (context, hovered) {
        return GestureDetector(
          onSecondaryTapUp: (d) => _menu(context, d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovered ? p.accent.withOpacity(0.7) : edge,
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
              child: _content(context, p, accent),
            ),
          ),
        );
      },
    );
  }

  /// Header row: project badges on the left, pin + menu on the right.
  Widget _header(BuildContext context, Pal p, Color accent) {
    final projects =
        [for (final id in note.projectIds) _project(id)].whereType<Project>().toList();
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 8),
      child: Row(
        children: [
          if (projects.isEmpty)
            Icon(AppIcons.note, size: 13, color: p.muted)
          else
            for (final pr in projects.take(2))
              Flexible(
                child: _pill(p, pr.name, pr.techStack.color,
                    dot: true,
                    onTap: onSelectProject == null ? null : () => onSelectProject!(pr.id)),
              ),
          if (projects.length > 2)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: T('+${projects.length - 2}', size: 10.5, color: p.muted),
            ),
          const Spacer(),
          IconBtn(
            icon: note.pinned ? AppIcons.pin : AppIcons.unpin,
            size: 24,
            iconSize: 13,
            color: note.pinned ? accent : p.muted,
            tooltip: note.pinned ? 'Unpin' : 'Pin to top',
            onClick: () => state.togglePinNote(note.id),
          ),
          Builder(
            builder: (ctx) => IconBtn(
              icon: AppIcons.dots,
              size: 24,
              iconSize: 13,
              tooltip: 'More',
              onClick: () {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                _menu(ctx, box.localToGlobal(Offset(0, box.size.height + 4)));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Pal p, Color accent) {
    final preview = note.plainContent;
    final hasList = note.checklist.isNotEmpty;
    final done = note.checklist.where((c) => c.checked).length;
    final total = note.checklist.length;
    final title = note.title.trim();

    // Show unchecked first so the card surfaces what's left to do.
    final ordered = [
      ...note.checklist.where((c) => !c.checked),
      ...note.checklist.where((c) => c.checked),
    ];
    final shown = ordered.take(fillHeight ? 4 : 5).toList();

    final pills = <Widget>[
      for (final t in note.tags.take(3))
        _pill(p, t, accent, onTap: onSelectTag == null ? null : () => onSelectTag!(t)),
    ];
    final extra = (note.tags.length - 3).clamp(0, 99);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        // Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  title.isNotEmpty ? title : (preview.isEmpty && !hasList ? 'Empty note' : 'Untitled'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: title.isNotEmpty ? p.text : p.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            preview,
            maxLines: hasList ? 2 : (fillHeight ? 5 : 4),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
          ),
        ],
        if (hasList) ...[
          const SizedBox(height: 8),
          for (final item in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  ClickableNoRipple(
                    onClick: () => state.toggleChecklistItem(note.id, item.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: item.checked ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4.5),
                        border: Border.all(color: item.checked ? accent : p.muted, width: 1.4),
                      ),
                      child: item.checked
                          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.checked ? p.muted : p.text,
                        decoration: item.checked ? TextDecoration.lineThrough : null,
                        decorationColor: p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (total > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 23),
              child: T('+${total - shown.length} more', size: 10.5, color: p.muted),
            ),
        ],
        if (pills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              ...pills,
              if (extra > 0) _pill(p, '+$extra', p.muted),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ],
    );

    final footer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border.withOpacity(0.55)))),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: p.muted),
          const SizedBox(width: 4),
          T(formatTime(note.updatedAt), size: 10.5, color: p.muted),
          const Spacer(),
          if (note.links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: HoverBuilder(
                cursor: SystemMouseCursors.click,
                onTap: () => _openLink(note.links.first),
                builder: (_, h) => Row(
                  children: [
                    Icon(AppIcons.link, size: 11, color: h ? accent : p.muted),
                    const SizedBox(width: 3),
                    T('${note.links.length}', size: 10.5, color: h ? accent : p.muted),
                  ],
                ),
              ),
            ),
          if (hasList) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: done / total,
                  backgroundColor: p.border,
                  valueColor: AlwaysStoppedAnimation(done == total ? p.ok : accent),
                ),
              ),
            ),
            const SizedBox(width: 6),
            T('$done/$total', size: 10.5, weight: FontWeight.w600, color: done == total ? p.ok : p.muted),
          ],
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
    );

    final padded = Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: body);
    final head = _header(context, p, accent);

    if (!fillHeight) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [head, padded, footer],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: padded),
          ),
        ),
        footer,
      ],
    );
  }

  Widget _pill(Pal p, String label, Color color, {bool dot = false, VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: T(label, size: 10.5, weight: FontWeight.w600, color: color, maxLines: 1),
          ),
        ],
      ),
    );
    return onTap == null ? child : ClickableNoRipple(onClick: onTap, child: child);
  }
}
