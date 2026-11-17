import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';

class AppTopBar extends StatefulWidget {
  const AppTopBar({super.key, required this.state});
  final AppState state;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.state.uiState.searchQuery);
  }

  @override
  void didUpdateWidget(AppTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.uiState.searchQuery != _searchCtrl.text) {
      _searchCtrl.text = widget.state.uiState.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final state = widget.state;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(bottom: BorderSide(color: p.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. App Branding (Icon + Name)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: p.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(AppIcons.radar, size: 15, color: p.accent),
            ),
          ),
          const SizedBox(width: 10),
          const T(AppConfig.NAME, size: 14, weight: FontWeight.w700),
          const Spacer(),
          // 2. Compact Search Box at the end
          SizedBox(
            width: 230,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.border, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(AppIcons.search, size: 14, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -2.0),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) {
                            state.updateUiState(
                              (s) => s.copyWith(searchQuery: val),
                            );
                          },
                          maxLines: 1,
                          cursorHeight: 15,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 12.5,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Search projects…',
                            hintStyle: TextStyle(
                              color: p.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconBtn(
                      icon: AppIcons.close,
                      size: 20,
                      iconSize: 11,
                      onClick: () {
                        _searchCtrl.clear();
                        state.updateUiState(
                          (s) => s.copyWith(searchQuery: ''),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort Options Dropdown (when viewing project catalog)
          if (state.uiState.activeTab == 'projects') ...[
            Builder(
              builder: (btnCtx) => Btn(
                icon: Icons.swap_vert_rounded,
                label: state.uiState.sortBy.label,
                height: 34,
                outlined: true,
                fontSize: 12,
                onClick: () {
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                    ContextMenu.show(context, pos, [
                      for (final opt in ProjectSortOption.values)
                        ContextMenuItem(
                          label: opt.label,
                          icon: opt.icon,
                          leading: opt == state.uiState.sortBy
                              ? Icon(Icons.check_rounded, size: 14, color: p.accent)
                              : const SizedBox(width: 14),
                          action: () {
                            state.updateUiState((s) => s.copyWith(sortBy: opt));
                          },
                        ),
                    ]);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 3. Refresh Git Status button
          IconBtn(
            icon: AppIcons.refresh,
            tooltip: 'Refresh all Git repositories',
            size: 34,
            iconSize: 15,
            onClick: () => state.refreshAllGit(),
          ),
          const SizedBox(width: 8),
          // 4. Toggle Notes Side Pane
          IconBtn(
            icon: AppIcons.note,
            tooltip: state.uiState.notesPaneVisible
                ? 'Hide Notes Pane'
                : 'Show Notes Pane',
            size: 34,
            iconSize: 15,
            active: state.uiState.notesPaneVisible,
            onClick: () => state.toggleNotesPane(),
          ),
          const SizedBox(width: 8),
          // 5. Command Palette Trigger Button (Cmd + K)
          Btn(
            label: '⌘K',
            height: 34,
            onClick: () => state.paletteOpen = true,
          ),
        ],
      ),
    );
  }
}
