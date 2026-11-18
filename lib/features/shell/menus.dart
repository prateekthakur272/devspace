import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';
import 'package:devspace/utils/app_metadata.dart';
import 'package:devspace/utils/paths.dart';
import 'package:devspace/utils/update_checker.dart';

class Shortcut {
  const Shortcut(
    this.key, {
    this.primary = true,
    this.shift = false,
    this.control = false,
  });

  final LogicalKeyboardKey key;
  final bool primary;
  final bool shift;
  final bool control;

  SingleActivator toActivator(bool isMac) => SingleActivator(
        key,
        control: control || (primary && !isMac),
        meta: primary && isMac,
        shift: shift,
      );

  String label(bool isMac) {
    String k;
    if (key == LogicalKeyboardKey.keyK) {
      k = 'K';
    } else if (key == LogicalKeyboardKey.keyN) {
      k = 'N';
    } else if (key == LogicalKeyboardKey.keyR) {
      k = 'R';
    } else if (key == LogicalKeyboardKey.comma) {
      k = ',';
    } else if (key == LogicalKeyboardKey.keyQ) {
      k = 'Q';
    } else {
      k = key.keyLabel.toUpperCase();
    }

    if (isMac) {
      return (control ? '⌃' : '') +
          (shift ? '⇧' : '') +
          (primary ? '⌘' : '') +
          k;
    }
    return [if (primary || control) 'Ctrl', if (shift) 'Shift', k].join('+');
  }
}

/// Triggers a manual update check.
/// Shows a toast or opens the update modal so the user gets instant feedback.
void checkForUpdates(AppState state) {
  unawaited(_doCheckForUpdates(state));
}

Future<void> _doCheckForUpdates(AppState state) async {
  await UpdateChecker.clearDismissed();
  final result = await UpdateChecker.check(AppMetadata.version);
  if (result.failed) {
    state.showToast("Couldn't check for updates: ${result.error}");
  } else if (result.hasUpdate) {
    state.availableUpdate = result.version;
    state.modal = ModalUpdateAvailable(result.version!);
  } else {
    state.availableUpdate = null;
    state.showToast('${AppConfig.NAME} is up to date (${AppMetadata.version})');
  }
}

/// Comprehensive macOS native top-bar menus (PlatformMenuBar).
List<PlatformMenuItem> buildMacMenus(AppState state, VoidCallback onQuit) {
  return [
    PlatformMenu(
      label: AppConfig.NAME,
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'About ${AppConfig.NAME}',
              onSelected: () => state.modal = const ModalAbout(),
            ),
            PlatformMenuItem(
              label: 'Developer…',
              onSelected: () => state.modal = const ModalDeveloper(),
            ),
            PlatformMenuItem(
              label: 'Check for Updates…',
              onSelected: () => checkForUpdates(state),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Preferences…',
              shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: () => state.modal = const ModalSettings(),
            ),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Quit ${AppConfig.NAME}',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
              onSelected: onQuit,
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Add Project…',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
              onSelected: () => state.modal = const ModalAddProject(),
            ),
            PlatformMenuItem(
              label: 'New Note',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true, alt: true),
              onSelected: () => state.openNewNoteInPane(),
            ),
            PlatformMenuItem(
              label: 'Add Workspace Folder…',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onSelected: () => state.modal = const ModalCreateGroup(),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Show Data Folder',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyD, meta: true, alt: true),
              onSelected: () => Platform.reveal(AppStore.dir),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Close Window',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyW, meta: true),
              onSelected: onQuit,
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
              onSelected: () {},
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              onSelected: () {},
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Command Palette…',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
              onSelected: () => state.paletteOpen = true,
            ),
            PlatformMenuItem(
              label: 'Refresh All Git Repos',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () => state.refreshAllGit(),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Projects Catalog',
              shortcut: const SingleActivator(LogicalKeyboardKey.digit1, meta: true),
              onSelected: () => state.updateUiState((s) => s.copyWith(activeTab: 'projects')),
            ),
            PlatformMenuItem(
              label: 'Git Radar',
              shortcut: const SingleActivator(LogicalKeyboardKey.digit2, meta: true),
              onSelected: () => state.updateUiState((s) => s.copyWith(activeTab: 'git_radar')),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Toggle Sidebar',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyB, meta: true),
              onSelected: () => state.updateUiState((s) => s.copyWith(sidebarVisible: !s.sidebarVisible)),
            ),
            PlatformMenuItem(
              label: 'Toggle Notes Pane',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyB, meta: true, alt: true),
              onSelected: () => state.toggleNotesPane(),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Toggle Dark / Light Theme',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyT, meta: true),
              onSelected: () => state.updateSettings(
                state.settings.copyWith(
                  themeMode: state.settings.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Window',
      menus: [
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.arrangeWindowsInFront),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Help',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Welcome & Onboarding Tour…',
              onSelected: () => state.modal = const ModalOnboarding(),
            ),
            PlatformMenuItem(
              label: 'Check for Updates…',
              onSelected: () => checkForUpdates(state),
            ),
            PlatformMenuItem(
              label: 'Keyboard Shortcuts Reference',
              onSelected: () => state.paletteOpen = true,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Show Data Folder',
              onSelected: () => Platform.reveal(AppStore.dir),
            ),
            PlatformMenuItem(
              label: 'Show Log File',
              onSelected: () => Platform.reveal(Paths.logFile(AppStore.dir)),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Developer & GitHub…',
              onSelected: () => state.modal = const ModalDeveloper(),
            ),
            PlatformMenuItem(
              label: 'Report an Issue…',
              onSelected: () => Platform.openUrl(AppConfig.ISSUES_URL),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'About ${AppConfig.NAME}',
              onSelected: () => state.modal = const ModalAbout(),
            ),
          ],
        ),
      ],
    ),
  ];
}

