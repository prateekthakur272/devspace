import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/dot_pattern.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/catalog/project_card.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class CatalogView extends StatelessWidget {
  const CatalogView({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final projects = state.filteredProjects;

    return Container(
      color: p.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Halftone Dot Matrix Pattern
          const Positioned.fill(
            child: ClipRect(
              child: RepaintBoundary(
                child: DotPatternBackground(),
              ),
            ),
          ),
          // Projects Pane Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Tag indicator if filtered
              if (state.uiState.activeTagFilter != null)
                DrawBottomBorder(
                  color: p.border,
                  child: Container(
                    color: p.panel,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        T('Filtering by tag: ', size: 12, color: p.muted),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              T(
                                state.uiState.activeTagFilter!,
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: p.accent,
                              ),
                              const SizedBox(width: 4),
                              ClickableNoRipple(
                                onClick: () => state.updateUiState(
                                  (s) => s.copyWith(clearTagFilter: true),
                                ),
                                child: Icon(AppIcons.close, size: 11, color: p.accent),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ClickableNoRipple(
                          onClick: () => state.updateUiState(
                            (s) => s.copyWith(clearTagFilter: true),
                          ),
                          child: T('Clear Filter', size: 11.5, color: p.accent, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              // Project Cards Grid
              Expanded(
                child: projects.isEmpty
                    ? _EmptyCatalogState(state: state)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width > 1150
                              ? 3
                              : (width > 680 ? 2 : 1);

                          return GridView.builder(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 202,
                            ),
                            itemCount: projects.length,
                            itemBuilder: (context, index) {
                              return ProjectCard(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                                state: state,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({required this.state});
  final AppState state;

  Future<void> _pickSingleFolder(BuildContext context) async {
    final picked = await Platform.pickDirectory('Select Project Directory');
    if (picked != null) {
      state.modal = ModalAddProject(initialPath: picked);
    }
  }

  Future<void> _scanFolder(BuildContext context) async {
    final picked = await Platform.pickDirectory('Select Directory to Scan for Git Projects');
    if (picked != null) {
      await state.scanAndImportWorkspace(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ui = state.uiState;
    final hasSearch = ui.searchQuery.isNotEmpty;
    final hasTag = ui.activeTagFilter != null;
    final isPinned = ui.selectedWorkspaceId == 'pinned';
    final isDirty = ui.selectedWorkspaceId == 'dirty';

    // If there is an active search or tag filter
    if (hasSearch || hasTag) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Center(
                  child: Icon(
                    hasSearch ? AppIcons.search : AppIcons.branch,
                    size: 26,
                    color: p.muted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              T(
                hasSearch
                    ? 'No projects matching "${ui.searchQuery}"'
                    : 'No projects tagged with "${ui.activeTagFilter}"',
                size: 15,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 6),
              T(
                'Try broadening your search keywords or resetting filters',
                size: 12.5,
                color: p.muted,
              ),
              const SizedBox(height: 20),
              Btn(
                label: 'Reset Filters',
                icon: AppIcons.refresh,
                onClick: () {
                  state.updateUiState(
                    (s) => s.copyWith(searchQuery: '', clearTagFilter: true),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // If Pinned filter with 0 pinned items
    if (isPinned) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Center(
                  child: Icon(AppIcons.pin, size: 26, color: p.accent),
                ),
              ),
              const SizedBox(height: 16),
              const T('No favorites pinned yet', size: 15, weight: FontWeight.w600),
              const SizedBox(height: 6),
              T(
                'Pin your most active repositories for instant 1-click access from the sidebar',
                size: 12.5,
                color: p.muted,
                align: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Btn(
                label: 'View All Projects',
                icon: AppIcons.project,
                onClick: () => state.updateUiState(
                  (s) => s.copyWith(selectedWorkspaceId: 'all'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If Dirty filter with 0 dirty items
    if (isDirty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.ok.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.ok.withOpacity(0.3), width: 1),
                ),
                child: Center(
                  child: Icon(Icons.check_circle_outline_rounded, size: 28, color: p.ok),
                ),
              ),
              const SizedBox(height: 16),
              const T('All repositories are clean', size: 15, weight: FontWeight.w600),
              const SizedBox(height: 6),
              T(
                'No uncommitted changes, staged files, or dirty working trees',
                size: 12.5,
                color: p.muted,
                align: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Btn(
                label: 'View All Projects',
                icon: AppIcons.project,
                onClick: () => state.updateUiState(
                  (s) => s.copyWith(selectedWorkspaceId: 'all'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If a specific workspace group is empty
    if (ui.selectedWorkspaceId != 'all' && state.projects.isNotEmpty) {
      final ws = state.workspaces.firstWhere(
        (w) => w.id == ui.selectedWorkspaceId,
        orElse: () => const WorkspaceGroup(id: 'default', name: 'General'),
      );
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Center(
                  child: Icon(AppIcons.folder, size: 26, color: p.muted),
                ),
              ),
              const SizedBox(height: 16),
              T('No projects in ${ws.name}', size: 15, weight: FontWeight.w600),
              const SizedBox(height: 6),
              T(
                'Drag and drop a project folder here, add manually, or move existing repositories using the card context menu',
                size: 12.5,
                color: p.muted,
                align: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Btn(
                    label: 'Add to ${ws.name}',
                    icon: AppIcons.add,
                    primary: true,
                    onClick: () => state.modal = ModalAddProject(initialWorkspaceId: ws.id),
                  ),
                  const SizedBox(width: 8),
                  Btn(
                    label: 'View All Projects',
                    outlined: true,
                    onClick: () => state.updateUiState(
                      (s) => s.copyWith(selectedWorkspaceId: 'all'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Default / Global Empty State: (when state.projects.isEmpty)
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive Hero Avatar / Drop Zone
            HoverBuilder(
              cursor: SystemMouseCursors.click,
              onTap: () => _pickSingleFolder(context),
              builder: (context, hovered) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: hovered ? p.accent.withOpacity(0.08) : p.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hovered ? p.accent : p.border,
                      width: hovered ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hovered
                            ? p.accent.withOpacity(0.2)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: hovered ? 16 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      AppIcons.folder,
                      size: 30,
                      color: hovered ? p.accent : p.muted,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const T(
              'No projects yet',
              size: 18,
              weight: FontWeight.w600,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: T(
                'Drag and drop a project folder here, or browse a local directory to begin organizing, monitoring, and launching your projects.',
                size: 12.5,
                color: p.muted,
                align: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            // Primary interactive button actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Btn(
                  label: 'Browse Folder…',
                  icon: AppIcons.folder,
                  primary: true,
                  height: 34,
                  onClick: () => _pickSingleFolder(context),
                ),
                Btn(
                  label: 'Add Manually…',
                  icon: AppIcons.add,
                  outlined: true,
                  height: 34,
                  onClick: () => state.modal = const ModalAddProject(),
                ),
                Btn(
                  label: 'Welcome Tour…',
                  icon: Icons.explore_outlined,
                  outlined: true,
                  height: 34,
                  onClick: () => state.modal = const ModalOnboarding(),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Quick Action Cards
            Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.panel.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border.withOpacity(0.8), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: AppIcons.radar,
                      iconColor: p.accent,
                      title: 'Scan Directory',
                      subtitle: 'Auto-import repos',
                      onClick: () => _scanFolder(context),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: p.border.withOpacity(0.6),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Expanded(
                    child: _QuickActionTile(
                      icon: AppIcons.palette,
                      iconColor: p.muted,
                      title: 'Command Palette',
                      subtitle: 'Press ⌘K anytime',
                      trailingChip: '⌘K',
                      onClick: () => state.paletteOpen = true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClick,
    this.iconColor,
    this.trailingChip,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClick;
  final Color? iconColor;
  final String? trailingChip;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: onClick,
      builder: (context, hovered) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? p.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor ?? p.text),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    T(title, size: 12, weight: FontWeight.w600, color: hovered ? p.accent : p.text),
                    T(subtitle, size: 10.5, color: p.muted),
                  ],
                ),
              ),
              if (trailingChip != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: p.border, width: 0.5),
                  ),
                  child: MonoText(trailingChip!, size: 10, color: p.muted, weight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
