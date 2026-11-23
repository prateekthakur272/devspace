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
import 'package:devspace/utils/app_config.dart';
import 'package:devspace/utils/issue_report.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ui = state.uiState;
    final projects = state.projects;

    // Calculate aggregated git metrics
    int dirtyCount = 0;
    int aheadCount = 0;
    int behindCount = 0;
    int repoCount = 0;

    for (final pr in projects) {
      final s = state.gitStatuses[pr.id];
      if (s != null && s.isGitRepo) {
        repoCount++;
        if (s.isDirty) dirtyCount++;
        if (s.aheadCount > 0) aheadCount += s.aheadCount;
        if (s.behindCount > 0) behindCount += s.behindCount;
      }
    }

    // Active workspace name
    String workspaceName = 'All Projects';
    if (ui.selectedWorkspaceId == 'pinned') {
      workspaceName = 'Favorites / Pinned';
    } else if (ui.selectedWorkspaceId == 'dirty') {
      workspaceName = 'Needs Attention';
    } else if (ui.selectedWorkspaceId != 'all') {
      final ws = state.workspaces.firstWhere(
        (w) => w.id == ui.selectedWorkspaceId,
        orElse: () => const WorkspaceGroup(id: 'all', name: 'General'),
      );
      workspaceName = ws.name;
    }

    Widget click(VoidCallback f, Widget child, {String? tooltip}) {
      Widget w = ClickableNoRipple(
        onClick: f,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
      );
      if (tooltip != null) {
        w = Tooltip(message: tooltip, child: w);
      }
      return w;
    }

    return Container(
      height: 24,
      color: p.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: CustomPaint(
        painter: _TopBorderPainter(p.border),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final isNormal = constraints.maxWidth >= 740;

            return SizedBox(
              width: constraints.maxWidth,
              child: Row(
                children: [
                  // Left Quick Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBtn(
                        icon: AppIcons.sidebar,
                        tooltip: ui.sidebarVisible
                            ? 'Hide Sidebar (${Platform.isMac ? "⌘B" : "Ctrl+B"})'
                            : 'Show Sidebar (${Platform.isMac ? "⌘B" : "Ctrl+B"})',
                        size: 20,
                        iconSize: 13,
                        color: ui.sidebarVisible ? p.accent : p.muted,
                        onClick: () => state.updateUiState(
                          (s) => s.copyWith(sidebarVisible: !s.sidebarVisible),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconBtn(
                        icon: AppIcons.settings,
                        tooltip: 'Preferences (${Platform.isMac ? "⌘," : "Ctrl+,"})',
                        size: 20,
                        iconSize: 13,
                        color: p.muted,
                        onClick: () => state.modal = const ModalSettings(),
                      ),
                      const SizedBox(width: 4),
                      IconBtn(
                        icon: AppIcons.info,
                        tooltip: 'About DevSpace',
                        size: 20,
                        iconSize: 13,
                        color: p.muted,
                        onClick: () => state.modal = const ModalAbout(),
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (btnCtx) => GestureDetector(
                          onSecondaryTapUp: (details) {
                            ContextMenu.show(btnCtx, details.globalPosition, [
                              ContextMenuItem(
                                label: 'Developer & Project…',
                                icon: AppIcons.info,
                                action: () =>
                                    state.modal = const ModalDeveloper(),
                              ),
                              ContextMenuItem(
                                label: 'DevSpace Repository',
                                icon: AppIcons.external,
                                action: () =>
                                    Platform.openUrl(AppConfig.REPOSITORY),
                              ),
                              ContextMenuItem(
                                label: 'Star on GitHub',
                                icon: Icons.star_rounded,
                                action: () =>
                                    Platform.openUrl(AppConfig.REPOSITORY),
                              ),
                              ContextMenuItem(
                                label: 'Releases & Changelog',
                                icon: AppIcons.download,
                                action: () =>
                                    Platform.openUrl(AppConfig.RELEASES_URL),
                              ),
                              const ContextMenuItem(label: ''),
                              ContextMenuItem(
                                label: 'Report an Issue…',
                                icon: AppIcons.bug,
                                action: () => Platform.openUrl(
                                  IssueReport.url().toString(),
                                ),
                              ),
                              ContextMenuItem(
                                label: 'Explore More Apps',
                                icon: Icons.apps_rounded,
                                action: () =>
                                    Platform.openUrl(AppConfig.MORE_APPS_URL),
                              ),
                            ]);
                          },
                          child: IconBtn(
                            icon: AppIcons.github,
                            tooltip: 'GitHub',
                            size: 20,
                            iconSize: 13,
                            color: p.muted,
                            onClick: () => state.modal = const ModalDeveloper(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconBtn(
                        key: const ValueKey('report-issue'),
                        icon: AppIcons.bug,
                        tooltip: 'Report an issue',
                        size: 20,
                        iconSize: 13,
                        color: p.muted,
                        onClick: () =>
                            Platform.openUrl(IssueReport.url().toString()),
                      ),
                      if (state.availableUpdate != null) ...[
                        const SizedBox(width: 4),
                        IconBtn(
                          icon: AppIcons.download,
                          tooltip:
                              'Update available: ${state.availableUpdate} — click to view',
                          size: 20,
                          iconSize: 13,
                          color: p.accent,
                          onClick: () => state.modal = ModalUpdateAvailable(
                            state.availableUpdate!,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Active Workspace Indicator (bounded width so Spacer owns all remaining flex)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 260 : 160),
                    child: click(
                      () => state.modal = const ModalAddProject(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: T(
                              workspaceName,
                              size: 11,
                              weight: FontWeight.w500,
                              color: p.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      tooltip: 'Current Workspace View',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Project Count
                  T(
                    '${projects.length} project${projects.length == 1 ? '' : 's'}',
                    size: 11,
                    color: p.muted,
                  ),
                  // Spacer pushes all right-hand action buttons flush to the end of the bar
                  const Spacer(),
                  // Right-Hand Quick Status & Navigation Group
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Right Side: Git Health Summary
                      if (repoCount > 0) ...[
                        click(
                          () => state.updateUiState(
                            (s) => s.copyWith(activeTab: 'git_radar'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.branch, size: 11, color: p.muted),
                              const SizedBox(width: 4),
                              if (dirtyCount > 0)
                                T(
                                  '$dirtyCount dirty',
                                  size: 11,
                                  color: p.warn,
                                  weight: FontWeight.w600,
                                )
                              else
                                T(
                                  'all clean',
                                  size: 11,
                                  color: p.ok,
                                  weight: FontWeight.w500,
                                ),
                              if (aheadCount > 0) ...[
                                const SizedBox(width: 6),
                                T(
                                  '↑$aheadCount',
                                  size: 11,
                                  color: p.accent,
                                  weight: FontWeight.w600,
                                ),
                              ],
                              if (behindCount > 0) ...[
                                const SizedBox(width: 6),
                                T(
                                  '↓$behindCount',
                                  size: 11,
                                  color: p.err,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ],
                          ),
                          tooltip: 'Git Status (click to view radar)',
                        ),
                        const SizedBox(width: 14),
                      ],
                      // Detected Tools & IDEs Indicator
                      if (isNormal) ...[
                        click(
                          () => state.modal = const ModalDetectedTools(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.terminal,
                                size: 11,
                                color: state.toolsScanning ? p.accent : p.muted,
                              ),
                              const SizedBox(width: 4),
                              if (state.toolsScanning)
                                T('scanning…', size: 11, color: p.accent)
                              else
                                T(
                                  isWide
                                      ? '${state.detectedTools.length} tools · ${state.availableEditors.length} IDEs'
                                      : '${state.detectedTools.length} tools',
                                  size: 11,
                                  color: p.muted,
                                ),
                            ],
                          ),
                          tooltip: 'Installed Developer Tools & IDEs',
                        ),
                        const SizedBox(width: 14),
                      ],
                      // Default IDE
                      if (isWide) ...[
                        click(
                          () => state.modal = const ModalSettings(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.code, size: 11, color: p.muted),
                              const SizedBox(width: 4),
                              T(
                                state.settings.defaultEditor.label,
                                size: 11,
                                color: p.muted,
                              ),
                            ],
                          ),
                          tooltip: 'Default Editor: ${state.settings.defaultEditor.label}',
                        ),
                        const SizedBox(width: 14),
                      ],
                      // Command Palette Quick Trigger
                      click(
                        () => state.paletteOpen = true,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MonoText(
                              Platform.isMac ? '⌘K' : 'Ctrl+K',
                              size: 11,
                              color: p.accent,
                              weight: FontWeight.w600,
                            ),
                            const SizedBox(width: 4),
                            T('commands', size: 11, color: p.muted),
                          ],
                        ),
                        tooltip: 'Open Command Palette (${Platform.isMac ? "⌘K" : "Ctrl+K"})',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBorderPainter extends CustomPainter {
  const _TopBorderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(0, 0.5),
      Offset(size.width, 0.5),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_TopBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
