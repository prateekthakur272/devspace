import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/ide/ide_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ui = state.uiState;

    final dirtyCount = state.projects.where((pr) {
      final s = state.gitStatuses[pr.id];
      return s != null && s.isDirty;
    }).length;

    return Container(
      color: p.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation tabs: Catalog vs Git Radar
          DrawBottomBorder(
            color: p.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _NavTabButton(
                      label: 'Projects',
                      icon: AppIcons.project,
                      active: ui.activeTab == 'projects',
                      onClick: () => state.updateUiState(
                        (s) => s.copyWith(activeTab: 'projects'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _NavTabButton(
                      label: 'Git Radar',
                      icon: AppIcons.radar,
                      active: ui.activeTab == 'git_radar',
                      badge: dirtyCount > 0 ? '$dirtyCount' : null,
                      badgeColor: p.warn,
                      onClick: () => state.updateUiState(
                        (s) => s.copyWith(activeTab: 'git_radar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sidebar Content: Switched dynamically based on active tab
          Expanded(
            child: ui.activeTab == 'git_radar'
                ? _buildGitRadarSidebar(context, p, ui)
                : _buildProjectsSidebar(context, p, ui),
          ),
          // Bottom Actions
          DrawTopBorder(
            color: p.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: ui.activeTab == 'git_radar'
                  ? _buildGitRadarFooter(context, p)
                  : Btn(
                      label: 'Add Project',
                      icon: AppIcons.add,
                      primary: true,
                      height: 34,
                      onClick: () => state.modal = const ModalAddProject(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsSidebar(BuildContext context, Pal p, SavedState ui) {
    final allCount = state.projects.length;
    final pinnedCount = state.projects.where((pr) => pr.pinned).length;
    final dirtyCount = state.projects.where((pr) {
      final s = state.gitStatuses[pr.id];
      return s != null && s.isDirty;
    }).length;

    // Collect all unique tags
    final allTags = <String>{};
    for (final pr in state.projects) {
      allTags.addAll(pr.tags);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: [
        // Workspace Section Header
        const _SectionTitle('WORKSPACES'),
        _SidebarItem(
          label: 'All Projects',
          icon: AppIcons.project,
          count: allCount,
          active: ui.selectedWorkspaceId == 'all',
          onClick: () => state.updateUiState(
            (s) => s.copyWith(selectedWorkspaceId: 'all', activeTagFilter: null),
          ),
        ),
        _SidebarItem(
          label: 'Favorites / Pinned',
          icon: AppIcons.pin,
          count: pinnedCount,
          active: ui.selectedWorkspaceId == 'pinned',
          onClick: () => state.updateUiState(
            (s) => s.copyWith(selectedWorkspaceId: 'pinned', activeTagFilter: null),
          ),
        ),
        _SidebarItem(
          label: 'Needs Attention',
          icon: AppIcons.alert,
          count: dirtyCount,
          countColor: p.warn,
          active: ui.selectedWorkspaceId == 'dirty',
          onClick: () => state.updateUiState(
            (s) => s.copyWith(selectedWorkspaceId: 'dirty', activeTagFilter: null),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          'GROUPS',
          action: IconBtn(
            icon: AppIcons.add,
            tooltip: 'Create New Group',
            size: 18,
            iconSize: 11,
            onClick: () => state.modal = const ModalCreateGroup(),
          ),
        ),
        for (final ws in state.workspaces)
          Builder(
            builder: (ctx) => _SidebarItem(
              label: ws.name,
              dotColor: ws.color,
              icon: ws.icon,
              count: state.projects.where((pr) => pr.workspaceId == ws.id).length,
              active: ui.selectedWorkspaceId == ws.id,
              onClick: () => state.updateUiState(
                (s) => s.copyWith(selectedWorkspaceId: ws.id, activeTagFilter: null),
              ),
              trailingActions: [
                IconBtn(
                  icon: AppIcons.add,
                  tooltip: 'Add project to ${ws.name}',
                  size: 24,
                  iconSize: 13,
                  onClick: () => state.modal = ModalAddProject(initialWorkspaceId: ws.id),
                ),
                const SizedBox(width: 2),
                IconBtn(
                  icon: AppIcons.moreVert,
                  tooltip: 'More options',
                  size: 24,
                  iconSize: 15,
                  onClick: () {
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final pos = box.localToGlobal(Offset.zero) + const Offset(120, 20);
                      ContextMenu.show(context, pos, [
                        ContextMenuItem(
                          label: 'Edit Group…',
                          icon: AppIcons.edit,
                          action: () => state.modal = ModalEditGroup(ws),
                        ),
                        if (ws.id != 'default') ...[
                          const ContextMenuItem(label: ''),
                          ContextMenuItem(
                            label: 'Delete Group',
                            icon: AppIcons.delete,
                            danger: true,
                            action: () => state.removeWorkspaceGroup(ws.id),
                          ),
                        ],
                      ]);
                    }
                  },
                ),
              ],
              onSecondaryTap: () {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box != null) {
                  final pos = box.localToGlobal(Offset.zero) + const Offset(120, 20);
                  ContextMenu.show(context, pos, [
                    ContextMenuItem(
                      label: 'Edit Group…',
                      icon: AppIcons.edit,
                      action: () => state.modal = ModalEditGroup(ws),
                    ),
                    if (ws.id != 'default') ...[
                      const ContextMenuItem(label: ''),
                      ContextMenuItem(
                        label: 'Delete Group',
                        icon: AppIcons.delete,
                        danger: true,
                        action: () => state.removeWorkspaceGroup(ws.id),
                      ),
                    ],
                  ]);
                }
              },
            ),
          ),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('TAGS'),
          for (final tag in allTags)
            _SidebarItem(
              label: '#$tag',
              icon: AppIcons.filter,
              count: state.projects.where((pr) => pr.tags.contains(tag)).length,
              active: ui.activeTagFilter == tag,
              onClick: () => state.updateUiState(
                (s) => s.copyWith(
                  activeTagFilter: ui.activeTagFilter == tag ? null : tag,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildGitRadarSidebar(BuildContext context, Pal p, SavedState ui) {
    final repos = state.radarRepositories;
    final totalRepos = repos.length;
    final dirtyRepos = repos.where((r) => r.status.isDirty).length;
    final aheadRepos = repos.where((r) => r.status.aheadCount > 0).length;
    final behindRepos = repos.where((r) => r.status.behindCount > 0).length;
    final cleanRepos = repos.where((r) => r.status.isClean).length;
    final stashRepos = repos.where((r) => r.status.hasStash).length;

    // Remotes count
    final githubCount = repos.where((r) => r.status.remoteUrl?.toLowerCase().contains('github') == true).length;
    final gitlabCount = repos.where((r) => r.status.remoteUrl?.toLowerCase().contains('gitlab') == true).length;
    final bitbucketCount = repos.where((r) => r.status.remoteUrl?.toLowerCase().contains('bitbucket') == true).length;
    final localCount = repos.where((r) => r.status.remoteUrl == null || (!r.status.remoteUrl!.toLowerCase().contains('github') && !r.status.remoteUrl!.toLowerCase().contains('gitlab') && !r.status.remoteUrl!.toLowerCase().contains('bitbucket'))).length;

    // Branches breakdown
    final Map<String, int> branchCounts = {};
    for (final r in repos) {
      if (r.status.branch.isNotEmpty) {
        branchCounts[r.status.branch] = (branchCounts[r.status.branch] ?? 0) + 1;
      }
    }
    final topBranches = branchCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final activeFilter = state.gitRadarFilter;
    final activeRemote = state.gitRadarRemoteFilter;
    final activeBranch = state.gitRadarBranchFilter;
    final selectedRepo = state.selectedGitRepoPath;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: [
        const _SectionTitle('REPOSITORIES'),
        _SidebarItem(
          label: 'All Repositories',
          icon: AppIcons.radar,
          count: totalRepos,
          active: activeFilter == 'all' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('all'),
        ),
        _SidebarItem(
          label: 'Uncommitted',
          icon: AppIcons.alert,
          count: dirtyRepos,
          countColor: p.warn,
          active: activeFilter == 'dirty' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('dirty'),
        ),
        _SidebarItem(
          label: 'Needs Push',
          icon: AppIcons.push,
          count: aheadRepos,
          countColor: p.accent,
          active: activeFilter == 'ahead' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('ahead'),
        ),
        _SidebarItem(
          label: 'Needs Pull',
          icon: AppIcons.pull,
          count: behindRepos,
          countColor: p.err,
          active: activeFilter == 'behind' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('behind'),
        ),
        _SidebarItem(
          label: 'Stashes',
          icon: Icons.archive_rounded,
          count: stashRepos,
          countColor: const Color(0xFFC084FC),
          active: activeFilter == 'stash' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('stash'),
        ),
        _SidebarItem(
          label: 'Clean Repos',
          icon: Icons.check_circle_outline_rounded,
          count: cleanRepos,
          countColor: p.ok,
          active: activeFilter == 'clean' && activeRemote == null && activeBranch == null,
          onClick: () => state.setGitRadarFilter('clean'),
        ),

        if (totalRepos > 0) ...[
          const SizedBox(height: 16),
          const _SectionTitle('REMOTES'),
          if (githubCount > 0)
            _SidebarItem(
              label: 'GitHub',
              icon: AppIcons.github,
              count: githubCount,
              active: activeRemote == 'github',
              onClick: () => state.setGitRadarRemoteFilter(activeRemote == 'github' ? null : 'github'),
            ),
          if (gitlabCount > 0)
            _SidebarItem(
              label: 'GitLab',
              icon: AppIcons.link,
              count: gitlabCount,
              active: activeRemote == 'gitlab',
              onClick: () => state.setGitRadarRemoteFilter(activeRemote == 'gitlab' ? null : 'gitlab'),
            ),
          if (bitbucketCount > 0)
            _SidebarItem(
              label: 'Bitbucket',
              icon: AppIcons.link,
              count: bitbucketCount,
              active: activeRemote == 'bitbucket',
              onClick: () => state.setGitRadarRemoteFilter(activeRemote == 'bitbucket' ? null : 'bitbucket'),
            ),
          if (localCount > 0)
            _SidebarItem(
              label: 'Local / Other',
              icon: AppIcons.folder,
              count: localCount,
              active: activeRemote == 'local',
              onClick: () => state.setGitRadarRemoteFilter(activeRemote == 'local' ? null : 'local'),
            ),
        ],

        if (topBranches.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('BRANCHES'),
          for (final b in topBranches.take(5))
            _SidebarItem(
              label: b.key,
              icon: AppIcons.branch,
              count: b.value,
              active: activeBranch == b.key,
              onClick: () => state.setGitRadarBranchFilter(activeBranch == b.key ? null : b.key),
            ),
        ],

        if (repos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('TRACKED REPOSITORIES (${repos.length})'),
          for (final r in repos)
            Builder(
              builder: (ctx) => _GitRepoSidebarItem(
                repo: r,
                isSelected: selectedRepo == r.path,
                p: p,
                onClick: () => state.setSelectedGitRepoPath(r.path),
                onSecondaryTap: () {
                  final box = ctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final pos = box.localToGlobal(Offset.zero) + const Offset(120, 20);
                    ContextMenu.show(context, pos, [
                      _buildRepoOpenMenuItem(r, state),
                      ContextMenuItem(
                        label: 'Open Terminal',
                        icon: AppIcons.terminal,
                        action: () => state.openTerminal(r.path, title: r.name),
                      ),
                      ContextMenuItem(
                        label: 'Copy Repo Path',
                        icon: AppIcons.copy,
                        action: () {
                          Platform.copy(r.path);
                          state.showToast('Copied path: ${r.path}');
                        },
                      ),
                      ContextMenuItem(
                        label: 'Fetch Remote',
                        icon: AppIcons.refresh,
                        action: () async {
                          final ok = await GitService.fetch(r.path);
                          for (final pr in r.linkedProjects) {
                            await state.refreshProjectGit(pr);
                          }
                          state.showToast(ok ? 'Fetched ${r.name}' : 'Fetch failed');
                        },
                      ),
                    ]);
                  }
                },
              ),
            ),
        ],
      ],
    );
  }

  ContextMenuItem _buildRepoOpenMenuItem(RadarRepository repo, AppState state) {
    if (repo.linkedProjects.length > 1) {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        submenu: [
          for (final proj in repo.linkedProjects)
            ContextMenuItem(
              label: '${proj.name} (${proj.techStack.label})',
              icon: AppIcons.project,
              action: () => state.launchProject(proj),
            ),
          const ContextMenuItem(label: ''),
          ContextMenuItem(
            label: 'Repo Root (${repo.name})',
            icon: AppIcons.folder,
            action: () {
              final editor = state.settings.defaultEditor;
              IdeService.launchEditor(editor, path: repo.path);
            },
          ),
        ],
      );
    } else if (repo.linkedProjects.length == 1) {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        action: () => state.launchProject(repo.linkedProjects.first),
      );
    } else {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        action: () => IdeService.launchEditor(
          state.settings.defaultEditor,
          path: repo.path,
        ),
      );
    }
  }

  Widget _buildGitRadarFooter(BuildContext context, Pal p) {
    return Btn(
      label: 'Fetch All',
      icon: AppIcons.pull,
      primary: true,
      height: 34,
      onClick: () async {
        state.showToast('Fetching all Git remotes…');
        int okCount = 0;
        for (final r in state.radarRepositories) {
          final ok = await GitService.fetch(r.path);
          if (ok) okCount++;
          for (final pr in r.linkedProjects) {
            await state.refreshProjectGit(pr);
          }
        }
        state.showToast('Fetched $okCount repositories');
      },
    );
  }
}

class _GitRepoSidebarItem extends StatelessWidget {
  const _GitRepoSidebarItem({
    required this.repo,
    required this.isSelected,
    required this.p,
    required this.onClick,
    this.onSecondaryTap,
  });

  final RadarRepository repo;
  final bool isSelected;
  final Pal p;
  final VoidCallback onClick;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final status = repo.status;
    final statusColor = status.isDirty
        ? p.warn
        : (status.aheadCount > 0
            ? p.accent
            : (status.behindCount > 0 ? p.err : p.ok));

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: onClick,
      onSecondaryTap: onSecondaryTap,
      builder: (context, hovered) {
        final bg = isSelected
            ? p.accent.withOpacity(0.14)
            : (hovered ? p.hover : Colors.transparent);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? p.accent.withOpacity(0.4) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: status.isDirty || status.aheadCount > 0
                      ? [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    T(
                      repo.name,
                      size: 12.5,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? p.accent : p.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status.branch.isNotEmpty)
                      MonoText(
                        status.branch,
                        size: 9.5,
                        color: p.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (status.isDirty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.warn.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: T('~${status.totalChanges}', size: 9.5, weight: FontWeight.w600, color: p.warn),
                )
              else if (status.aheadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: T('↑${status.aheadCount}', size: 9.5, weight: FontWeight.w600, color: p.accent),
                )
              else if (status.behindCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.err.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: T('↓${status.behindCount}', size: 9.5, weight: FontWeight.w600, color: p.err),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onClick,
    this.badge,
    this.badgeColor,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onClick;
  final String? badge;
  final Color? badgeColor;

  static const double tabHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: onClick,
      builder: (context, hovered) {
        final bg = active
            ? p.accent.withOpacity(0.14)
            : (hovered ? p.hover : Colors.transparent);
        final fg = active ? p.accent : (hovered ? p.text : p.muted);

        return Container(
          height: tabHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.5, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: T(
                  label,
                  size: 12,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? p.accent).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: T(badge!, size: 10, weight: FontWeight.w600, color: badgeColor ?? p.accent),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4, top: 4),
      child: Row(
        children: [
          Expanded(
            child: T(
              title,
              size: 10.5,
              weight: FontWeight.w700,
              color: context.pal.muted.withOpacity(0.7),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    this.icon,
    required this.count,
    required this.active,
    required this.onClick,
    this.countColor,
    this.dotColor,
    this.trailingActions,
    this.onSecondaryTap,
  });

  final String label;
  final IconData? icon;
  final int count;
  final bool active;
  final VoidCallback onClick;
  final Color? countColor;
  final Color? dotColor;
  final List<Widget>? trailingActions;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: onClick,
      onSecondaryTap: onSecondaryTap,
      builder: (context, hovered) {
        final bg = active
            ? p.accent.withOpacity(0.12)
            : (hovered ? p.hover : Colors.transparent);
        final fg = active ? p.accent : p.text;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: dotColor!.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: 13.5, color: dotColor!)
                        : T(
                            label.isNotEmpty ? label[0].toUpperCase() : 'G',
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: dotColor!,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: active ? p.accent.withOpacity(0.14) : p.hover.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(icon, size: 13, color: active ? p.accent : p.muted),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: T(
                  label,
                  size: 13,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hovered && trailingActions != null && trailingActions!.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: trailingActions!,
                ),
              ] else if (count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (countColor ?? p.muted).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: T(
                    '$count',
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: countColor ?? (active ? p.accent : p.muted),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
