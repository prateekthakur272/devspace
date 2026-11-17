import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ui = state.uiState;

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
          // Sidebar Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: [
                // Workspace Section Header
                _SectionTitle('WORKSPACES'),
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
                  _SectionTitle('TAGS'),
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
            ),
          ),
          // Bottom Actions
          DrawTopBorder(
            color: p.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Btn(
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
