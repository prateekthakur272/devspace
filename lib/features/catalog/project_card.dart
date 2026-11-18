import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/tech_icon.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.state,
  });

  final Project project;
  final AppState state;

  String _formatTime(DateTime? time) {
    if (time == null) return 'Never opened';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _showContextMenu(BuildContext context, Offset pos) {
    ContextMenu.show(
      context,
      pos,
      [
        ContextMenuItem(
          label: 'Open in ${project.defaultEditor.label}',
          leading: IdeIcon(editor: project.defaultEditor, size: 14),
          action: () => state.launchProject(project),
        ),
        for (final editor in state.availableEditors)
          if (editor != project.defaultEditor && editor != EditorType.custom)
            ContextMenuItem(
              label: 'Open in ${editor.label}',
              leading: IdeIcon(editor: editor, size: 14),
              action: () => state.launchProject(project, overrideEditor: editor),
            ),
        const ContextMenuItem(label: ''), // Divider
        ContextMenuItem(
          label: Platform.revealLabel,
          icon: AppIcons.folder,
          action: () => Platform.reveal(project.path),
        ),
        ContextMenuItem(
          label: 'Open in ${state.settings.defaultTerminal.label}',
          icon: AppIcons.terminal,
          action: () => state.openTerminal(project.path, title: project.name),
        ),
        ContextMenuItem(
          label: state.settings.defaultTerminal == DefaultTerminalType.integrated
              ? 'Open in System Terminal'
              : 'Open in Integrated Terminal',
          icon: state.settings.defaultTerminal == DefaultTerminalType.integrated
              ? AppIcons.external
              : AppIcons.terminal,
          action: () {
            if (state.settings.defaultTerminal == DefaultTerminalType.integrated) {
              state.openSystemTerminal(project.path);
            } else {
              state.openIntegratedTerminal(project.path, title: project.name);
            }
          },
        ),
        ContextMenuItem(
          label: 'Copy Path',
          icon: AppIcons.copy,
          action: () => Platform.copy(project.path),
        ),
        ContextMenuItem(
          label: 'Refresh Git Status',
          icon: AppIcons.refresh,
          action: () => state.refreshProjectGit(project),
        ),
        const ContextMenuItem(label: ''), // Divider
        ContextMenuItem(
          label: 'Add Note for this Project…',
          icon: AppIcons.note,
          action: () => state.openNewNoteInPane(initialProjectId: project.id),
        ),
        const ContextMenuItem(label: ''), // Divider
        ContextMenuItem(
          label: project.pinned ? 'Unpin Project' : 'Pin Project',
          icon: project.pinned ? AppIcons.unpin : AppIcons.pin,
          action: () => state.togglePin(project.id),
        ),
        ContextMenuItem(
          label: 'Edit Settings…',
          icon: AppIcons.edit,
          action: () => state.modal = ModalEditProject(project),
        ),
        const ContextMenuItem(label: ''), // Divider
        ContextMenuItem(
          label: 'Move to',
          icon: AppIcons.folder,
          submenu: [
            for (final ws in state.workspaces)
              if (ws.id != project.workspaceId)
                ContextMenuItem(
                  label: ws.name,
                  leading: Center(
                    child: ws.icon != null
                        ? Icon(ws.icon, size: 13, color: ws.color)
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ws.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                  action: () => state.moveProjectToWorkspace(project.id, ws.id),
                ),
            if (state.workspaces.where((w) => w.id != project.workspaceId).isNotEmpty)
              const ContextMenuItem(label: ''), // Divider
            ContextMenuItem(
              label: 'New Workspace Group…',
              icon: AppIcons.add,
              action: () => state.modal = const ModalCreateGroup(),
            ),
          ],
        ),
        const ContextMenuItem(label: ''), // Divider
        ContextMenuItem(
          label: 'Remove from DevSpace',
          icon: AppIcons.delete,
          danger: true,
          action: () => state.modal = ModalConfirmDelete(project: project),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final gitStatus = state.gitStatuses[project.id];
    final isLoadingGit = state.gitLoading[project.id] == true;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      opaque: false,
      onDoubleTap: () => state.launchProject(project),
      onSecondaryTap: () {
        // Find position for context menu
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero) + const Offset(40, 20);
          _showContextMenu(context, pos);
        }
      },
      builder: (context, hovered) {
        final fillColor = p.panel;
        final borderColor = project.pinned
            ? p.accent
            : (hovered
                ? (p.dark ? p.text.withOpacity(0.35) : p.text.withOpacity(0.25))
                : p.border);
        final borderWidth = project.pinned ? 1.5 : (hovered ? 1.2 : 1.0);

        return CustomPaint(
          painter: _FolderCardPainter(
            fillColor: fillColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
            hasShadow: hovered,
            pinned: project.pinned,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Folder Tab Row
              SizedBox(
                height: FolderPathHelper.tabHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TechIcon(
                        stack: project.techStack,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      T(
                        project.techStack.label,
                        size: 11,
                        weight: FontWeight.w600,
                        color: project.techStack.color,
                      ),
                    ],
                  ),
                ),
              ),
              // Main Folder Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with Pin + Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: T(
                                    project.name,
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: p.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (project.pinned) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: p.accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: T('PINNED', size: 9, weight: FontWeight.w700, color: p.accent),
                                  ),
                                ],
                                Builder(
                                  builder: (_) {
                                    final pNotes = state.getNotesForProject(project.id);
                                    if (pNotes.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: ClickableNoRipple(
                                        onClick: () => state.updateUiState(
                                          (s) => s.copyWith(activeTab: 'notes'),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: p.field,
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: p.border, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(AppIcons.note, size: 9.5, color: p.muted),
                                              const SizedBox(width: 3),
                                              T('${pNotes.length}', size: 9, weight: FontWeight.w700, color: p.muted),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconBtn(
                            icon: project.pinned ? AppIcons.pin : AppIcons.unpin,
                            tooltip: project.pinned ? 'Unpin' : 'Pin to top',
                            active: project.pinned,
                            color: project.pinned ? p.accent : p.muted,
                            size: 26,
                            iconSize: 14,
                            onClick: () => state.togglePin(project.id),
                          ),
                          const SizedBox(width: 2),
                          IconBtn(
                            icon: AppIcons.dots,
                            tooltip: 'More actions',
                            size: 26,
                            iconSize: 14,
                            onClick: () {
                              final box = context.findRenderObject() as RenderBox?;
                              if (box != null) {
                                final pos = box.localToGlobal(Offset.zero) +
                                    Offset(box.size.width - 120, 30);
                                _showContextMenu(context, pos);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Path
                      MonoText(
                        project.path,
                        size: 11,
                        color: p.muted,
                      ),
                      const SizedBox(height: 6),
                      // Git Status Banner
                      _buildGitSection(context, p, gitStatus, isLoadingGit),
                      const Spacer(),
                      // Footer: Recency + Quick Actions
                      DrawTopBorder(
                        color: p.border,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: T(
                                  _formatTime(project.lastOpenedAt),
                                  size: 11,
                                  color: p.muted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconBtn(
                                icon: AppIcons.folder,
                                tooltip: Platform.revealLabel,
                                size: 28,
                                iconSize: 15,
                                onClick: () => Platform.reveal(project.path),
                              ),
                              const SizedBox(width: 4),
                              IconBtn(
                                icon: AppIcons.terminal,
                                tooltip: state.settings.defaultTerminal == DefaultTerminalType.integrated
                                    ? 'Open in Integrated Terminal'
                                    : 'Open in System Terminal',
                                size: 28,
                                iconSize: 15,
                                onClick: () => state.openTerminal(project.path, title: project.name),
                              ),
                              const SizedBox(width: 4),
                              IconBtn(
                                icon: AppIcons.note,
                                tooltip: 'Add note for this project',
                                size: 28,
                                iconSize: 15,
                                onClick: () => state.openNewNoteInPane(initialProjectId: project.id),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: HoverBuilder(
                                  cursor: SystemMouseCursors.click,
                                  onTap: () => state.launchProject(project),
                                  builder: (context, editorHovered) {
                                    return Tooltip(
                                      message: 'Default editor: ${project.defaultEditor.label}\nDouble-click card to open',
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: editorHovered ? p.hover : p.field,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: editorHovered ? p.accent.withOpacity(0.5) : p.border,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IdeIcon(editor: project.defaultEditor, size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: T(
                                                project.defaultEditor.label,
                                                size: 11.5,
                                                weight: FontWeight.w500,
                                                color: editorHovered ? p.text : p.muted,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGitSection(BuildContext context, Pal p, GitRepoStatus? gitStatus, bool isLoadingGit) {
    if (gitStatus == null || !gitStatus.isGitRepo) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: p.field.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: p.border.withOpacity(0.6), width: 1),
        ),
        child: Row(
          children: [
            Icon(AppIcons.branch, size: 12, color: p.muted.withOpacity(0.5)),
            const SizedBox(width: 6),
            T('No Git repository', size: 11, color: p.muted.withOpacity(0.65)),
          ],
        ),
      );
    }

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => state.modal = ModalGitDetails(project, gitStatus),
      builder: (context, hovered) {
        final hasCommitInfo = gitStatus.lastCommitMessage != null || gitStatus.lastTag != null;

        final buffer = StringBuffer('Branch: ${gitStatus.branch}');
        if (gitStatus.upstream != null) {
          buffer.write(' -> ${gitStatus.upstream}');
        }
        buffer.writeln();
        if (gitStatus.isClean) {
          buffer.write('Status: Clean');
        } else {
          buffer.write(
            'Status: ${gitStatus.totalChanges} uncommitted changes (${gitStatus.stagedCount} staged, ${gitStatus.modifiedCount} modified, ${gitStatus.untrackedCount} untracked)',
          );
        }
        if (gitStatus.aheadCount > 0 || gitStatus.behindCount > 0) {
          buffer.write('\nSync: ${gitStatus.aheadCount} ahead, ${gitStatus.behindCount} behind');
        }
        if (gitStatus.hasStash) {
          buffer.write('\nStash: Saved changes present');
        }
        if (gitStatus.lastCommitMessage != null) {
          buffer.write('\nLast commit: ${gitStatus.lastCommitHash ?? ""} ${gitStatus.lastCommitMessage!}');
          if (gitStatus.lastCommitAuthor != null) {
            buffer.write(' (${gitStatus.lastCommitAuthor})');
          }
        }
        buffer.write('\nClick for full Git health & details');

        return Tooltip(
          message: buffer.toString(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: hovered
                  ? (p.dark ? const Color(0xFF1E2128) : const Color(0xFFE9EDF5))
                  : (p.dark ? const Color(0xFF16181D) : p.field),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hovered ? p.accent.withOpacity(0.55) : p.border,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Branch, Sync Badges, Dirty/Clean Badges
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Branch chip
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: p.accent.withOpacity(0.25), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.branch, size: 12, color: p.accent),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 110),
                                      child: T(
                                        gitStatus.branch,
                                        size: 11.5,
                                        weight: FontWeight.w600,
                                        color: p.accent,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Stash Badge
                          if (gitStatus.hasStash)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.warn.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 9.5, color: p.warn),
                                  const SizedBox(width: 2),
                                  T('stash', size: 9.5, weight: FontWeight.w600, color: p.warn),
                                ],
                              ),
                            ),

                          // Synced indicator
                          if (gitStatus.isSynced)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.ok.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync_rounded, size: 9.5, color: p.ok),
                                  const SizedBox(width: 2),
                                  T('synced', size: 9.5, weight: FontWeight.w600, color: p.ok),
                                ],
                              ),
                            ),

                          // Ahead / Behind Commits
                          if (gitStatus.aheadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 10, color: p.accent),
                                  const SizedBox(width: 1),
                                  T('${gitStatus.aheadCount}', size: 10, weight: FontWeight.w700, color: p.accent),
                                ],
                              ),
                            ),
                          if (gitStatus.behindCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.err.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 10, color: p.err),
                                  const SizedBox(width: 1),
                                  T('${gitStatus.behindCount}', size: 10, weight: FontWeight.w700, color: p.err),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Status Indicator
                    if (isLoadingGit)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: p.accent),
                      )
                    else if (gitStatus.isDirty) ...[
                      // Granular breakdown: staged (+), modified (~), untracked (?)
                      if (gitStatus.stagedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.ok.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: T('+${gitStatus.stagedCount}', size: 9.5, weight: FontWeight.w700, color: p.ok),
                        ),
                      if (gitStatus.modifiedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.warn.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: T('~${gitStatus.modifiedCount}', size: 9.5, weight: FontWeight.w700, color: p.warn),
                        ),
                      if (gitStatus.untrackedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.muted.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: T('?${gitStatus.untrackedCount}', size: 9.5, weight: FontWeight.w700, color: p.muted),
                        ),
                      // Total changes badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.warn.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: p.warn.withOpacity(0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: p.warn,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            T(
                              '${gitStatus.totalChanges} dirty',
                              size: 10.5,
                              weight: FontWeight.w600,
                              color: p.warn,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.ok.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: p.ok.withOpacity(0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 11, color: p.ok),
                            const SizedBox(width: 3),
                            T('clean', size: 10.5, weight: FontWeight.w600, color: p.ok),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Bottom Row: Last Commit Message, Hash, Tag, Relative Time, Chevron
                if (hasCommitInfo) ...[
                  const SizedBox(height: 4),
                  DrawTopBorder(
                    color: p.border.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(AppIcons.commit, size: 11, color: p.muted),
                          const SizedBox(width: 4),
                          // Commit short hash
                          if (gitStatus.lastCommitHash != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: p.field.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: p.border.withOpacity(0.6), width: 0.5),
                              ),
                              child: MonoText(
                                gitStatus.lastCommitHash!.length > 7
                                    ? gitStatus.lastCommitHash!.substring(0, 7)
                                    : gitStatus.lastCommitHash!,
                                size: 9.5,
                                color: p.muted,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          // Flexible middle section: tag, commit message, author
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tag badge (if available)
                                if (gitStatus.lastTag != null) ...[
                                  Flexible(
                                    flex: gitStatus.lastCommitMessage != null ? 1 : 2,
                                    child: Tooltip(
                                      message: 'Tag: ${gitStatus.lastTag!}',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: p.accent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.sell_outlined, size: 9, color: p.accent),
                                            const SizedBox(width: 2.5),
                                            Flexible(
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 85),
                                                child: T(
                                                  gitStatus.lastTag!,
                                                  size: 9.5,
                                                  weight: FontWeight.w600,
                                                  color: p.accent,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (gitStatus.lastCommitMessage != null) const SizedBox(width: 5),
                                ],
                                // Commit message & author
                                if (gitStatus.lastCommitMessage != null)
                                  Flexible(
                                    flex: 2,
                                    child: T(
                                      gitStatus.lastCommitMessage!,
                                      size: 11,
                                      color: p.text.withOpacity(0.85),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (gitStatus.lastCommitAuthor != null) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 75),
                                      child: T(
                                        '• ${gitStatus.lastCommitAuthor}',
                                        size: 9.5,
                                        color: p.muted.withOpacity(0.75),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Relative time
                          if (gitStatus.lastCommitDate != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: T(
                                _formatTime(gitStatus.lastCommitDate!),
                                size: 9.5,
                                color: p.muted,
                              ),
                            ),
                          if (hovered)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 13,
                                color: p.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class FolderPathHelper {
  const FolderPathHelper._();

  static const double tabHeight = 28.0;
  static const double tabWidth = 145.0;
  static const double slant = 18.0;
  static const double radius = 8.0;

  static Path buildPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at top-left below the corner curve
    path.moveTo(0, radius);
    // Top-left corner of the tab
    path.quadraticBezierTo(0, 0, radius, 0);
    // Top edge of tab
    path.lineTo(tabWidth - 6, 0);
    // Smooth S-curve from tab top down to shoulder
    path.cubicTo(
      tabWidth + 4,
      0,
      tabWidth + slant - 8,
      tabHeight,
      tabWidth + slant + 6,
      tabHeight,
    );
    // Horizontal shoulder to top-right
    path.lineTo(w - radius, tabHeight);
    // Top-right corner of shoulder
    path.quadraticBezierTo(w, tabHeight, w, tabHeight + radius);
    // Right vertical edge
    path.lineTo(w, h - radius);
    // Bottom-right corner
    path.quadraticBezierTo(w, h, w - radius, h);
    // Bottom horizontal edge
    path.lineTo(radius, h);
    // Bottom-left corner
    path.quadraticBezierTo(0, h, 0, h - radius);
    // Left vertical edge back to start
    path.lineTo(0, radius);
    path.close();

    return path;
  }
}

class _FolderCardPainter extends CustomPainter {
  const _FolderCardPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.hasShadow,
    required this.pinned,
  });

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hasShadow;
  final bool pinned;

  @override
  void paint(Canvas canvas, Size size) {
    final path = FolderPathHelper.buildPath(size);

    if (hasShadow) {
      canvas.drawShadow(
        path,
        Colors.black.withOpacity(0.12),
        4.0,
        false,
      );
    }

    // Fill the folder shape
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_FolderCardPainter old) =>
      fillColor != old.fillColor ||
      borderColor != old.borderColor ||
      borderWidth != old.borderWidth ||
      hasShadow != old.hasShadow ||
      pinned != old.pinned;
}
