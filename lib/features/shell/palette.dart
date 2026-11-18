import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

int _fuzzy(String q, String t) {
  if (q.isEmpty) return 0;
  final ql = q.toLowerCase();
  final tl = t.toLowerCase();
  var qi = 0, score = 0, last = -2;
  for (var i = 0; i < tl.length; i++) {
    if (qi < ql.length && tl[i] == ql[qi]) {
      score += i == last + 1 ? 6 : 1;
      if (i == 0 || ' /-_.:'.contains(tl[i - 1])) score += 4;
      last = i;
      qi++;
    }
  }
  return qi == ql.length ? score - tl.length ~/ 25 : -1;
}

class _PaletteItem {
  const _PaletteItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.leading,
    this.badge,
    this.badgeColor,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Widget? leading;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback action;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.state});
  final AppState state;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_PaletteItem> _buildItems() {
    final state = widget.state;
    final list = <_PaletteItem>[];

    // Global Actions
    list.add(_PaletteItem(
      title: 'Add Project to Workspace',
      subtitle: 'Pick a folder anywhere on your disk',
      category: 'Actions',
      icon: AppIcons.add,
      action: () {
        state.paletteOpen = false;
        state.modal = const ModalAddProject();
      },
    ));

    list.add(_PaletteItem(
      title: 'Create Workspace Group',
      subtitle: 'Create a custom category or workspace folder',
      category: 'Actions',
      icon: AppIcons.folder,
      action: () {
        state.paletteOpen = false;
        state.modal = const ModalCreateGroup();
      },
    ));

    list.add(_PaletteItem(
      title: 'Refresh All Git Repositories',
      subtitle: 'Fetch and check uncommitted changes and branch states',
      category: 'Actions',
      icon: AppIcons.refresh,
      action: () {
        state.paletteOpen = false;
        state.refreshAllGit();
      },
    ));

    list.add(_PaletteItem(
      title: 'Open Preferences & Settings',
      subtitle: 'Change theme, default IDE, and polling interval',
      category: 'Actions',
      icon: AppIcons.settings,
      action: () {
        state.paletteOpen = false;
        state.modal = const ModalSettings();
      },
    ));

    list.add(_PaletteItem(
      title: 'Welcome & Onboarding Tour',
      subtitle: 'Explore features, customize IDE, and set up your workspace',
      category: 'Actions',
      icon: Icons.explore_outlined,
      action: () {
        state.paletteOpen = false;
        state.modal = const ModalOnboarding();
      },
    ));

    list.add(_PaletteItem(
      title: 'Switch to Combined Git Radar',
      subtitle: 'View all repository statuses across your workspace',
      category: 'Actions',
      icon: AppIcons.radar,
      action: () {
        state.paletteOpen = false;
        state.updateUiState((s) => s.copyWith(activeTab: 'git_radar'));
      },
    ));

    list.add(_PaletteItem(
      title: 'Switch to Project Catalog',
      subtitle: 'View and launch your projects',
      category: 'Actions',
      icon: AppIcons.project,
      action: () {
        state.paletteOpen = false;
        state.updateUiState((s) => s.copyWith(activeTab: 'projects'));
      },
    ));

    list.add(_PaletteItem(
      title: 'Toggle Notes Side Pane',
      subtitle: state.uiState.notesPaneVisible
          ? 'Hide the right notes & checklists pane'
          : 'Show the right notes & checklists pane',
      category: 'Actions',
      icon: AppIcons.note,
      action: () {
        state.paletteOpen = false;
        state.toggleNotesPane();
      },
    ));

    list.add(_PaletteItem(
      title: 'Toggle Integrated Terminal',
      subtitle: state.terminalVisible
          ? 'Hide the VS Code-style bottom terminal panel'
          : 'Open the VS Code-style bottom terminal panel',
      category: 'Terminal',
      icon: AppIcons.terminal,
      badge: Platform.isMac ? '⌘`' : 'Ctrl+`',
      action: () {
        state.paletteOpen = false;
        state.toggleTerminal();
      },
    ));

    list.add(_PaletteItem(
      title: 'Terminal: New Tab Session',
      subtitle: 'Create a new terminal session in working directory',
      category: 'Terminal',
      icon: AppIcons.add,
      action: () {
        state.paletteOpen = false;
        state.toggleTerminal(true);
        state.terminalController.createSession();
      },
    ));

    list.add(_PaletteItem(
      title: 'Terminal: Clear Output Buffer',
      subtitle: 'Clear screen and output history for active session',
      category: 'Terminal',
      icon: AppIcons.delete,
      badge: Platform.isMac ? '⌘K' : 'Ctrl+L',
      action: () {
        state.paletteOpen = false;
        state.terminalController.activeSession.clear();
      },
    ));

    list.add(_PaletteItem(
      title: 'Toggle Tools & IDEs Rail',
      subtitle: state.settings.showToolsRail
          ? 'Hide the right launcher rail for installed tools and editors'
          : 'Show the right launcher rail for installed tools and editors',
      category: 'Actions',
      icon: AppIcons.terminal,
      action: () {
        state.paletteOpen = false;
        state.toggleToolsRail();
      },
    ));

    list.add(_PaletteItem(
      title: 'Pin Application to Toolbar…',
      subtitle: 'Add a desktop application to the quick-launch rail',
      category: 'Actions',
      icon: AppIcons.add,
      action: () {
        state.paletteOpen = false;
        state.modal = const ModalPinApp();
      },
    ));

    list.add(_PaletteItem(
      title: 'Create New Note…',
      subtitle: 'Add a new note, checklist, or project task',
      category: 'Actions',
      icon: AppIcons.add,
      action: () {
        state.paletteOpen = false;
        state.openNewNoteInPane();
      },
    ));

    // Sorting Options
    for (final opt in ProjectSortOption.values) {
      list.add(_PaletteItem(
        title: 'Sort Projects: ${opt.label}',
        subtitle: 'Reorder project catalog',
        category: 'Sorting',
        icon: opt.icon,
        badge: state.uiState.sortBy == opt ? 'Active' : null,
        badgeColor: state.uiState.sortBy == opt ? const Color(0xFF6C5CE7) : null,
        action: () {
          state.paletteOpen = false;
          state.updateUiState((s) => s.copyWith(sortBy: opt, activeTab: 'projects'));
        },
      ));
    }

    // Projects
    for (final p in state.projects) {
      list.add(_PaletteItem(
        title: 'Open ${p.name}',
        subtitle: 'Launch in ${p.defaultEditor.label} • ${p.path}',
        category: 'Projects',
        icon: AppIcons.code,
        leading: IdeIcon(editor: p.defaultEditor, size: 16),
        badge: p.techStack.label,
        badgeColor: p.techStack.color,
        action: () {
          state.paletteOpen = false;
          state.launchProject(p);
        },
      ));

      list.add(_PaletteItem(
        title: 'Show ${p.name} in File Manager',
        subtitle: p.path,
        category: 'Projects',
        icon: AppIcons.folder,
        action: () {
          state.paletteOpen = false;
          Platform.reveal(p.path);
        },
      ));

      list.add(_PaletteItem(
        title: 'Open ${p.name} in ${state.settings.defaultTerminal.label}',
        subtitle: p.path,
        category: 'Projects',
        icon: AppIcons.terminal,
        action: () {
          state.paletteOpen = false;
          state.openTerminal(p.path, title: p.name);
        },
      ));

      list.add(_PaletteItem(
        title: state.settings.defaultTerminal == DefaultTerminalType.integrated
            ? 'Open ${p.name} in System Terminal'
            : 'Open ${p.name} in Integrated Terminal',
        subtitle: p.path,
        category: 'Projects',
        icon: state.settings.defaultTerminal == DefaultTerminalType.integrated
            ? AppIcons.external
            : AppIcons.terminal,
        action: () {
          state.paletteOpen = false;
          if (state.settings.defaultTerminal == DefaultTerminalType.integrated) {
            state.openSystemTerminal(p.path);
          } else {
            state.openIntegratedTerminal(p.path, title: p.name);
          }
        },
      ));

      list.add(_PaletteItem(
        title: 'Copy Path for ${p.name}',
        subtitle: p.path,
        category: 'Projects',
        icon: AppIcons.copy,
        action: () {
          state.paletteOpen = false;
          Platform.copy(p.path);
        },
      ));
    }

    // Notes
    for (final note in state.notes) {
      final total = note.checklist.length;
      final done = note.checklist.where((c) => c.checked).length;
      final extra = [
        if (total > 0) '$done/$total checklist',
        if (note.tags.isNotEmpty) note.tags.join(' '),
      ].join(' • ');

      list.add(_PaletteItem(
        title: 'Note: ${note.title.isNotEmpty ? note.title : 'Untitled Note'}',
        subtitle: [note.plainContent, extra].where((s) => s.isNotEmpty).join(' • '),
        category: 'Notes',
        icon: AppIcons.note,
        badge: note.pinned ? 'Pinned' : null,
        badgeColor: note.pinned ? const Color(0xFF6C5CE7) : null,
        action: () {
          state.paletteOpen = false;
          state.openNoteInPane(note);
        },
      ));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final query = _controller.text.trim();
    final allItems = _buildItems();

    final filtered = query.isEmpty
        ? allItems
        : (allItems
            .map((item) {
              final score = _fuzzy(query, '${item.title} ${item.subtitle}');
              return (item: item, score: score);
            })
            .where((it) => it.score >= 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score)))
            .map((it) => it.item)
            .toList();

    final safeIndex = filtered.isEmpty
        ? 0
        : _selectedIndex.clamp(0, filtered.length - 1);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              if (filtered.isNotEmpty) {
                _selectedIndex = (_selectedIndex + 1) % filtered.length;
              }
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              if (filtered.isNotEmpty) {
                _selectedIndex =
                    (_selectedIndex - 1 + filtered.length) % filtered.length;
              }
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (filtered.isNotEmpty) {
              filtered[safeIndex].action();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.state.paletteOpen = false;
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ClickableNoRipple(
        onClick: () => widget.state.paletteOpen = false,
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Align(
            alignment: const Alignment(0, -0.6),
            child: ClickableNoRipple(
              onClick: () {}, // Prevent click propagation
              child: Container(
                width: 620,
                constraints: const BoxConstraints(maxHeight: 460),
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search bar
                    DrawBottomBorder(
                      color: p.border,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Icon(AppIcons.search, size: 16, color: p.muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(0, -1.5),
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    onChanged: (_) => setState(() => _selectedIndex = 0),
                                    maxLines: 1,
                                    cursorHeight: 16,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: p.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration.collapsed(
                                      hintText: 'Type a command, project, or action…',
                                      hintStyle: TextStyle(
                                        color: p.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.field,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: p.border, width: 0.5),
                              ),
                              child: T('ESC', size: 10, color: p.muted, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Item list
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: T('No matching projects or commands', color: p.muted),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemBuilder: (context, idx) {
                                final item = filtered[idx];
                                final isSelected = idx == safeIndex;

                                return HoverBuilder(
                                  cursor: SystemMouseCursors.click,
                                  onTap: item.action,
                                  builder: (context, hovered) {
                                    final bg = isSelected
                                        ? p.accent.withOpacity(0.14)
                                        : (hovered ? p.hover : Colors.transparent);

                                    return Container(
                                      color: bg,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          if (item.leading != null)
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Center(child: item.leading!),
                                            )
                                          else
                                            Icon(
                                              item.icon,
                                              size: 16,
                                              color: isSelected ? p.accent : p.muted,
                                            ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                T(
                                                  item.title,
                                                  size: 13,
                                                  weight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected ? p.accent : p.text,
                                                ),
                                                T(
                                                  item.subtitle,
                                                  size: 11.5,
                                                  color: p.muted,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (item.badge != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (item.badgeColor ?? p.accent)
                                                    .withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: T(
                                                item.badge!,
                                                size: 10.5,
                                                color: item.badgeColor ?? p.accent,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 8),
                                          T(
                                            item.category,
                                            size: 11,
                                            color: p.muted.withOpacity(0.7),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