/// Menu items map for Windows and Linux in-window desktop titlebar menus.
Map<String, List<ContextMenuItem>> buildWindowsLinuxMenuItems({
  required AppState state,
  required VoidCallback onQuit,
  VoidCallback? onMinimize,
  VoidCallback? onToggleMaximize,
}) {
  return {
    'File': [
      ContextMenuItem(
        label: 'Add Project…',
        icon: AppIcons.add,
        shortcut: 'Ctrl+N',
        action: () => state.modal = const ModalAddProject(),
      ),
      ContextMenuItem(
        label: 'New Note',
        icon: AppIcons.note,
        shortcut: 'Ctrl+Shift+N',
        action: () => state.openNewNoteInPane(),
      ),
      ContextMenuItem(
        label: 'Add Workspace Folder…',
        icon: Icons.create_new_folder_outlined,
        shortcut: 'Ctrl+O',
        action: () => state.modal = const ModalCreateGroup(),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Settings…',
        icon: AppIcons.settings,
        shortcut: 'Ctrl+,',
        action: () => state.modal = const ModalSettings(),
      ),
      ContextMenuItem(
        label: 'Open Data Directory',
        icon: Icons.folder_special_outlined,
        action: () => Platform.reveal(AppStore.dir),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Exit',
        icon: Icons.exit_to_app_rounded,
        shortcut: 'Alt+F4',
        danger: true,
        action: onQuit,
      ),
    ],
    'Edit': [
      ContextMenuItem(
        label: 'Undo',
        icon: Icons.undo_rounded,
        shortcut: 'Ctrl+Z',
        action: () => state.showToast('Undo'),
      ),
      ContextMenuItem(
        label: 'Redo',
        icon: Icons.redo_rounded,
        shortcut: 'Ctrl+Y',
        action: () => state.showToast('Redo'),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Cut',
        icon: Icons.content_cut_rounded,
        shortcut: 'Ctrl+X',
        action: () => state.showToast('Cut'),
      ),
      ContextMenuItem(
        label: 'Copy',
        icon: Icons.content_copy_rounded,
        shortcut: 'Ctrl+C',
        action: () => state.showToast('Copy'),
      ),
      ContextMenuItem(
        label: 'Paste',
        icon: Icons.content_paste_rounded,
        shortcut: 'Ctrl+V',
        action: () => state.showToast('Paste'),
      ),
      ContextMenuItem(
        label: 'Select All',
        icon: Icons.select_all_rounded,
        shortcut: 'Ctrl+A',
        action: () => state.showToast('Select All'),
      ),
    ],
    'View': [
      ContextMenuItem(
        label: 'Command Palette…',
        icon: AppIcons.search,
        shortcut: 'Ctrl+K',
        action: () => state.paletteOpen = true,
      ),
      ContextMenuItem(
        label: 'Refresh All Git Repos',
        icon: AppIcons.refresh,
        shortcut: 'Ctrl+R',
        action: () => state.refreshAllGit(),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Projects Catalog',
        icon: Icons.grid_view_rounded,
        shortcut: 'Ctrl+1',
        action: () => state.updateUiState((s) => s.copyWith(activeTab: 'projects')),
      ),
      ContextMenuItem(
        label: 'Combined Git Radar',
        icon: AppIcons.radar,
        shortcut: 'Ctrl+2',
        action: () => state.updateUiState((s) => s.copyWith(activeTab: 'git_radar')),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Toggle Sidebar',
        icon: Icons.view_sidebar_outlined,
        shortcut: 'Ctrl+B',
        action: () => state.updateUiState((s) => s.copyWith(sidebarVisible: !s.sidebarVisible)),
      ),
      ContextMenuItem(
        label: 'Toggle Notes Pane',
        icon: AppIcons.note,
        shortcut: 'Ctrl+Shift+B',
        action: () => state.toggleNotesPane(),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Toggle Dark / Light Theme',
        icon: Icons.brightness_medium_outlined,
        shortcut: 'Ctrl+T',
        action: () => state.updateSettings(
          state.settings.copyWith(
            themeMode: state.settings.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
          ),
        ),
      ),
    ],
    'Window': [
      ContextMenuItem(
        label: 'Minimize',
        icon: AppIcons.windowMinimize,
        shortcut: 'Ctrl+M',
        action: onMinimize,
      ),
      ContextMenuItem(
        label: 'Maximize / Restore',
        icon: AppIcons.windowMaximize,
        action: onToggleMaximize,
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Close Window',
        icon: AppIcons.windowClose,
        shortcut: 'Alt+F4',
        danger: true,
        action: onQuit,
      ),
    ],
    'Help': [
      ContextMenuItem(
        label: 'Welcome & Onboarding Tour…',
        icon: Icons.explore_outlined,
        action: () => state.modal = const ModalOnboarding(),
      ),
      ContextMenuItem(
        label: 'Check for Updates…',
        icon: Icons.system_update_rounded,
        action: () => checkForUpdates(state),
      ),
      ContextMenuItem(
        label: 'Keyboard Shortcuts Reference',
        icon: Icons.keyboard_outlined,
        shortcut: 'Ctrl+?',
        action: () => state.paletteOpen = true,
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Show Data Directory',
        icon: Icons.folder_outlined,
        action: () => Platform.reveal(AppStore.dir),
      ),
      ContextMenuItem(
        label: 'Show Log File',
        icon: Icons.description_outlined,
        action: () => Platform.reveal(Paths.logFile(AppStore.dir)),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Developer & GitHub…',
        icon: AppIcons.github,
        action: () => state.modal = const ModalDeveloper(),
      ),
      ContextMenuItem(
        label: 'Report an Issue…',
        icon: AppIcons.bug,
        action: () => Platform.openUrl(AppConfig.ISSUES_URL),
      ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'About ${AppConfig.NAME}',
        icon: Icons.info_outline_rounded,
        action: () => state.modal = const ModalAbout(),
      ),
    ],
  };
}

