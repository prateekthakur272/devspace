import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/utils/app_config.dart';

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
      ],
    ),
  ];
}
