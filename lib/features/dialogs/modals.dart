import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';
import 'package:devspace/features/dialogs/developer_dialog.dart';
import 'package:devspace/features/dialogs/onboarding_dialog.dart';
import 'package:devspace/features/notes/note_dialog.dart';
import 'package:devspace/features/shell/menus.dart' show checkForUpdates;
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';
import 'package:devspace/utils/app_metadata.dart';
import 'package:devspace/utils/paths.dart';
import 'package:devspace/utils/update_checker.dart';

Widget buildActiveModal(BuildContext context, AppState state) {
  final modal = state.modal;
  if (modal == null) return const SizedBox.shrink();

  return ClickableNoRipple(
    onClick: () => state.modal = null,
    child: Container(
      color: Colors.black.withOpacity(0.5),
      child: switch (modal) {
        ModalAddProject(:final initialWorkspaceId, :final initialPath) =>
          _AddProjectDialog(
            state: state,
            initialWorkspaceId: initialWorkspaceId,
            initialPath: initialPath,
          ),
        ModalEditProject(:final project) =>
          _EditProjectDialog(state: state, project: project),
        ModalSettings() => _SettingsDialog(state: state),
        ModalAbout() => _AboutDialog(state: state),
        ModalDeveloper() => DeveloperDialog(state: state),
        ModalUpdateAvailable(:final version) =>
          _UpdateAvailableDialog(state: state, version: version),
        ModalConfirmDelete(:final project) =>
          _ConfirmDeleteDialog(state: state, project: project),
        ModalGitDetails(:final project, :final status) =>
          _GitDetailsDialog(state: state, project: project, status: status),
        ModalDetectedTools() => _DetectedToolsDialog(state: state),
        ModalPinApp() => _PinAppDialog(state: state),
        ModalCreateGroup() => _CreateGroupDialog(state: state),
        ModalEditGroup(:final group) => _EditGroupDialog(state: state, group: group),
        ModalCreateNote(:final initialProjectId, :final initialTag) =>
          NoteDialog(
            state: state,
            initialProjectId: initialProjectId,
            initialTag: initialTag,
          ),
        ModalEditNote(:final note) =>
          NoteDialog(state: state, existingNote: note),
        ModalOnboarding() =>
          OnboardingDialog(state: state),
      },
    ),
  );
}

class _AddProjectDialog extends StatefulWidget {
  const _AddProjectDialog({
    required this.state,
    this.initialWorkspaceId,
    this.initialPath,
  });
  final AppState state;
  final String? initialWorkspaceId;
  final String? initialPath;

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  final TextEditingController _pathCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController();
  EditorType _editor = EditorType.vscode;
  String _workspace = 'default';