/// In-window menu bar for Windows and Linux custom window chrome.
class WindowMenuBar extends StatefulWidget {
  const WindowMenuBar({
    super.key,
    required this.state,
    required this.onQuit,
    this.onMinimize,
    this.onToggleMaximize,
  });

  final AppState state;
  final VoidCallback onQuit;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;

  @override
  State<WindowMenuBar> createState() => _WindowMenuBarState();
}

class _WindowMenuBarState extends State<WindowMenuBar> {
  String? _activeMenu;

  void _openMenu(BuildContext btnContext, String name, List<ContextMenuItem> items) {
    setState(() => _activeMenu = name);
    final box = btnContext.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset(0, box.size.height + 2));
      ContextMenu.show(context, pos, items).then((_) {
        if (mounted) setState(() => _activeMenu = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final menuItemsMap = buildWindowsLinuxMenuItems(
      state: widget.state,
      onQuit: widget.onQuit,
      onMinimize: widget.onMinimize,
      onToggleMaximize: widget.onToggleMaximize,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 6),
          child: Image.asset(
            'assets/icons/header_logo.png',
            width: 14,
            height: 14,
            filterQuality: FilterQuality.medium,
          ),
        ),
        for (final entry in menuItemsMap.entries)
          Builder(
            builder: (btnCtx) {
              final isOpen = _activeMenu == entry.key;
              return HoverBuilder(
                cursor: SystemMouseCursors.click,
                onTap: () => _openMenu(btnCtx, entry.key, entry.value),
                builder: (context, hovered) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOpen || hovered ? p.hover : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: T(
                      entry.key,
                      size: 11.5,
                      weight: FontWeight.w500,
                      color: isOpen || hovered ? p.text : p.muted,
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
