import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class GitRadarView extends StatelessWidget {
  const GitRadarView({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final projects = state.projects;

    int totalRepos = 0;
    int cleanCount = 0;
    int dirtyCount = 0;
    int aheadCount = 0;
    int behindCount = 0;

    for (final pr in projects) {
      final s = state.gitStatuses[pr.id];
      if (s != null && s.isGitRepo) {
        totalRepos++;
        if (s.isClean) cleanCount++;
        if (s.isDirty) dirtyCount++;
        if (s.aheadCount > 0) aheadCount++;
        if (s.behindCount > 0) behindCount++;
      }
    }

    return Container(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Metrics Bar
          DrawBottomBorder(
            color: p.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.radar, size: 18, color: p.accent),
                      const SizedBox(width: 8),
                      T('Combined Git Radar', size: 16, weight: FontWeight.w700),
                      const Spacer(),
                      Btn(
                        label: 'Refresh All',
                        icon: AppIcons.refresh,
                        primary: true,
                        height: 34,
                        onClick: () => state.refreshAllGit(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MetricCard(label: 'Tracked Repos', value: '$totalRepos', color: p.text),
                        const SizedBox(width: 10),
                        _MetricCard(label: 'Clean', value: '$cleanCount', color: p.ok),
                        const SizedBox(width: 10),
                        _MetricCard(label: 'Uncommitted', value: '$dirtyCount', color: p.warn),
                        const SizedBox(width: 10),
                        _MetricCard(label: 'Needs Push', value: '$aheadCount', color: p.accent),
                        const SizedBox(width: 10),
                        _MetricCard(label: 'Needs Pull', value: '$behindCount', color: p.err),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Repository List Table
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: T('No projects in workspace', color: p.muted),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: projects.length,
                    itemBuilder: (context, idx) {
                      final pr = projects[idx];
                      final status = state.gitStatuses[pr.id];
                      final isLoading = state.gitLoading[pr.id] == true;

                      return _RepoRow(
                        project: pr,
                        status: status,
                        isLoading: isLoading,
                        state: state,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        children: [
          T(value, size: 15, weight: FontWeight.w700, color: color),
          T(label, size: 10.5, color: p.muted),
        ],
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow({
    required this.project,
    required this.status,
    required this.isLoading,
    required this.state,
  });

  final Project project;
  final GitRepoStatus? status;
  final bool isLoading;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isRepo = status != null && status!.isGitRepo;

    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hovered) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hovered ? p.hover.withOpacity(0.5) : p.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isRepo && status!.isDirty
                  ? p.warn.withOpacity(0.5)
                  : p.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              TechBadge(
                label: project.techStack.label,
                color: project.techStack.color,
                stack: project.techStack,
              ),
              const SizedBox(width: 12),
              // Project info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(project.name, size: 13.5, weight: FontWeight.w600),
                    MonoText(project.path, size: 11, color: p.muted),
                  ],
                ),
              ),
              // Branch & Git Status
              Expanded(
                flex: 4,
                child: isRepo
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Icon(AppIcons.branch, size: 14, color: p.muted),
                            const SizedBox(width: 6),
                            T(
                              status!.branch,
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: p.text,
                            ),
                            const SizedBox(width: 12),
                            if (status!.isClean)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.ok.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: T('Clean', size: 11, color: p.ok, weight: FontWeight.w600),
                              )
                            else ...[
                              if (status!.modifiedCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: T('~${status!.modifiedCount}', size: 11.5, color: p.warn, weight: FontWeight.w600),
                                ),
                              if (status!.stagedCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: T('+${status!.stagedCount}', size: 11.5, color: p.ok, weight: FontWeight.w600),
                                ),
                              if (status!.untrackedCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: T('?${status!.untrackedCount}', size: 11.5, color: p.muted, weight: FontWeight.w600),
                                ),
                            ],
                            if (status!.aheadCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: T('↑${status!.aheadCount} ahead', size: 11.5, color: p.accent, weight: FontWeight.w600),
                              ),
                            if (status!.behindCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: T('↓${status!.behindCount} behind', size: 11.5, color: p.err, weight: FontWeight.w600),
                              ),
                            if (status!.hasStash)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: T('[stash]', size: 11, color: p.muted),
                              ),
                          ],
                        ),
                      )
                    : T('Not a Git repository', size: 12, color: p.muted, italic: true),
              ),
              // Actions
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isRepo) ...[
                IconBtn(
                  icon: AppIcons.refresh,
                  tooltip: 'Fetch Git',
                  size: 26,
                  iconSize: 13,
                  onClick: () async {
                    await GitService.fetch(project.path);
                    state.refreshProjectGit(project);
                  },
                ),
                const SizedBox(width: 4),
                if (status!.behindCount > 0)
                  IconBtn(
                    icon: AppIcons.pull,
                    tooltip: 'Pull commits',
                    size: 26,
                    iconSize: 13,
                    onClick: () async {
                      await GitService.pull(project.path);
                      state.refreshProjectGit(project);
                    },
                  ),
              ],
              const SizedBox(width: 4),
              IconBtn(
                icon: AppIcons.folder,
                tooltip: Platform.revealLabel,
                size: 26,
                iconSize: 13,
                onClick: () => Platform.reveal(project.path),
              ),
              const SizedBox(width: 4),
              IconBtn(
                icon: AppIcons.terminal,
                tooltip: 'Terminal at root',
                size: 26,
                iconSize: 13,
                onClick: () => Platform.openInTerminal(project.path),
              ),
              const SizedBox(width: 6),
              Btn(
                label: 'Open',
                icon: AppIcons.code,
                height: 26,
                onClick: () => state.launchProject(project),
              ),
            ],
          ),
        );
      },
    );
  }
}
