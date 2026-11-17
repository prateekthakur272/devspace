import 'dart:async';
import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
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
        ModalUpdateAvailable(:final version) =>
          _UpdateAvailableDialog(state: state, version: version),
        ModalConfirmDelete(:final project) =>
          _ConfirmDeleteDialog(state: state, project: project),
        ModalGitDetails(:final project, :final status) =>
          _GitDetailsDialog(state: state, project: project, status: status),
        ModalDetectedTools() => _DetectedToolsDialog(state: state),
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

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.state});
  final AppState state;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late ThemeMode _themeMode;
  late EditorType _defaultEditor;
  late int _gitInterval;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.state.settings.themeMode;
    _defaultEditor = widget.state.settings.defaultEditor;
    _gitInterval = widget.state.settings.gitRefreshIntervalSeconds;
  }

  void _save() {
    final s = widget.state.settings.copyWith(
      themeMode: _themeMode,
      defaultEditor: _defaultEditor,
      gitRefreshIntervalSeconds: _gitInterval,
    );
    widget.state.updateSettings(s);
    widget.state.modal = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ModalScaffold(
      title: 'Preferences',
      onClose: () => widget.state.modal = null,
      actions: [
        Btn(label: 'Done', primary: true, onClick: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Appearance / Theme', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _DropdownField<ThemeMode>(
            value: _themeMode,
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: T('System Preference', size: 12.5)),
              DropdownMenuItem(value: ThemeMode.dark, child: T('Dark Theme', size: 12.5)),
              DropdownMenuItem(value: ThemeMode.light, child: T('Light Theme', size: 12.5)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _themeMode = val);
            },
          ),
          const SizedBox(height: 16),
          T('Global Default Editor', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _DropdownField<EditorType>(
            value: _defaultEditor,
            items: [
              for (final e in {
                ...widget.state.availableEditors,
                _defaultEditor,
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
              if (val != null) setState(() => _defaultEditor = val);
            },
          ),
          const SizedBox(height: 16),
          T('Git Radar Polling Interval', size: 12, weight: FontWeight.w600, color: p.muted),
          const SizedBox(height: 6),
          _DropdownField<int>(
            value: _gitInterval,
            items: const [
              DropdownMenuItem(value: 15, child: T('Every 15 seconds', size: 12.5)),
              DropdownMenuItem(value: 30, child: T('Every 30 seconds (Default)', size: 12.5)),
              DropdownMenuItem(value: 60, child: T('Every 1 minute', size: 12.5)),
              DropdownMenuItem(value: 120, child: T('Every 2 minutes', size: 12.5)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _gitInterval = val);
            },
          ),
          const SizedBox(height: 18),
          // Detected Developer Tools & SDKs section
          Row(
            children: [
              T('Detected Developer Tools & SDKs', size: 12, weight: FontWeight.w600, color: p.muted),
              const Spacer(),
              Btn(
                label: widget.state.toolsScanning ? 'Scanning…' : 'Re-scan System',
                icon: AppIcons.refresh,
                height: 24,
                onClick: widget.state.toolsScanning ? null : () => widget.state.refreshDetectedTools(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p.border, width: 1),
            ),
            child: widget.state.toolsScanning
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : widget.state.detectedTools.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: T('No CLI tools detected yet', size: 12, color: p.muted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final tool in widget.state.detectedTools) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                                  T(tool.version, size: 11.5, color: p.text),
                                  const Spacer(),
                                  T(tool.category, size: 10.5, color: p.muted),
                                ],
                              ),
                            ),
                            if (tool != widget.state.detectedTools.last)
                              Divider(height: 6, color: p.border.withOpacity(0.5)),
                          ],
                        ],
                      ),
          ),
          const SizedBox(height: 20),
          DrawTopBorder(
            color: p.border,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        T('DevSpace Data Directory', size: 12, weight: FontWeight.w600),
                        MonoText(Paths.dataDir, size: 11, color: p.muted),
                      ],
                    ),
                  ),
                  Btn(
                    label: 'Reveal in Finder',
                    icon: AppIcons.folder,
                    onClick: () => Platform.reveal(Paths.dataDir),
                  ),
                ],
              ),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AppIcons.radar, size: 32, color: p.accent),
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

class _GitDetailsDialog extends StatelessWidget {
  const _GitDetailsDialog({
    required this.state,
    required this.project,
    required this.status,
  });

  final AppState state;
  final Project project;
  final GitRepoStatus status;

  @override
  Widget build(BuildContext context) {
    return ModalScaffold(
      title: 'Git Health: ${project.name}',
      onClose: () => state.modal = null,
      actions: [
        Btn(label: 'Close', primary: true, onClick: () => state.modal = null),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('Branch: ${status.branch}', size: 13, weight: FontWeight.w600),
          if (status.lastTag != null) ...[
            const SizedBox(height: 4),
            T('Latest Tag: ${status.lastTag}', size: 12, weight: FontWeight.w500),
          ],
          if (status.lastCommitMessage != null) ...[
            const SizedBox(height: 4),
            T('Last Commit: ${status.lastCommitHash ?? ""} ${status.lastCommitMessage!}', size: 12),
          ],
          const SizedBox(height: 8),
          T('Status: ${status.isClean ? "Clean" : "${status.totalChanges} uncommitted changes (${status.stagedCount} staged, ${status.modifiedCount} modified, ${status.untrackedCount} untracked)"}'),
          T('Ahead: ${status.aheadCount} commits'),
          T('Behind: ${status.behindCount} commits'),
        ],
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
