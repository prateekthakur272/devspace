import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/theme/theme.dart';

/// Desktop drop zone widget that allows dragging and dropping folders
/// from the operating system (Finder, File Explorer) directly into DevSpace.
class ProjectDropTarget extends StatefulWidget {
  const ProjectDropTarget({
    super.key,
    required this.state,
    required this.child,
    this.targetWorkspaceId,
    this.targetWorkspaceName,
    this.showOverlay = true,
    this.onDragStateChanged,
  });

  final AppState state;
  final Widget child;
  final String? targetWorkspaceId;
  final String? targetWorkspaceName;
  final bool showOverlay;
  final ValueChanged<bool>? onDragStateChanged;

  /// Helper to process a list of dropped paths or XFiles and import them.
  static Future<int> handleDroppedFiles(
    AppState state,
    List<XFile> files, {
    String? workspaceId,
  }) async {
    final targetWorkspace = workspaceId ??
        (state.uiState.selectedWorkspaceId == 'all' ||
                state.uiState.selectedWorkspaceId == 'pinned' ||
                state.uiState.selectedWorkspaceId == 'dirty'
            ? 'default'
            : state.uiState.selectedWorkspaceId);

    final resolvedDirs = <String>{};

    for (final file in files) {
      final rawPath = file.path;
      if (rawPath.isEmpty) continue;

      try {
        final type = FileSystemEntity.typeSync(rawPath);
        if (type == FileSystemEntityType.directory) {
          resolvedDirs.add(rawPath);
        } else if (type == FileSystemEntityType.file) {
          resolvedDirs.add(File(rawPath).parent.path);
        }
      } catch (_) {
        if (Directory(rawPath).existsSync()) {
          resolvedDirs.add(rawPath);
        }
      }
    }

    if (resolvedDirs.isEmpty) {
      state.showToast('No valid project folder found in dropped items');
      return 0;
    }

    int addedCount = 0;
    String? lastAddedName;

    for (final dirPath in resolvedDirs) {
      final alreadyExists = state.projects.any((p) => p.path == dirPath);
      if (alreadyExists) {
        final existing = state.projects.firstWhere((p) => p.path == dirPath);
        state.showToast('"${existing.name}" is already in DevSpace');
        continue;
      }

      final folderName = dirPath.split(RegExp(r'[\\/]')).lastWhere(
            (e) => e.isNotEmpty,
            orElse: () => 'Project',
          );

      await state.addProject(
        path: dirPath,
        name: folderName,
        workspaceId: targetWorkspace,
      );

      lastAddedName = folderName;
      addedCount++;
    }

    if (addedCount == 1 && lastAddedName != null) {
      state.showToast('Added project "$lastAddedName"');
    } else if (addedCount > 1) {
      state.showToast('Added $addedCount projects to DevSpace');
    }

    return addedCount;
  }

  @override
  State<ProjectDropTarget> createState() => _ProjectDropTargetState();
}

class _ProjectDropTargetState extends State<ProjectDropTarget> {
  bool _isDragging = false;

  void _setDragging(bool dragging) {
    if (_isDragging != dragging) {
      setState(() => _isDragging = dragging);
      widget.onDragStateChanged?.call(dragging);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final wsName = widget.targetWorkspaceName;

    return DropTarget(
      onDragEntered: (_) => _setDragging(true),
      onDragExited: (_) => _setDragging(false),
      onDragDone: (detail) async {
        _setDragging(false);
        await ProjectDropTarget.handleDroppedFiles(
          widget.state,
          detail.files,
          workspaceId: widget.targetWorkspaceId,
        );
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_isDragging && widget.showOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.bg.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.accent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      decoration: BoxDecoration(
                        color: p.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.accent.withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: p.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.drive_folder_upload_rounded,
                              size: 30,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          T(
                            'Drop to Add Project',
                            size: 16,
                            weight: FontWeight.w600,
                            color: p.text,
                          ),
                          const SizedBox(height: 4),
                          T(
                            wsName != null
                                ? 'Add folder directly to "$wsName"'
                                : 'Folder will be added to your workspace',
                            size: 12.5,
                            color: p.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
