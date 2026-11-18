import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/core/ide/ide_service.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/paths.dart';

/// Right-hand vertical quick-launch rail for installed IDEs, code editors,
/// and developer tools that open as desktop applications.
class ToolsRail extends StatelessWidget {
  const ToolsRail({super.key, required this.state});
  final AppState state;

  static const double kRailWidth = 44.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final p = context.pal;
    final editors = state.availableEditors;
    final desktopApps = state.installedDesktopApps;

    return Container(
      width: kRailWidth,
      decoration: BoxDecoration(
        color: p.sidebar,
        border: Border(left: BorderSide(color: p.border, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // 1. Quick Launch System Terminal Application
          _RailIconButton(
            tooltip: 'System Terminal\nClick to launch terminal application',
            onClick: () => Platform.openInTerminal(Paths.home),
            child: _terminalIcon(p),
          ),

          _divider(p),

          // 2. Scrollable Middle List of Installed Applications (IDEs & GUI Tools)
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Installed Code Editors & IDE Applications
                  for (final editor in editors)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _RailIconButton(
                        tooltip: 'Open ${editor.label}\nClick to launch editor application',
                        onClick: () => IdeService.launchEditor(editor),
                        child: IdeIcon(editor: editor, size: 22),
                      ),
                    ),

                  if (editors.isNotEmpty && desktopApps.isNotEmpty) _divider(p),

                  // Installed Developer GUI Desktop Applications
                  for (final app in desktopApps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _RailIconButton(
                        tooltip: '${app.name}\n${app.category}\nClick to launch application',
                        onClick: () => DesktopAppService.launchApp(app),
                        child: _desktopAppIcon(app, p),
                      ),
                    ),

                  if (state.pinnedApps.isNotEmpty &&
                      (editors.isNotEmpty || desktopApps.isNotEmpty))
                    _divider(p),

                  // Apps the user pinned manually with the + button
                  for (final app in state.pinnedApps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Builder(
                        builder: (ctx) => _RailIconButton(
                          tooltip: '${app.name}\n${app.path}\nRight-click to unpin',
                          onClick: () => DesktopAppService.launchPath(app.path),
                          onSecondaryClick: (pos) => ContextMenu.show(ctx, pos, [
                            ContextMenuItem(
                              label: 'Open ${app.name}',
                              icon: AppIcons.play,
                              action: () => DesktopAppService.launchPath(app.path),
                            ),
                            ContextMenuItem(
                              label: Platform.revealLabel,
                              icon: AppIcons.folder,
                              action: () => Platform.reveal(app.path),
                            ),
                            const ContextMenuItem(label: ''),
                            ContextMenuItem(
                              label: 'Unpin from rail',
                              icon: AppIcons.close,
                              danger: true,
                              action: () => state.unpinApp(app.path),
                            ),
                          ]),
                          child: _pinnedIcon(app, p),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          _divider(p),

          // 3. Pin more apps
          Builder(
            builder: (btnCtx) => _RailIconButton(
              tooltip: 'Pin an app to the rail',
              onClick: () => state.modal = const ModalPinApp(),
              onSecondaryClick: (pos) => ContextMenu.show(btnCtx, pos, [
                ContextMenuItem(
                  label: 'Pin Application…',
                  icon: AppIcons.add,
                  action: () => state.modal = const ModalPinApp(),
                ),
                ContextMenuItem(
                  label: 'Browse from Disk…',
                  icon: AppIcons.folder,
                  action: () async {
                    final path = await Platform.pickApplication('Choose an application to pin');
                    if (path != null && path.isNotEmpty) await state.pinApp(path);
                  },
                ),
                const ContextMenuItem(label: ''),
                ContextMenuItem(
                  label: 'Rescan Applications',
                  icon: AppIcons.refresh,
                  action: () => state.refreshDetectedTools(),
                ),
              ]),
              child: Icon(AppIcons.add, size: 17, color: p.muted),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pinnedIcon(PinnedApp app, Pal p) {
    final file = AppIconService.getIconFileForApp(app);
    final fallback = Icon(Icons.apps_rounded, size: 18, color: p.accent);
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return fallback;
  }

  Widget _terminalIcon(Pal p) {
    final file = AppIconService.getIconFile('terminal');
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            Icon(AppIcons.terminal, size: 16, color: p.accent),
      );
    }
    return Icon(AppIcons.terminal, size: 16, color: p.accent);
  }

  Widget _desktopAppIcon(DesktopApp app, Pal p) {
    final file = app.iconPath != null
        ? io.File(app.iconPath!)
        : AppIconService.getIconFile(app.id);

    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => app.iconBuilder(p),
      );
    }
    return app.iconBuilder(p);
  }

  Widget _divider(Pal p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      height: 1,
      color: p.border,
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.child,
    required this.tooltip,
    required this.onClick,
    this.onSecondaryClick,
  });

  final Widget child;
  final String tooltip;
  final VoidCallback onClick;
  final ValueChanged<Offset>? onSecondaryClick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: onClick,
      builder: (context, hovered) {
        final btn = Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovered
                  ? (p.dark ? const Color(0xFF2C3038) : const Color(0xFFE2E5EA))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hovered ? p.accent.withOpacity(0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: child,
          ),
        );
        if (onSecondaryClick == null) return btn;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (d) => onSecondaryClick!(d.globalPosition),
          child: btn,
        );
      },
    );
  }
}