  @override
  void initState() {
    super.initState();
    _editor = widget.state.settings.defaultEditor;
    if (widget.initialWorkspaceId != null) {
      _workspace = widget.initialWorkspaceId!;
    }
    if (widget.initialPath != null) {
      _pathCtrl.text = widget.initialPath!;
      _nameCtrl.text = widget.initialPath!
          .split(RegExp(r'[\\/]'))
          .lastWhere((e) => e.isNotEmpty, orElse: () => '');
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _nameCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final picked = await Platform.pickDirectory('Select Project Directory');
    if (picked != null) {
      setState(() {
        _pathCtrl.text = picked;
        if (_nameCtrl.text.isEmpty) {
          _nameCtrl.text = picked.split(RegExp(r'[\\/]')).lastWhere((e) => e.isNotEmpty, orElse: () => '');
        }
      });
    }
  }

  void _submit() {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return;

    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    widget.state.addProject(
      path: path,
      name: _nameCtrl.text.trim(),
      defaultEditor: _editor,
      workspaceId: _workspace,
      tags: tags,
    );
    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'Add Project to DevSpace',
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(label: 'Cancel', onClick: () => widget.state.modal = null),
        Btn(
          label: 'Add Project',
          primary: true,
          onClick: _pathCtrl.text.trim().isNotEmpty ? _submit : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Project Folder Path', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ModalTextField(
                  controller: _pathCtrl,
                  hint: '/path/to/your/repository',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Btn(
                label: 'Browse…',
                icon: AppIcons.folder,
                onClick: _pickFolder,
              ),
            ],
          ),
          const SizedBox(height: 14),
          T('Display Name', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(
            controller: _nameCtrl,
            hint: 'e.g. devspace, my-api',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Default Editor', size: 12, weight: FontWeight.w600, color: p.muted),
                    const SizedBox(height: 6),
                    _DropdownField<EditorType>(
                      value: _editor,
                      items: [
                        for (final e in {
                          ...widget.state.availableEditors,
                          _editor,
                        })
                          if (e != EditorType.custom)
                            DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  IdeIcon(editor: e, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(child: T(e.label, size: 12.5)),
                                  if (widget.state.availableEditors.contains(e))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: p.ok.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: T('Detected', size: 9.5, color: p.ok, weight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _editor = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Workspace Group', size: 12, weight: FontWeight.w600, color: p.muted),
                    const SizedBox(height: 6),
                    _DropdownField<String>(
                      value: _workspace,
                      items: [
                        for (final ws in widget.state.workspaces)
                          DropdownMenuItem(value: ws.id, child: T(ws.name, size: 12.5)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _workspace = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          T('Tags (comma separated)', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(
            controller: _tagsCtrl,
            hint: 'e.g. backend, mobile, rust',
          ),
        ],
      ),
    );
  }
}

class _EditProjectDialog extends StatefulWidget {
  const _EditProjectDialog({required this.state, required this.project});
  final AppState state;
  final Project project;

  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _customCmdCtrl;
  late EditorType _editor;
  late String _workspace;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _tagsCtrl = TextEditingController(text: widget.project.tags.join(', '));
    _customCmdCtrl = TextEditingController(text: widget.project.customEditorCommand ?? '');
    _editor = widget.project.defaultEditor;
    _workspace = widget.project.workspaceId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagsCtrl.dispose();
    _customCmdCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final updated = widget.project.copyWith(
      name: _nameCtrl.text.trim(),
      defaultEditor: _editor,
      customEditorCommand: _customCmdCtrl.text.trim().isNotEmpty
          ? _customCmdCtrl.text.trim()
          : null,
      workspaceId: _workspace,
      tags: tags,
    );
    widget.state.updateProject(updated);
    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'Edit Project: ${widget.project.name}',
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(label: 'Cancel', onClick: () => widget.state.modal = null),
        Btn(label: 'Save Changes', primary: true, onClick: _save),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Project Path', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 4),
          MonoText(widget.project.path, size: 12),
          const SizedBox(height: 14),
          T('Display Name', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(controller: _nameCtrl, hint: 'Project name'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Default Editor', size: 12, weight: FontWeight.w600, color: p.muted),
                    const SizedBox(height: 6),
                    _DropdownField<EditorType>(
                      value: _editor,
                      items: [
                        for (final e in {
                          ...widget.state.availableEditors,
                          _editor,
                        })
                          if (e != EditorType.custom)
                            DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  IdeIcon(editor: e, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(child: T(e.label, size: 12.5)),
                                  if (widget.state.availableEditors.contains(e))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: p.ok.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: T('Detected', size: 9.5, color: p.ok, weight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _editor = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Workspace Group', size: 12, weight: FontWeight.w600, color: p.muted),
                    const SizedBox(height: 6),
                    _DropdownField<String>(
                      value: _workspace,
                      items: [
                        for (final ws in widget.state.workspaces)
                          DropdownMenuItem(value: ws.id, child: T(ws.name, size: 12.5)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _workspace = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          T('Custom Launch Command (optional)', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(controller: _customCmdCtrl, hint: 'e.g. nvim, code -n'),
          const SizedBox(height: 14),
          T('Tags (comma separated)', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(controller: _tagsCtrl, hint: 'e.g. flutter, tools'),
        ],
      ),
    );
  }
}

enum _SettingsCategory {
  general('General', Icons.tune_rounded),
  editors('Editors & Tools', Icons.code_rounded),
  git('Git & Radar', AppIcons.branch),
  storage('Storage & Data', AppIcons.folder);

  const _SettingsCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.state});
  final AppState state;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  _SettingsCategory _category = _SettingsCategory.general;

  void _updateSettings(AppSettings Function(AppSettings current) updater) {
    final next = updater(widget.state.settings);
    widget.state.updateSettings(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = widget.state.settings;

    return ModalScaffold(
      title: 'Preferences',
      width: 660,
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(
          label: 'Done',
          primary: true,
          height: 32,
          onClick: () => widget.state.modal = null,
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Category Segmented Pills Bar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border, width: 1),
              ),
              child: Row(
                children: [
                  for (final cat in _SettingsCategory.values)
                    Expanded(
                      child: ClickableNoRipple(
                        onClick: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _category == cat ? p.panel : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _category == cat ? p.border : Colors.transparent,
                              width: 1,
                            ),
                            boxShadow: _category == cat
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(p.dark ? 0.3 : 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.icon,
                                size: 13,
                                color: _category == cat ? p.accent : p.muted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: T(
                                  cat.label,
                                  size: 11.5,
                                  weight: _category == cat ? FontWeight.w600 : FontWeight.w500,
                                  color: _category == cat ? p.text : p.muted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Active Category Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: switch (_category) {
                  _SettingsCategory.general => _buildGeneralTab(context, p, settings),
                  _SettingsCategory.editors => _buildEditorsTab(context, p, settings),
                  _SettingsCategory.git => _buildGitTab(context, p, settings),
                  _SettingsCategory.storage => _buildStorageTab(context, p),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: GENERAL & THEME ---
  Widget _buildGeneralTab(BuildContext context, Pal p, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Theme Selection Header
        const T('Appearance & Theme', size: 12.5, weight: FontWeight.w700),
        const SizedBox(height: 4),
        T(
          'Choose your preferred desktop interface theme mode.',
          size: 11.5,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        // 3 Visual Theme Selector Cards
        Row(
          children: [
            _buildThemeCard(
              p: p,
              title: 'System',
              subtitle: 'Match OS look',
              icon: Icons.brightness_auto_rounded,
              mode: ThemeMode.system,
              selected: settings.themeMode == ThemeMode.system,
            ),
            const SizedBox(width: 10),
            _buildThemeCard(
              p: p,
              title: 'Dark',
              subtitle: 'Charcoal palette',
              icon: Icons.dark_mode_rounded,
              mode: ThemeMode.dark,
              selected: settings.themeMode == ThemeMode.dark,
            ),
            const SizedBox(width: 10),
            _buildThemeCard(
              p: p,
              title: 'Light',
              subtitle: 'Daylight palette',
              icon: Icons.light_mode_rounded,
              mode: ThemeMode.light,
              selected: settings.themeMode == ThemeMode.light,
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Auto-Discovery Switch Tile
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.radar_rounded, size: 16, color: p.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Automatic Project Discovery', size: 12.5, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Periodically scan workspace root paths to discover newly cloned Git repositories.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: settings.autoDetectProjects,
                activeColor: p.accent,
                onChanged: (val) {
                  _updateSettings((s) => s.copyWith(autoDetectProjects: val));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tools & IDEs Quick Launch Rail Switch Tile
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(AppIcons.terminal, size: 16, color: p.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Tools & IDEs Quick Launch Rail', size: 12.5, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Display a vertical launcher toolbar at the right edge after the notes pane to directly open installed IDEs and terminal tools.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: settings.showToolsRail,
                activeColor: p.accent,
                onChanged: (val) {
                  _updateSettings((s) => s.copyWith(showToolsRail: val));
                },
              ),
            ],
          ),
        ),
        if (settings.showToolsRail) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T('Pinned Toolbar Applications (${widget.state.pinnedApps.length})',
                          size: 12, weight: FontWeight.w600),
                      const SizedBox(height: 2),
                      T(
                        widget.state.pinnedApps.isEmpty
                            ? 'Pin any custom application or utility to the quick-launch rail.'
                            : widget.state.pinnedApps.map((a) => a.name).join(', '),
                        size: 11,
                        color: p.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Btn(
                  label: 'Pin Apps…',
                  icon: AppIcons.add,
                  height: 28,
                  fontSize: 11.5,
                  onClick: () => widget.state.modal = const ModalPinApp(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Open at Login Switch Tile
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.login_rounded, size: 16, color: p.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Open at Login', size: 12.5, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Automatically launch DevSpace when you start or log in to your computer.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: settings.openAtLogin,
                activeColor: p.accent,
                onChanged: (val) {
                  _updateSettings((s) => s.copyWith(openAtLogin: val));
                  widget.state.setOpenAtLogin(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // App Info & Version Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/header_logo.png',
                width: 28,
                height: 28,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const T(AppConfig.NAME, size: 13, weight: FontWeight.w700),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: T(
                            'v${AppMetadata.version}',
                            size: 10,
                            weight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    T(
                      'Cross-platform desktop command center for local developers.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Btn(
                label: 'Welcome Tour…',
                icon: Icons.explore_outlined,
                height: 30,
                fontSize: 11.5,
                onClick: () => widget.state.modal = const ModalOnboarding(),
              ),
              const SizedBox(width: 8),
              Btn(
                label: 'Check for Updates…',
                icon: Icons.update_rounded,
                height: 30,
                fontSize: 11.5,
                onClick: () => checkForUpdates(widget.state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required Pal p,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
  }) {
    return Expanded(
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        onTap: () => _updateSettings((s) => s.copyWith(themeMode: mode)),
        builder: (context, hovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? p.accent.withOpacity(0.12)
                  : hovered
                      ? p.hover
                      : p.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? p.accent
                    : hovered
                        ? p.accent.withOpacity(0.4)
                        : p.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? p.accent : p.muted,
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle_rounded, size: 15, color: p.accent),
                  ],
                ),
                const SizedBox(height: 10),
                T(
                  title,
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: selected ? p.accent : p.text,
                ),
                const SizedBox(height: 2),
                T(subtitle, size: 10.5, color: p.muted),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: EDITORS & TOOLS ---
  Widget _buildEditorsTab(BuildContext context, Pal p, AppSettings settings) {
    final available = widget.state.availableEditors;
    final allEditors = {
      ...available,
      settings.defaultEditor,
      EditorType.vscode,
      EditorType.cursor,
      EditorType.androidStudio,
      EditorType.intellij,
      EditorType.xcode,
    }.where((e) => e != EditorType.custom).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tools & IDEs Quick Launch Rail Switch Tile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(AppIcons.terminal, size: 16, color: p.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Tools & IDEs Quick Launch Rail', size: 12.5, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Vertical launcher toolbar at the right end of the workspace to directly open installed editors and CLI tools.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: settings.showToolsRail,
                activeColor: p.accent,
                onChanged: (val) {
                  _updateSettings((s) => s.copyWith(showToolsRail: val));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Default Terminal Selection
        const T('Default Terminal', size: 12.5, weight: FontWeight.w700),
        const SizedBox(height: 4),
        T(
          'Choose whether terminal actions and project shortcuts open in the integrated panel or an external system terminal.',
          size: 11.5,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // 1. Integrated Terminal
            Expanded(
              child: HoverBuilder(
                cursor: SystemMouseCursors.click,
                onTap: () => _updateSettings((s) => s.copyWith(defaultTerminal: DefaultTerminalType.integrated)),
                builder: (context, hovered) {
                  final isSelected = settings.defaultTerminal == DefaultTerminalType.integrated;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? p.accent.withOpacity(0.12)
                          : hovered
                              ? p.hover
                              : p.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? p.accent
                            : hovered
                                ? p.accent.withOpacity(0.4)
                                : p.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.terminal, size: 18, color: isSelected ? p.accent : p.muted),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, size: 15, color: p.accent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        T(
                          'Integrated Terminal',
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: isSelected ? p.accent : p.text,
                        ),
                        const SizedBox(height: 2),
                        T(
                          'DevSpace built-in bottom panel with tabs, ANSI styling & command suggestions',
                          size: 10.5,
                          color: p.muted,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),

            // 2. System Terminal
            Expanded(
              child: HoverBuilder(
                cursor: SystemMouseCursors.click,
                onTap: () => _updateSettings((s) => s.copyWith(defaultTerminal: DefaultTerminalType.system)),
                builder: (context, hovered) {
                  final isSelected = settings.defaultTerminal == DefaultTerminalType.system;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? p.accent.withOpacity(0.12)
                          : hovered
                              ? p.hover
                              : p.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? p.accent
                            : hovered
                                ? p.accent.withOpacity(0.4)
                                : p.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 18, color: isSelected ? p.accent : p.muted),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, size: 15, color: p.accent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        T(
                          'System Terminal',
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: isSelected ? p.accent : p.text,
                        ),
                        const SizedBox(height: 2),
                        T(
                          Platform.isMac
                              ? 'Native macOS Terminal, iTerm2, Warp, or Ghostty application'
                              : (Platform.isWindows
                                  ? 'Native Windows Terminal, PowerShell, or cmd.exe'
                                  : 'Native Linux desktop terminal emulator'),
                          size: 10.5,
                          color: p.muted,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        const T('Default Code Editor', size: 12.5, weight: FontWeight.w700),
        const SizedBox(height: 4),
        T(
          'Double-clicking project cards and project actions open in this editor.',
          size: 11.5,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        // Grid of IDE selector cards
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final editor in allEditors) ...[
              SizedBox(
                width: 300,
                child: HoverBuilder(
                  cursor: SystemMouseCursors.click,
                  onTap: () => _updateSettings((s) => s.copyWith(defaultEditor: editor)),
                  builder: (context, hovered) {
                    final isSelected = settings.defaultEditor == editor;
                    final isDetected = available.contains(editor);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? p.accent.withOpacity(0.12)
                            : hovered
                                ? p.hover
                                : p.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? p.accent
                              : hovered
                                  ? p.accent.withOpacity(0.4)
                                  : p.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          IdeIcon(editor: editor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                T(
                                  editor.label,
                                  size: 12,
                                  weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? p.accent : p.text,
                                ),
                                T(
                                  isDetected ? 'Installed & ready' : 'Not installed',
                                  size: 10,
                                  color: isDetected ? p.ok : p.muted,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const T(
                                'Default',
                                size: 9.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        // Detected Developer Tools & CLI SDKs
        Row(
          children: [
            const T('Detected CLI Tools & SDKs', size: 12.5, weight: FontWeight.w700),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: p.ok.withOpacity(0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: T(
                '${widget.state.detectedTools.length} found',
                size: 10,
                weight: FontWeight.w700,
                color: p.ok,
              ),
            ),
            const Spacer(),
            Btn(
              label: widget.state.toolsScanning ? 'Scanning…' : 'Re-scan System',
              icon: AppIcons.refresh,
              height: 26,
              fontSize: 11,
              onClick: widget.state.toolsScanning ? null : () => widget.state.refreshDetectedTools(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: widget.state.toolsScanning
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : widget.state.detectedTools.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: T('No developer CLI tools detected yet', size: 12, color: p.muted),
                      ),
                    )
                  : Column(
                      children: [
                        for (final tool in widget.state.detectedTools) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: p.ok,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                T(tool.name, size: 12, weight: FontWeight.w600),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: p.panel,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: p.border, width: 0.5),
                                  ),
                                  child: MonoText(
                                    tool.version,
                                    size: 10.5,
                                    color: p.text.withOpacity(0.85),
                                  ),
                                ),
                                const Spacer(),
                                T(tool.category, size: 10.5, color: p.muted),
                              ],
                            ),
                          ),
                          if (tool != widget.state.detectedTools.last)
                            Divider(height: 4, color: p.border.withOpacity(0.5)),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  // --- TAB 3: GIT & RADAR ---
  Widget _buildGitTab(BuildContext context, Pal p, AppSettings settings) {
    const intervals = [
      (0, 'None', 'Disable background polling; refresh on-demand only'),
      (15, '15 seconds', 'High frequency / active coding'),
      (30, '30 seconds', 'Recommended standard'),
      (60, '1 minute', 'Balanced performance'),
      (120, '2 minutes', 'Low battery impact'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const T('Git Radar Background Polling', size: 12.5, weight: FontWeight.w700),
        const SizedBox(height: 4),
        T(
          'Background frequency for checking git status, uncommitted changes, and remote sync.',
          size: 11.5,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        // Interval Cards
        for (final item in intervals) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: HoverBuilder(
              cursor: SystemMouseCursors.click,
              onTap: () => _updateSettings((s) => s.copyWith(gitRefreshIntervalSeconds: item.$1)),
              builder: (context, hovered) {
                final isSelected = settings.gitRefreshIntervalSeconds == item.$1;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? p.accent.withOpacity(0.12)
                        : hovered
                            ? p.hover
                            : p.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? p.accent
                          : hovered
                              ? p.accent.withOpacity(0.4)
                              : p.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 16,
                        color: isSelected ? p.accent : p.muted,
                      ),
                      const SizedBox(width: 10),
                      T(
                        item.$2,
                        size: 12,
                        weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? p.accent : p.text,
                      ),
                      const Spacer(),
                      Flexible(
                        child: T(
                          item.$3,
                          size: 10.5,
                          color: p.muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          align: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Live Radar Actions Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(AppIcons.refresh, size: 16, color: p.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(
                      'Monitored Repositories: ${widget.state.projects.length}',
                      size: 12.5,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 2),
                    T(
                      'Immediately query git status for all projects in the catalog.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              Btn(
                label: 'Refresh All Now',
                icon: AppIcons.refresh,
                height: 30,
                onClick: () {
                  widget.state.refreshAllGit();
                  widget.state.showToast('Refreshing all Git repositories…');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 4: STORAGE & DATA ---
  Widget _buildStorageTab(BuildContext context, Pal p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const T('File Storage & Workspace Data', size: 12.5, weight: FontWeight.w700),
        const SizedBox(height: 4),
        T(
          'DevSpace persists projects, developer notes, and preferences into dedicated files.',
          size: 11.5,
          color: p.muted,
        ),
        const SizedBox(height: 12),

        // 1. Projects Folder
        _buildStorageCard(
          p: p,
          title: 'Projects Directory',
          subtitle: 'Individual .json file for each cataloged project (${widget.state.projects.length} files)',
          path: AppStore.projectsDir,
          icon: AppIcons.project,
        ),
        const SizedBox(height: 8),

        // 2. Notes Folder
        _buildStorageCard(
          p: p,
          title: 'Notes & Scratchpads Directory',
          subtitle: 'Individual .json file for each note and checklist (${widget.state.notes.length} files)',
          path: AppStore.notesDir,
          icon: AppIcons.note,
        ),
        const SizedBox(height: 8),

        // 3. Diagnostic Log File
        _buildStorageCard(
          p: p,
          title: 'Rotating Diagnostic Log',
          subtitle: 'Rotating developer log file capped at 1 MB (.old backup preserved)',
          path: Paths.logFile(AppStore.dir),
          icon: Icons.description_outlined,
          isFile: true,
        ),
        const SizedBox(height: 8),

        // 4. Master App Directory
        _buildStorageCard(
          p: p,
          title: 'Master DevSpace Storage Folder',
          subtitle: 'Contains settings.json, workspaces.json, state.json, and data subfolders',
          path: AppStore.dir,
          icon: AppIcons.folder,
        ),
      ],
    );
  }

  Widget _buildStorageCard({
    required Pal p,
    required String title,
    required String subtitle,
    required String path,
    required IconData icon,
    bool isFile = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: p.accent),
              const SizedBox(width: 8),
              T(title, size: 12.5, weight: FontWeight.w600),
              const Spacer(),
              IconBtn(
                icon: AppIcons.copy,
                tooltip: 'Copy path',
                size: 24,
                iconSize: 12,
                onClick: () {
                  Platform.copy(path);
                  widget.state.showToast('Copied path to clipboard');
                },
              ),
              const SizedBox(width: 4),
              Btn(
                label: Platform.revealLabel,
                icon: AppIcons.folder,
                height: 26,
                fontSize: 11,
                onClick: () => Platform.reveal(path),
              ),
            ],
          ),
          const SizedBox(height: 4),
          T(subtitle, size: 11, color: p.muted),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: p.border.withOpacity(0.5), width: 0.5),
            ),
            child: MonoText(path, size: 10.5, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'About ${AppConfig.NAME}',
      width: 440,
      onClose: () => state.modal = null,
      actions: [
        Btn(
          label: 'Check for Updates…',
          onClick: () {
            state.modal = null;
            checkForUpdates(state);
          },
        ),
        Btn(label: 'Close', primary: true, onClick: () => state.modal = null),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 64,
            height: 64,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 12),
          T(AppConfig.NAME, size: 18, weight: FontWeight.w700),
          const SizedBox(height: 4),
          T('Version ${AppMetadata.version} (${AppMetadata.buildNumber})', size: 12, color: p.muted),
          const SizedBox(height: 12),
          T(
            'A unified desktop workspace for developers to view, track, and open all their projects at once.',
            size: 12.5,
            color: p.text,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 16),
          T(AppConfig.COPYRIGHT, size: 11, color: p.muted),
        ],
      ),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({
    required this.state,
    required this.version,
  });

  final AppState state;
  final String version;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'Update Available',
      width: 440,
      onClose: _dismiss,
      actions: [
        Btn(label: 'Later', onClick: _dismiss),
        Btn(
          label: 'Download $version',
          primary: true,
          onClick: () {
            state.modal = null;
            state.availableUpdate = null;
            unawaited(Platform.openUrl(AppConfig.RELEASES_URL));
          },
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.download, size: 24, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(
                  'Version $version is now available',
                  size: 14,
                  weight: FontWeight.w600,
                ),
                const SizedBox(height: 6),
                T(
                  'You are running ${AppMetadata.version}. '
                  'Visit the GitHub releases page to download the latest build.',
                  color: p.muted,
                  size: 12,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _dismiss() {
    state.modal = null;
    unawaited(UpdateChecker.dismissVersion(version));
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.state, required this.project});
  final AppState state;
  final Project project;

  @override
  Widget build(BuildContext context) {
    return ModalScaffold(
      title: 'Remove Project?',
      width: 440,
      onClose: () => state.modal = null,
      actions: [
        Btn(label: 'Cancel', onClick: () => state.modal = null),
        Btn(
          label: 'Remove',
          danger: true,
          primary: true,
          onClick: () {
            state.removeProject(project.id);
            state.modal = null;
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('Are you sure you want to remove "${project.name}" from DevSpace?', size: 13, weight: FontWeight.w500),
          const SizedBox(height: 6),
          T(
            'This only unlinks the project from your workspace. No files on your disk will be deleted.',
            size: 12,
            color: context.pal.muted,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}

class _GitDetailsDialog extends StatefulWidget {
  const _GitDetailsDialog({
    required this.state,
    required this.project,
    required this.status,
  });

  final AppState state;
  final Project project;
  final GitRepoStatus status;

  @override
  State<_GitDetailsDialog> createState() => _GitDetailsDialogState();
}

class _GitDetailsDialogState extends State<_GitDetailsDialog> {
  bool _isFetching = false;
  bool _isPulling = false;

  GitRepoStatus get _status =>
      widget.state.gitStatusFor(widget.project.id) ?? widget.status;

  bool get _isLoading => widget.state.isGitLoading(widget.project.id);

  Future<void> _handleFetch() async {
    setState(() => _isFetching = true);
    final ok = await GitService.fetch(widget.project.path);
    await widget.state.refreshProjectGit(widget.project);
    if (!mounted) return;
    setState(() => _isFetching = false);
    widget.state.showToast(ok ? 'Git fetch completed successfully' : 'Git fetch failed');
  }

  Future<void> _handlePull() async {
    setState(() => _isPulling = true);
    final ok = await GitService.pull(widget.project.path);
    await widget.state.refreshProjectGit(widget.project);
    if (!mounted) return;
    setState(() => _isPulling = false);
    widget.state.showToast(
      ok ? 'Git pull completed successfully' : 'Git pull failed (check for conflicts)',
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final status = _status;

    return ModalScaffold(
      title: 'Git Health: ${widget.project.name}',
      width: 620,
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(
          icon: AppIcons.terminal,
          label: 'Terminal',
          height: 32,
          onClick: () => widget.state.openTerminal(widget.project.path, title: widget.project.name),
        ),
        Btn(
          icon: Icons.sync_alt_rounded,
          label: _isFetching ? 'Fetching…' : 'Fetch',
          height: 32,
          onClick: _isFetching || _isPulling ? null : _handleFetch,
        ),
        Btn(
          icon: Icons.arrow_downward_rounded,
          label: _isPulling ? 'Pulling…' : 'Pull',
          height: 32,
          onClick: _isFetching || _isPulling ? null : _handlePull,
        ),
        Btn(
          label: 'Close',
          primary: true,
          height: 32,
          onClick: () => widget.state.modal = null,
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Identity & Path Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TechBadge(
                          label: widget.project.techStack.label,
                          color: widget.project.techStack.color,
                          stack: widget.project.techStack,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Branch badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: p.accent.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: p.accent.withOpacity(0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.branch, size: 12, color: p.accent),
                                    const SizedBox(width: 4),
                                    T(
                                      status.branch.isNotEmpty ? status.branch : 'HEAD',
                                      size: 11.5,
                                      weight: FontWeight.w700,
                                      color: p.accent,
                                    ),
                                    if (status.upstream != null) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 10, color: p.accent),
                                      const SizedBox(width: 3),
                                      T(
                                        status.upstream!,
                                        size: 11,
                                        weight: FontWeight.w500,
                                        color: p.accent.withOpacity(0.85),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Tag badge if available
                              if (status.lastTag != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: p.panel,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: p.border, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sell_outlined, size: 11, color: p.muted),
                                      const SizedBox(width: 4),
                                      T(status.lastTag!, size: 11, weight: FontWeight.w600),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Refresh status button
                        Btn(
                          icon: AppIcons.refresh,
                          label: _isLoading ? 'Checking…' : 'Refresh',
                          height: 28,
                          fontSize: 11,
                          onClick: _isLoading ? null : () => widget.state.refreshProjectGit(widget.project),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Path row
                    Row(
                      children: [
                        Icon(AppIcons.folder, size: 12, color: p.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: MonoText(
                            widget.project.path,
                            size: 11,
                            color: p.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconBtn(
                          icon: AppIcons.copy,
                          tooltip: 'Copy path',
                          size: 24,
                          iconSize: 12,
                          onClick: () {
                            Platform.copy(widget.project.path);
                            widget.state.showToast('Copied path to clipboard');
                          },
                        ),
                        const SizedBox(width: 2),
                        IconBtn(
                          icon: AppIcons.external,
                          tooltip: Platform.revealLabel,
                          size: 24,
                          iconSize: 12,
                          onClick: () => Platform.reveal(widget.project.path),
                        ),
                      ],
                    ),
                    // Remote URL row
                    if (status.remoteUrl != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cloud_outlined, size: 12, color: p.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: MonoText(
                              status.remoteUrl!,
                              size: 11,
                              color: p.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconBtn(
                            icon: AppIcons.copy,
                            tooltip: 'Copy remote URL',
                            size: 24,
                            iconSize: 12,
                            onClick: () {
                              Platform.copy(status.remoteUrl!);
                              widget.state.showToast('Copied remote URL to clipboard');
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Health & Sync Hero Cards (Two Column Split)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Working Tree Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: status.isClean
                            ? p.ok.withOpacity(0.08)
                            : p.warn.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status.isClean
                              ? p.ok.withOpacity(0.3)
                              : p.warn.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: status.isClean
                                  ? p.ok.withOpacity(0.16)
                                  : p.warn.withOpacity(0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                status.isClean
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.error_outline_rounded,
                                size: 18,
                                color: status.isClean ? p.ok : p.warn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                T(
                                  status.isClean
                                      ? 'Working Tree Clean'
                                      : '${status.totalChanges} Uncommitted Changes',
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: status.isClean ? p.ok : p.warn,
                                ),
                                const SizedBox(height: 2),
                                T(
                                  status.isClean
                                      ? 'No pending modifications'
                                      : '${status.stagedCount} staged, ${status.modifiedCount} modified, ${status.untrackedCount} untracked',
                                  size: 11,
                                  color: p.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Remote Sync State Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: status.isSynced
                            ? p.ok.withOpacity(0.08)
                            : status.needsSync
                                ? (status.aheadCount > 0 && status.behindCount > 0
                                    ? p.warn.withOpacity(0.08)
                                    : status.behindCount > 0
                                        ? p.err.withOpacity(0.08)
                                        : p.accent.withOpacity(0.08))
                                : p.field,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status.isSynced
                              ? p.ok.withOpacity(0.3)
                              : status.needsSync
                                  ? (status.aheadCount > 0 && status.behindCount > 0
                                      ? p.warn.withOpacity(0.3)
                                      : status.behindCount > 0
                                          ? p.err.withOpacity(0.3)
                                          : p.accent.withOpacity(0.3))
                                  : p.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: status.isSynced
                                  ? p.ok.withOpacity(0.16)
                                  : status.needsSync
                                      ? (status.aheadCount > 0 && status.behindCount > 0
                                          ? p.warn.withOpacity(0.16)
                                          : status.behindCount > 0
                                              ? p.err.withOpacity(0.16)
                                              : p.accent.withOpacity(0.16))
                                      : p.panel,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                status.isSynced
                                    ? Icons.sync_rounded
                                    : status.aheadCount > 0 && status.behindCount > 0
                                        ? Icons.sync_problem_rounded
                                        : status.behindCount > 0
                                            ? Icons.arrow_downward_rounded
                                            : status.aheadCount > 0
                                                ? Icons.arrow_upward_rounded
                                                : Icons.cloud_off_outlined,
                                size: 18,
                                color: status.isSynced
                                    ? p.ok
                                    : status.aheadCount > 0 && status.behindCount > 0
                                        ? p.warn
                                        : status.behindCount > 0
                                            ? p.err
                                            : status.aheadCount > 0
                                                ? p.accent
                                                : p.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                T(
                                  status.isSynced
                                      ? 'Up to Date'
                                      : status.aheadCount > 0 && status.behindCount > 0
                                          ? 'Diverged from Upstream'
                                          : status.aheadCount > 0
                                              ? '${status.aheadCount} Commit${status.aheadCount > 1 ? "s" : ""} Ahead'
                                              : status.behindCount > 0
                                                  ? '${status.behindCount} Commit${status.behindCount > 1 ? "s" : ""} Behind'
                                                  : 'Local Branch Only',
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: status.isSynced
                                      ? p.ok
                                      : status.aheadCount > 0 && status.behindCount > 0
                                          ? p.warn
                                          : status.behindCount > 0
                                              ? p.err
                                              : status.aheadCount > 0
                                                  ? p.accent
                                                  : p.text,
                                ),
                                const SizedBox(height: 2),
                                T(
                                  status.isSynced
                                      ? 'Synchronized with ${status.upstream ?? "remote"}'
                                      : status.aheadCount > 0 && status.behindCount > 0
                                          ? '↑ ${status.aheadCount} to push, ↓ ${status.behindCount} to pull'
                                          : status.aheadCount > 0
                                              ? 'Ready to push to upstream'
                                              : status.behindCount > 0
                                                  ? 'Pull to update local branch'
                                                  : 'No remote tracking branch configured',
                                  size: 11,
                                  color: p.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Changes Breakdown Grid (Staged, Modified, Untracked)
              Row(
                children: [
                  // Staged card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status.stagedCount > 0 ? p.ok.withOpacity(0.35) : p.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              T(
                                '+${status.stagedCount}',
                                size: 18,
                                weight: FontWeight.w700,
                                color: status.stagedCount > 0 ? p.ok : p.muted,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 14,
                                color: status.stagedCount > 0 ? p.ok : p.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const T('Staged Files', size: 11.5, weight: FontWeight.w600),
                          T('Ready for commit', size: 10, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Modified card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status.modifiedCount > 0 ? p.warn.withOpacity(0.35) : p.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              T(
                                '~${status.modifiedCount}',
                                size: 18,
                                weight: FontWeight.w700,
                                color: status.modifiedCount > 0 ? p.warn : p.muted,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: status.modifiedCount > 0 ? p.warn : p.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const T('Modified Files', size: 11.5, weight: FontWeight.w600),
                          T('Unstaged edits', size: 10, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Untracked card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status.untrackedCount > 0 ? p.accent.withOpacity(0.35) : p.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              T(
                                '?${status.untrackedCount}',
                                size: 18,
                                weight: FontWeight.w700,
                                color: status.untrackedCount > 0 ? p.accent : p.muted,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.help_outline_rounded,
                                size: 14,
                                color: status.untrackedCount > 0 ? p.accent : p.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const T('Untracked Files', size: 11.5, weight: FontWeight.w600),
                          T('New files', size: 10, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Stash notice (if stash exists)
              if (status.hasStash) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.warn.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.warn.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14, color: p.warn),
                      const SizedBox(width: 8),
                      T(
                        'Git Stash contains saved modifications.',
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: p.warn,
                      ),
                      const Spacer(),
                      T(
                        'Run git stash pop in terminal to restore',
                        size: 10.5,
                        color: p.muted,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 4. Latest Commit Card
              if (status.lastCommitMessage != null || status.lastCommitHash != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.commit, size: 13, color: p.accent),
                          const SizedBox(width: 6),
                          const T('Latest Commit', size: 12, weight: FontWeight.w700),
                          const Spacer(),
                          if (status.lastCommitHash != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.panel,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: p.border, width: 1),
                              ),
                              child: MonoText(
                                status.lastCommitHash!,
                                size: 10.5,
                                color: p.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconBtn(
                              icon: AppIcons.copy,
                              tooltip: 'Copy commit hash',
                              size: 22,
                              iconSize: 11,
                              onClick: () {
                                Platform.copy(status.lastCommitHash!);
                                widget.state.showToast('Copied commit hash');
                              },
                            ),
                          ],
                        ],
                      ),
                      if (status.lastCommitMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: p.panel,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: p.border.withOpacity(0.6), width: 1),
                          ),
                          child: SelectableText(
                            status.lastCommitMessage!,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (status.lastCommitAuthor != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline_rounded, size: 12, color: p.muted),
                                const SizedBox(width: 4),
                                T(status.lastCommitAuthor!, size: 11, color: p.muted),
                              ],
                            ),
                          if (status.lastCommitDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: p.muted),
                                const SizedBox(width: 4),
                                T(
                                  '${_formatTimeAgo(status.lastCommitDate!)} (${status.lastCommitDate!.toString().substring(0, 16)})',
                                  size: 11,
                                  color: p.muted,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectedToolsDialog extends StatelessWidget {
  const _DetectedToolsDialog({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final editors = state.availableEditors;
    final tools = state.detectedTools;

    return ModalScaffold(
      title: 'Detected Tools & Environments',
      width: 580,
      onClose: () => state.modal = null,
      actions: [
        Btn(
          label: state.toolsScanning ? 'Scanning…' : 'Re-scan System',
          icon: AppIcons.refresh,
          onClick: state.toolsScanning ? null : () => state.refreshDetectedTools(),
        ),
        Btn(label: 'Close', primary: true, onClick: () => state.modal = null),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: state.toolsScanning ? p.accent : p.ok,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T(
                            state.toolsScanning
                                ? 'Scanning system for installed IDEs and developer CLI tools…'
                                : 'Detected ${editors.length} code editor${editors.length == 1 ? '' : 's'} and ${tools.length} developer tool${tools.length == 1 ? '' : 's'}.',
                            size: 12.5,
                            weight: FontWeight.w600,
                          ),
                          const SizedBox(height: 2),
                          T(
                            'DevSpace automatically configures "Open in..." actions and terminal shortcuts based on detected tools.',
                            size: 11.5,
                            color: p.muted,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Section 1: Detected IDEs & Editors
              Row(
                children: [
                  Icon(AppIcons.code, size: 14, color: p.accent),
                  const SizedBox(width: 6),
                  T('Installed IDEs & Editors (${editors.length})', size: 12.5, weight: FontWeight.w600),
                ],
              ),
              const SizedBox(height: 8),
              if (editors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.border, width: 1),
                  ),
                  child: Center(
                    child: T('No supported IDEs detected in standard paths', size: 12, color: p.muted),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final editor in editors)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: p.field,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: p.border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IdeIcon(editor: editor, size: 15),
                            const SizedBox(width: 8),
                            T(editor.label, size: 12, weight: FontWeight.w600),
                            if (editor == state.settings.defaultEditor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: p.accent.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: T('Default', size: 9, color: p.accent, weight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              // Section 2: Developer CLI Tools & SDKs
              Row(
                children: [
                  Icon(AppIcons.terminal, size: 14, color: p.accent),
                  const SizedBox(width: 6),
                  T('Developer CLI Tools & SDKs (${tools.length})', size: 12.5, weight: FontWeight.w600),
                ],
              ),
              const SizedBox(height: 8),
              if (tools.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.border, width: 1),
                  ),
                  child: Center(
                    child: T(
                      state.toolsScanning ? 'Scanning developer tools…' : 'No developer tools found in PATH',
                      size: 12,
                      color: p.muted,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < tools.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: p.ok,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        T(tools[i].name, size: 12.5, weight: FontWeight.w600),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: p.panel,
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: p.border, width: 0.5),
                                          ),
                                          child: T(tools[i].category, size: 9.5, color: p.muted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    MonoText(tools[i].path, size: 10.5, color: p.muted),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.panel,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: MonoText(tools[i].version, size: 11, color: p.text),
                              ),
                            ],
                          ),
                        ),
                        if (i < tools.length - 1)
                          Divider(height: 1, color: p.border.withOpacity(0.5)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.state});
  final AppState state;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  Color _selectedColor = const Color(0xFF6750A4);
  IconData? _selectedIcon;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.state.addWorkspaceGroup(
      name: name,
      color: _selectedColor,
      icon: _selectedIcon,
    );
    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'Create Workspace Group',
      width: 440,
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(label: 'Cancel', onClick: () => widget.state.modal = null),
        Btn(
          label: 'Create Group',
          primary: true,
          onClick: _nameCtrl.text.trim().isNotEmpty ? _submit : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Group Name', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(
            controller: _nameCtrl,
            hint: 'e.g. Clients, Microservices, Mobile Apps',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          T('Group Accent Color', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 8),
          _GroupColorPicker(
            selectedColor: _selectedColor,
            onColorChanged: (c) => setState(() => _selectedColor = c),
          ),
          const SizedBox(height: 16),
          T('Group Icon', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 8),
          _GroupIconPicker(
            selectedIcon: _selectedIcon,
            groupName: _nameCtrl.text,
            accentColor: _selectedColor,
            onIconChanged: (icon) => setState(() => _selectedIcon = icon),
          ),
        ],
      ),
    );
  }
}

class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({required this.state, required this.group});
  final AppState state;
  final WorkspaceGroup group;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late TextEditingController _nameCtrl;
  late Color _selectedColor;
  IconData? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _selectedColor = widget.group.color;
    _selectedIcon = widget.group.icon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.state.updateWorkspaceGroup(
      widget.group.copyWith(
        name: name,
        color: _selectedColor,
        icon: _selectedIcon,
        clearIcon: _selectedIcon == null,
      ),
    );
    widget.state.modal = null;
  }

  void _delete() {
    widget.state.removeWorkspaceGroup(widget.group.id);
    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isDefault = widget.group.id == 'default';

    return ModalScaffold(
      title: 'Edit Group: ${widget.group.name}',
      width: 440,
      onClose: () => widget.state.modal = null,
      actions: [
        if (!isDefault)
          Btn(
            label: 'Delete Group',
            danger: true,
            onClick: _delete,
          ),
        const Spacer(),
        Btn(label: 'Cancel', onClick: () => widget.state.modal = null),
        Btn(
          label: 'Save Changes',
          primary: true,
          onClick: _nameCtrl.text.trim().isNotEmpty ? _save : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Group Name', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _ModalTextField(
            controller: _nameCtrl,
            hint: 'Group Name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          T('Group Accent Color', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 8),
          _GroupColorPicker(
            selectedColor: _selectedColor,
            onColorChanged: (c) => setState(() => _selectedColor = c),
          ),
          const SizedBox(height: 16),
          T('Group Icon', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 8),
          _GroupIconPicker(
            selectedIcon: _selectedIcon,
            groupName: _nameCtrl.text,
            accentColor: _selectedColor,
            onIconChanged: (icon) => setState(() => _selectedIcon = icon),
          ),
        ],
      ),
    );
  }
}

class _GroupIconPicker extends StatelessWidget {
  const _GroupIconPicker({
    required this.selectedIcon,
    required this.groupName,
    required this.accentColor,
    required this.onIconChanged,
  });

  final IconData? selectedIcon;
  final String groupName;
  final Color accentColor;
  final ValueChanged<IconData?> onIconChanged;

  static const List<IconData> presetIcons = kGroupPresetIcons;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final initialLetter = groupName.trim().isNotEmpty
        ? groupName.trim()[0].toUpperCase()
        : 'A';

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        // Option 1: Initial letter (default)
        ClickableNoRipple(
          onClick: () => onIconChanged(null),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selectedIcon == null
                  ? accentColor.withOpacity(0.18)
                  : p.field,
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedIcon == null ? accentColor : p.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: T(
                initialLetter,
                size: 11.5,
                weight: FontWeight.w700,
                color: selectedIcon == null ? accentColor : p.muted,
              ),
            ),
          ),
        ),
        // Preset Icons
        for (final icon in presetIcons)
          ClickableNoRipple(
            onClick: () => onIconChanged(icon),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selectedIcon == icon
                    ? accentColor.withOpacity(0.18)
                    : p.field,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedIcon == icon ? accentColor : p.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 14,
                  color: selectedIcon == icon ? accentColor : p.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupColorPicker extends StatelessWidget {
  const _GroupColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  static const List<Color> presetColors = [
    // Purples & Indigos
    Color(0xFF6750A4), // Deep Purple
    Color(0xFF8B5CF6), // Bright Violet
    Color(0xFF6366F1), // Electric Indigo
    Color(0xFF4F46E5), // Deep Indigo
    // Blues & Cyans
    Color(0xFF2563EB), // Cobalt Blue
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF00668B), // Deep Ocean
    Color(0xFF0891B2), // Cerulean
    // Teals & Greens
    Color(0xFF0D9488), // Teal
    Color(0xFF006C4C), // Forest Green
    Color(0xFF059669), // Emerald
    Color(0xFF16A34A), // Leaf Green
    // Limes & Oranges
    Color(0xFF65A30D), // Lime
    Color(0xFFCA8A04), // Warm Gold
    Color(0xFFD97706), // Amber
    Color(0xFFEA580C), // Orange
    // Reds & Pinks
    Color(0xFFDC2626), // Vivid Red
    Color(0xFFBA1A1A), // Crimson
    Color(0xFFE11D48), // Rose
    Color(0xFFDB2777), // Pink
    // Magentas & Neutrals
    Color(0xFF9333EA), // Royal Purple
    Color(0xFF90427A), // Plum
    Color(0xFF78350F), // Espresso Brown
    Color(0xFF52525B), // Slate Gray
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final color in presetColors)
          ClickableNoRipple(
            onClick: () => onColorChanged(color),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: selectedColor.value == color.value
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _ModalTextField extends StatelessWidget {
  const _ModalTextField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -2.0),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 1,
            cursorHeight: 15,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: p.text,
              fontSize: 12.5,
            ),
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: TextStyle(
                color: p.muted,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField<V> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final V value;
  final List<DropdownMenuItem<V>> items;
  final ValueChanged<V?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<V>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: p.panel,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PinAppDialog extends StatefulWidget {
  const _PinAppDialog({required this.state});
  final AppState state;

  @override
  State<_PinAppDialog> createState() => _PinAppDialogState();
}

class _PinAppDialogState extends State<_PinAppDialog> {
  final _searchCtrl = TextEditingController();
  List<PinnedApp> _systemApps = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final list = await DesktopAppService.listSystemApplications();
    if (mounted) {
      setState(() {
        _systemApps = list;
        _loading = false;
      });
    }
    await AppIconService.extractBatch(list);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _browseDisk() async {
    final path = await Platform.pickApplication('Choose an application to pin');
    if (path != null && path.isNotEmpty) {
      await widget.state.pinApp(path);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;

    // Filtered apps by search query
    final filtered = _systemApps.where((app) {
      if (_filter.isEmpty) return true;
      return app.name.toLowerCase().contains(_filter) ||
          app.path.toLowerCase().contains(_filter);
    }).toList();

    return ModalScaffold(
      title: 'Pin Application to Toolbar',
      width: 580,
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(
          label: 'Browse from Disk…',
          icon: AppIcons.folder,
          onClick: _browseDisk,
        ),
        Btn(
          label: 'Done',
          primary: true,
          onClick: () => widget.state.modal = null,
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explanatory Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.add, size: 16, color: p.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const T(
                          'Quick-Launch Toolbar Applications',
                          size: 12.5,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: 2),
                        T(
                          'Pin any installed application or custom executable to the right-hand desktop toolbar for one-click access.',
                          size: 11.5,
                          color: p.muted,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            _ModalTextField(
              controller: _searchCtrl,
              hint: 'Search installed applications…',
              onChanged: (val) {
                setState(() => _filter = val.trim().toLowerCase());
              },
            ),
            const SizedBox(height: 12),

            // Middle Apps List
            Flexible(
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            T('Scanning installed applications…', size: 12, color: p.muted),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: T(
                              _filter.isEmpty
                                  ? 'No applications found in standard paths.\nClick "Browse from Disk…" to select an app.'
                                  : 'No applications match "$_filter"',
                              size: 12,
                              color: p.muted,
                              align: TextAlign.center,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final app in filtered) _buildAppRow(app, p),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppRow(PinnedApp app, Pal p) {
    final isPinned = widget.state.pinnedApps.any((a) => a.path == app.path);
    final onRail = widget.state.installedDesktopApps.any((a) => a.resolvedPath == app.path);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPinned ? p.accent.withOpacity(0.5) : p.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // App icon
          _AppIconView(
            app: app,
            fallbackColor: p.accent,
          ),
          const SizedBox(width: 10),
          // App name & path
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                T(app.name, size: 12.5, weight: FontWeight.w600),
                const SizedBox(height: 1),
                T(
                  app.path,
                  size: 10.5,
                  color: p.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onRail)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: T('Detected on Rail', size: 11, color: p.muted),
            )
          else if (isPinned)
            Btn(
              label: 'Pinned',
              icon: Icons.check_rounded,
              primary: true,
              height: 28,
              fontSize: 11.5,
              onClick: () {
                widget.state.unpinApp(app.path);
                setState(() {});
              },
            )
          else
            Btn(
              label: 'Pin',
              icon: AppIcons.add,
              outlined: true,
              height: 28,
              fontSize: 11.5,
              onClick: () async {
                await widget.state.pinApp(app.path);
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}

class _AppIconView extends StatefulWidget {
  const _AppIconView({required this.app, required this.fallbackColor});
  final PinnedApp app;
  final Color fallbackColor;

  @override
  State<_AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<_AppIconView> {
  io.File? _file;

  @override
  void initState() {
    super.initState();
    _file = AppIconService.getIconFileForApp(widget.app);
    if (_file == null) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(covariant _AppIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.path != widget.app.path || _file == null) {
      final f = AppIconService.getIconFileForApp(widget.app);
      if (f != null) {
        _file = f;
      } else {
        _resolve();
      }
    }
  }

  Future<void> _resolve() async {
    final cached = AppIconService.getIconFileForApp(widget.app);
    if (cached != null && cached.existsSync()) {
      if (mounted) setState(() => _file = cached);
      return;
    }
    await AppIconService.extractAppIcon(widget.app.path, widget.app.name);
    if (mounted) {
      final found = AppIconService.getIconFileForApp(widget.app);
      if (found != null && found.existsSync()) {
        setState(() => _file = found);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file ?? AppIconService.getIconFileForApp(widget.app);
    return SizedBox(
      width: 28,
      height: 28,
      child: file != null && file.existsSync()
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                file,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.apps_rounded, size: 22, color: widget.fallbackColor),
              ),
            )
          : Icon(Icons.apps_rounded, size: 22, color: widget.fallbackColor),
    );
  }
}
