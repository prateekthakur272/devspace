import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/drag_devices.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/features/catalog/catalog_view.dart';
import 'package:devspace/features/catalog/sidebar.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/features/git_radar/git_radar_view.dart';
import 'package:devspace/features/notes/notes_pane.dart';
import 'package:devspace/features/shell/palette.dart';
import 'package:devspace/features/shell/status_bar.dart';
import 'package:devspace/features/shell/top_bar.dart';
import 'package:devspace/features/shell/window_chrome.dart';
import 'package:devspace/theme/theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.state,
    required this.chrome,
  });

  final AppState state;
  final WindowChrome chrome;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final p = context.pal;
        final ui = state.uiState;

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Plain Custom Desktop Titlebar like OpenRest
                chrome.dragArea(
                  GestureDetector(
                    onDoubleTap: chrome.onDoubleClick,
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: p.panel,
                        border: Border(bottom: BorderSide(color: p.border, width: 1)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: [
                                if (chrome.leftInset > 0)
                                  SizedBox(width: chrome.leftInset),
                                const Spacer(),
                                if (chrome.controls != null) chrome.controls!,
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: T(
                                  ui.activeTab == 'git_radar'
                                      ? 'Combined Git Radar'
                                      : 'Workspace Catalog',
                                  size: 11.5,
                                  color: p.muted,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Merged Unified Header (Branding + Search + Controls)
                AppTopBar(state: state),
                // Workspace body with left sidebar, main content, and right notes pane
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Sidebar
                      if (ui.sidebarVisible) ...[
                        SizedBox(
                          width: ui.sidebarWidth.clamp(200.0, 380.0),
                          child: WorkspaceSidebar(state: state),
                        ),
                        _PaneDivider(
                          color: p.border,
                          onDrag: (delta) {
                            state.updateUiState(
                              (s) => s.copyWith(
                                sidebarWidth: (s.sidebarWidth + delta).clamp(200.0, 380.0),
                              ),
                            );
                          },
                        ),
                      ],
                      // Main Content Area
                      Expanded(
                        child: ui.activeTab == 'git_radar'
                            ? GitRadarView(state: state)
                            : CatalogView(state: state),
                      ),
                      // Right Notes Side Pane
                      if (ui.notesPaneVisible) ...[
                        _PaneDivider(
                          color: p.border,
                          onDrag: (delta) {
                            state.setNotesPaneWidth(
                              (ui.notesPaneWidth - delta).clamp(260.0, 520.0),
                            );
                          },
                        ),
                        SizedBox(
                          width: ui.notesPaneWidth.clamp(260.0, 520.0),
                          child: NotesPane(state: state),
                        ),
                      ],
                    ],
                  ),
                ),
                // Bottom Desktop Status Bar (like open_rest)
                StatusBar(state: state),
              ],
            ),
            // Command Palette Overlay
            if (state.paletteOpen)
              Positioned.fill(
                child: CommandPalette(state: state),
              ),
            // Modal Overlay
            if (state.modal != null)
              Positioned.fill(
                child: buildActiveModal(context, state),
              ),
            // Toast Notification
            if (state.toast != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: p.dark
                            ? const Color(0xFF3A3F47)
                            : const Color(0xFF1F2328),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: T(
                        state.toast!,
                        color: const Color(0xFFFFFFFF),
                        size: 12,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaneDivider extends StatelessWidget {
  const _PaneDivider({required this.color, required this.onDrag});
  final Color color;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: kDragDevices,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Container(
          width: 5,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
