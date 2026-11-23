import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/context_menu.dart';
import 'package:devspace/components/drag_devices.dart';
import 'package:devspace/components/ide_icon.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/ide/ide_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

enum GitRadarFilter {
  all('All Repos'),
  dirty('Uncommitted'),
  ahead('Needs Push'),
  behind('Needs Pull'),
  clean('Clean');

  final String label;
  const GitRadarFilter(this.label);
}

enum GitRadarSort {
  needsAttention('Needs Attention First'),
  nameAsc('Name (A → Z)'),
  nameDesc('Name (Z → A)'),
  mostChanges('Most Changes'),
  aheadBehind('Ahead / Behind');

  final String label;
  const GitRadarSort(this.label);
}

enum RadarSidepaneTab {
  changes('Changes'),
  commits('Commits'),
  branches('Branches'),
  projects('Projects'),
  tools('Git Tools');

  final String label;
  const RadarSidepaneTab(this.label);
}

/// Advanced Git Radar Command Center.
/// Aggregates repository health, multi-repo sync, branch switching,
/// changed file diffs, quick commits, and remote tracking across the entire workspace.
class GitRadarView extends StatefulWidget {
  const GitRadarView({super.key, required this.state});
  final AppState state;

  @override
  State<GitRadarView> createState() => _GitRadarViewState();
}

class _GitRadarViewState extends State<GitRadarView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  GitRadarSort _activeSort = GitRadarSort.needsAttention;

  bool _isBatchOperating = false;
  String _batchOperationLabel = '';

  // --- Detailed Sidepane State ---
  String? _selectedRepoPath;
  double _sidepaneWidth = 440.0;
  RadarSidepaneTab _sidepaneTab = RadarSidepaneTab.changes;

  // Cached sidepane data
  List<GitChangedFile>? _sidepaneChangedFiles;
  bool _loadingChangedFiles = false;
  List<GitCommitInfo>? _sidepaneCommits;
  bool _loadingCommits = false;
  List<String>? _sidepaneBranches;
  bool _loadingBranches = false;

  // Diff inspection
  String? _diffFilePath;
  String? _diffContent;
  bool _loadingDiff = false;
  bool _diffIsStaged = false;

  // Inline Commit inside Sidepane
  final TextEditingController _sidepaneCommitCtrl = TextEditingController();
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.state.selectedGitRepoPath != null) {
      _selectedRepoPath = widget.state.selectedGitRepoPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedRepoPath != null) {
          _loadSidepaneData(force: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(GitRadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedGitRepoPath != null &&
        widget.state.selectedGitRepoPath != _selectedRepoPath) {
      _selectedRepoPath = widget.state.selectedGitRepoPath;
      _diffFilePath = null;
      _diffContent = null;
      _loadSidepaneData(force: true);
    } else if (widget.state.selectedGitRepoPath == null && _selectedRepoPath != null) {
      _selectedRepoPath = null;
      _diffFilePath = null;
      _diffContent = null;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sidepaneCommitCtrl.dispose();
    super.dispose();
  }

  void _selectRepo(String repoPath, {RadarSidepaneTab? initialTab}) {
    setState(() {
      _selectedRepoPath = repoPath;
      if (initialTab != null) {
        _sidepaneTab = initialTab;
      }
      _diffFilePath = null;
      _diffContent = null;
      widget.state.setSelectedGitRepoPath(repoPath);
    });
    _loadSidepaneData(force: true);
  }

  Future<void> _loadSidepaneData({bool force = false}) async {
    final repoPath = _selectedRepoPath;
    if (repoPath == null) return;

    if (_sidepaneTab == RadarSidepaneTab.changes || force) {
      setState(() => _loadingChangedFiles = true);
      final files = await GitService.getChangedFiles(repoPath);
      if (mounted && _selectedRepoPath == repoPath) {
        setState(() {
          _sidepaneChangedFiles = files;
          _loadingChangedFiles = false;
        });
      }
    }

    if (_sidepaneTab == RadarSidepaneTab.commits || force) {
      setState(() => _loadingCommits = true);
      final commits = await GitService.getRecentCommits(repoPath, count: 25);
      if (mounted && _selectedRepoPath == repoPath) {
        setState(() {
          _sidepaneCommits = commits;
          _loadingCommits = false;
        });
      }
    }

    if (_sidepaneTab == RadarSidepaneTab.branches || force) {
      setState(() => _loadingBranches = true);
      final branches = await GitService.getBranches(repoPath);
      if (mounted && _selectedRepoPath == repoPath) {
        setState(() {
          _sidepaneBranches = branches;
          _loadingBranches = false;
        });
      }
    }
  }

  Future<void> _handleSidepaneFetch(RadarRepository repo) async {
    final ok = await GitService.fetch(repo.path);
    widget.state.showToast(ok ? 'Fetched ${repo.name}' : 'Fetch failed');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleSidepanePull(RadarRepository repo) async {
    final ok = await GitService.pull(repo.path);
    widget.state.showToast(ok ? 'Pulled ${repo.name}' : 'Pull failed (check conflicts)');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleSidepanePush(RadarRepository repo) async {
    final ok = await GitService.push(repo.path);
    widget.state.showToast(ok ? 'Pushed ${repo.name}' : 'Push failed');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleSidepaneCommit(RadarRepository repo) async {
    final msg = _sidepaneCommitCtrl.text.trim();
    if (msg.isEmpty) {
      widget.state.showToast('Please enter a commit message');
      return;
    }
    setState(() => _isCommitting = true);
    final ok = await GitService.commitAll(repo.path, msg);
    if (ok) {
      _sidepaneCommitCtrl.clear();
      widget.state.showToast('Committed changes in ${repo.name}');
      for (final p in repo.linkedProjects) {
        await widget.state.refreshProjectGit(p);
      }
      await _loadSidepaneData(force: true);
    } else {
      widget.state.showToast('Commit failed');
    }
    if (mounted) setState(() => _isCommitting = false);
  }

  Future<void> _handleToggleStageFile(RadarRepository repo, GitChangedFile file) async {
    final ok = file.isStaged
        ? await GitService.unstageFile(repo.path, file.path)
        : await GitService.stageFile(repo.path, file.path);
    if (ok) {
      for (final p in repo.linkedProjects) {
        await widget.state.refreshProjectGit(p);
      }
      await _loadSidepaneData(force: true);
    }
  }

  Future<void> _handleDiscardFile(RadarRepository repo, GitChangedFile file) async {
    final ok = await GitService.discardFile(repo.path, file.path, isUntracked: file.status == '?');
    if (ok) {
      widget.state.showToast('Discarded changes in ${file.path}');
      for (final p in repo.linkedProjects) {
        await widget.state.refreshProjectGit(p);
      }
      await _loadSidepaneData(force: true);
    }
  }

  Future<void> _handleViewDiff(RadarRepository repo, GitChangedFile file) async {
    if (_diffFilePath == file.path && _diffIsStaged == file.isStaged) {
      setState(() {
        _diffFilePath = null;
        _diffContent = null;
      });
      return;
    }
    setState(() {
      _diffFilePath = file.path;
      _diffIsStaged = file.isStaged;
      _loadingDiff = true;
    });
    final diff = await GitService.getFileDiff(repo.path, file.path, staged: file.isStaged);
    if (mounted) {
      setState(() {
        _diffContent = diff;
        _loadingDiff = false;
      });
    }
  }

  Future<void> _handleSidepaneStash(RadarRepository repo) async {
    final ok = await GitService.stash(repo.path, message: 'DevSpace Stash');
    widget.state.showToast(ok ? 'Changes stashed' : 'Stash failed');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleSidepanePopStash(RadarRepository repo) async {
    final ok = await GitService.stashPop(repo.path);
    widget.state.showToast(ok ? 'Stash popped' : 'Stash pop failed');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleCheckoutBranch(RadarRepository repo, String branch) async {
    final ok = await GitService.checkoutBranch(repo.path, branch);
    if (ok) {
      widget.state.showToast('Switched to branch "$branch"');
      for (final p in repo.linkedProjects) {
        await widget.state.refreshProjectGit(p);
      }
      await _loadSidepaneData(force: true);
    } else {
      widget.state.showToast('Failed to checkout "$branch"');
    }
  }

  Future<void> _handleCreateBranch(RadarRepository repo) async {
    final ctrl = TextEditingController();
    final branchName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final p = ctx.pal;
        return AlertDialog(
          backgroundColor: p.panel,
          title: const T('Create & Checkout Branch', size: 14, weight: FontWeight.w700),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. feature/new-screen'),
          ),
          actions: [
            Btn(label: 'Cancel', onClick: () => Navigator.pop(ctx)),
            Btn(
              label: 'Create',
              primary: true,
              onClick: () => Navigator.pop(ctx, ctrl.text.trim()),
            ),
          ],
        );
      },
    );
    if (branchName != null && branchName.isNotEmpty) {
      final ok = await GitService.createBranch(repo.path, branchName);
      if (ok) {
        widget.state.showToast('Created branch "$branchName"');
        for (final p in repo.linkedProjects) {
          await widget.state.refreshProjectGit(p);
        }
        await _loadSidepaneData(force: true);
      } else {
        widget.state.showToast('Failed to create branch');
      }
    }
  }

  Future<void> _handleFetchPrune(RadarRepository repo) async {
    final ok = await GitService.fetchPrune(repo.path);
    widget.state.showToast(ok ? 'Fetched and pruned remote tracking branches' : 'Fetch failed');
    for (final p in repo.linkedProjects) {
      await widget.state.refreshProjectGit(p);
    }
    await _loadSidepaneData(force: true);
  }

  Future<void> _handleCleanUntracked(RadarRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.pal.panel,
        title: const T('Clean Untracked Files?', size: 14, weight: FontWeight.w700),
        content: const T('This will permanently delete untracked files and directories in this repository. Continue?', size: 12),
        actions: [
          Btn(label: 'Cancel', onClick: () => Navigator.pop(ctx, false)),
          Btn(label: 'Delete Files', danger: true, onClick: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmed == true) {
      await GitService.discardAllChanges(repo.path);
      widget.state.showToast('Cleaned untracked files in ${repo.name}');
      for (final p in repo.linkedProjects) {
        await widget.state.refreshProjectGit(p);
      }
      await _loadSidepaneData(force: true);
    }
  }

  // --- Repository Resolution ---

  List<RadarRepository> _getUniqueRepositories() {
    return widget.state.radarRepositories;
  }

  // --- Multi-Repo Batch Operations ---

  Future<void> _handleFetchAll() async {
    setState(() {
      _isBatchOperating = true;
      _batchOperationLabel = 'Fetching all repositories…';
    });

    final repos = _getUniqueRepositories();
    int successCount = 0;

    final futures = repos.map((r) async {
      final ok = await GitService.fetch(r.path);
      if (ok) successCount++;
    });

    await Future.wait(futures);
    await widget.state.refreshAllGit();

    if (mounted) {
      setState(() {
        _isBatchOperating = false;
        _batchOperationLabel = '';
      });
      widget.state.showToast('Fetched $successCount Git repositories');
    }
  }

  Future<void> _handlePullAllClean() async {
    setState(() {
      _isBatchOperating = true;
      _batchOperationLabel = 'Pulling upstream commits for clean repos…';
    });

    final repos = _getUniqueRepositories();
    int pulledCount = 0;

    for (final r in repos) {
      if (r.status.behindCount > 0 && r.status.isClean) {
        final ok = await GitService.pull(r.path);
        if (ok) {
          pulledCount++;
          for (final p in r.linkedProjects) {
            await widget.state.refreshProjectGit(p);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isBatchOperating = false;
        _batchOperationLabel = '';
      });
      widget.state.showToast(
        pulledCount > 0
            ? 'Successfully pulled $pulledCount clean repositories'
            : 'No clean repositories were waiting to pull',
      );
    }
  }

  Future<void> _handlePushAllAhead() async {
    setState(() {
      _isBatchOperating = true;
      _batchOperationLabel = 'Pushing local commits for ahead repos…';
    });

    final repos = _getUniqueRepositories();
    int pushedCount = 0;

    for (final r in repos) {
      if (r.status.aheadCount > 0) {
        final ok = await GitService.push(r.path);
        if (ok) {
          pushedCount++;
          for (final p in r.linkedProjects) {
            await widget.state.refreshProjectGit(p);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isBatchOperating = false;
        _batchOperationLabel = '';
      });
      widget.state.showToast(
        pushedCount > 0
            ? 'Successfully pushed $pushedCount repositories'
            : 'No repositories were ahead of remote',
      );
    }
  }

  Future<void> _handleStashAllDirty() async {
    setState(() {
      _isBatchOperating = true;
      _batchOperationLabel = 'Stashing uncommitted changes…';
    });

    final repos = _getUniqueRepositories();
    int stashedCount = 0;

    for (final r in repos) {
      if (r.status.isDirty) {
        final ok = await GitService.stash(r.path, message: 'DevSpace Auto-Stash');
        if (ok) {
          stashedCount++;
          for (final p in r.linkedProjects) {
            await widget.state.refreshProjectGit(p);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isBatchOperating = false;
        _batchOperationLabel = '';
      });
      widget.state.showToast('Stashed changes in $stashedCount repositories');
    }
  }

  // --- Branch Switcher Menu ---

  void _showBranchSwitcher(BuildContext context, Offset position, RadarRepository repo) async {
    final branches = await GitService.getBranches(repo.path);
    if (!context.mounted) return;

    if (branches.isEmpty) {
      widget.state.showToast('No other branches found for ${repo.name}');
      return;
    }

    final items = <ContextMenuItem>[
      ContextMenuItem(
        label: 'Branches in ${repo.name}',
        icon: AppIcons.branch,
      ),
      const ContextMenuItem(label: ''),
      for (final b in branches)
        ContextMenuItem(
          label: b,
          leading: b == repo.status.branch
              ? Icon(Icons.check_rounded, size: 14, color: context.pal.accent)
              : const SizedBox(width: 14),
          action: () async {
            if (b == repo.status.branch) return;
            final ok = await GitService.checkoutBranch(repo.path, b);
            if (ok) {
              for (final pr in repo.linkedProjects) {
                await widget.state.refreshProjectGit(pr);
              }
              widget.state.showToast('Switched to branch "$b"');
            } else {
              widget.state.showToast('Failed switching to branch "$b" (check dirty files)');
            }
          },
        ),
    ];

    ContextMenu.show(context, position, items);
  }

  // --- Open in Editor Menu (with Submenu for Multi-Project Repos) ---

  List<ContextMenuItem> _buildOpenProjectMenuItems(RadarRepository repo) {
    return [
      for (final proj in repo.linkedProjects)
        ContextMenuItem(
          label: '${proj.name} (${proj.techStack.label})',
          icon: AppIcons.project,
          action: () => widget.state.launchProject(proj),
        ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Repo Root (${repo.name})',
        icon: AppIcons.folder,
        action: () {
          final editor = widget.state.settings.defaultEditor;
          IdeService.launchEditor(editor, path: repo.path);
        },
      ),
    ];
  }

  ContextMenuItem _buildOpenMenuItem(RadarRepository repo) {
    if (repo.linkedProjects.length > 1) {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        submenu: _buildOpenProjectMenuItems(repo),
      );
    } else if (repo.linkedProjects.length == 1) {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        action: () => widget.state.launchProject(repo.linkedProjects.first),
      );
    } else {
      return ContextMenuItem(
        label: 'Open',
        icon: AppIcons.code,
        action: () => IdeService.launchEditor(
          widget.state.settings.defaultEditor,
          path: repo.path,
        ),
      );
    }
  }

  void _showRepoContextMenu(BuildContext context, Offset position, RadarRepository repo) {
    final status = repo.status;
    ContextMenu.show(context, position, [
      _buildOpenMenuItem(repo),
      if (repo.linkedProjects.isNotEmpty)
        ContextMenuItem(
          label: 'Git Details Modal…',
          icon: AppIcons.branch,
          action: () => widget.state.modal = ModalGitDetails(repo.linkedProjects.first, status),
        ),
      if (status.isDirty)
        ContextMenuItem(
          label: 'Quick Commit…',
          icon: AppIcons.commit,
          action: () => _showQuickCommitDialog(repo),
        ),
      ContextMenuItem(
        label: 'Terminal',
        icon: AppIcons.terminal,
        action: () => widget.state.openTerminal(repo.path, title: repo.name),
      ),
      ContextMenuItem(
        label: 'Fetch Remote',
        icon: AppIcons.refresh,
        action: () async {
          final ok = await GitService.fetch(repo.path);
          for (final pr in repo.linkedProjects) {
            await widget.state.refreshProjectGit(pr);
          }
          widget.state.showToast(ok ? 'Fetched ${repo.name}' : 'Fetch failed');
        },
      ),
      if (status.isDirty) ...[
        ContextMenuItem(
          label: 'Stash Changes',
          icon: Icons.archive_rounded,
          action: () async {
            final ok = await GitService.stash(repo.path);
            for (final pr in repo.linkedProjects) {
              await widget.state.refreshProjectGit(pr);
            }
            widget.state.showToast(ok ? 'Changes stashed' : 'Stash failed');
          },
        ),
        ContextMenuItem(
          label: 'Discard All Uncommitted Changes…',
          icon: AppIcons.delete,
          danger: true,
          action: () async {
            final ok = await GitService.discardAllChanges(repo.path);
            for (final pr in repo.linkedProjects) {
              await widget.state.refreshProjectGit(pr);
            }
            widget.state.showToast(ok ? 'Changes discarded' : 'Discard failed');
          },
        ),
      ],
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Copy Branch Name',
        icon: AppIcons.copy,
        action: () {
          Platform.copy(status.branch);
          widget.state.showToast('Copied branch "${status.branch}"');
        },
      ),
      if (status.lastCommitHash != null)
        ContextMenuItem(
          label: 'Copy Last Commit Hash',
          icon: AppIcons.copy,
          action: () {
            Platform.copy(status.lastCommitHash!);
            widget.state.showToast('Copied hash "${status.lastCommitHash}"');
          },
        ),
      if (status.remoteUrl != null)
        ContextMenuItem(
          label: 'Copy Remote URL',
          icon: AppIcons.link,
          action: () {
            Platform.copy(status.remoteUrl!);
            widget.state.showToast('Copied remote URL');
          },
        ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Copy Repository Path',
        icon: AppIcons.copy,
        action: () {
          Platform.copy(repo.path);
          widget.state.showToast('Copied ${repo.path}');
        },
      ),
      ContextMenuItem(
        label: Platform.revealLabel,
        icon: AppIcons.folder,
        action: () => Platform.reveal(repo.path),
      ),
      if (status.remoteUrl != null)
        ContextMenuItem(
          label: 'Open Remote in Browser',
          icon: AppIcons.external,
          action: () => Platform.openUrl(status.remoteUrl!),
        ),
      const ContextMenuItem(label: ''),
      ContextMenuItem(
        label: 'Checkout Branch…',
        icon: AppIcons.branch,
        action: () => _showBranchSwitcher(context, position, repo),
      ),
      if (repo.linkedProjects.isNotEmpty)
        ContextMenuItem(
          label: 'Remove from DevSpace…',
          icon: AppIcons.delete,
          danger: true,
          action: () => widget.state.modal = ModalConfirmDelete(project: repo.linkedProjects.first),
        ),
    ]);
  }

  // --- Quick Commit Modal ---

  void _showQuickCommitDialog(RadarRepository repo) {
    final p = context.pal;
    final msgCtrl = TextEditingController();
    bool committing = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            backgroundColor: p.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: p.border, width: 1),
            ),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.commit, size: 20, color: p.accent),
                      const SizedBox(width: 8),
                      T('Quick Commit — ${repo.name}', size: 15, weight: FontWeight.w700),
                      const Spacer(),
                      IconBtn(
                        icon: AppIcons.close,
                        size: 24,
                        iconSize: 13,
                        onClick: () => Navigator.of(dlgCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  T(
                    'Stage all modified & untracked files in ${repo.path} and commit with message:',
                    size: 11.5,
                    color: p.muted,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: p.field,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.border, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: msgCtrl,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 2,
                      style: TextStyle(color: p.text, fontSize: 13),
                      decoration: InputDecoration.collapsed(
                        hintText: 'feat: descriptive commit message…',
                        hintStyle: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Btn(
                        label: 'Cancel',
                        outlined: true,
                        height: 32,
                        onClick: () => Navigator.of(dlgCtx).pop(),
                      ),
                      const SizedBox(width: 10),
                      Btn(
                        label: committing ? 'Committing…' : 'Stage & Commit',
                        icon: AppIcons.check,
                        primary: true,
                        height: 32,
                        onClick: committing
                            ? null
                            : () async {
                                final msg = msgCtrl.text.trim();
                                if (msg.isEmpty) {
                                  widget.state.showToast('Please enter a commit message');
                                  return;
                                }
                                setDlgState(() => committing = true);
                                final ok = await GitService.commitAll(repo.path, msg);
                                if (dlgCtx.mounted) Navigator.of(dlgCtx).pop();
                                for (final pr in repo.linkedProjects) {
                                  await widget.state.refreshProjectGit(pr);
                                }
                                widget.state.showToast(
                                  ok ? 'Successfully committed in ${repo.name}' : 'Commit failed',
                                );
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final allRepos = _getUniqueRepositories();

    // Metrics calculation
    int totalRepos = allRepos.length;
    int cleanCount = 0;
    int dirtyCount = 0;
    int aheadCount = 0;
    int behindCount = 0;

    for (final r in allRepos) {
      if (r.status.isClean) cleanCount++;
      if (r.status.isDirty) dirtyCount++;
      if (r.status.aheadCount > 0) aheadCount++;
      if (r.status.behindCount > 0) behindCount++;
    }

    final activeFilter = widget.state.gitRadarFilter;
    final activeRemote = widget.state.gitRadarRemoteFilter;
    final activeBranch = widget.state.gitRadarBranchFilter;

    // Filtering
    var filtered = allRepos.where((repo) {
      final s = repo.status;

      // Status Filter
      switch (activeFilter) {
        case 'dirty':
          if (!s.isDirty) return false;
          break;
        case 'ahead':
          if (s.aheadCount <= 0) return false;
          break;
        case 'behind':
          if (s.behindCount <= 0) return false;
          break;
        case 'clean':
          if (!s.isClean) return false;
          break;
        case 'stash':
          if (!s.hasStash) return false;
          break;
        case 'all':
        default:
          break;
      }

      // Remote Host Filter
      if (activeRemote != null) {
        final remote = s.remoteUrl?.toLowerCase() ?? '';
        if (activeRemote == 'github' && !remote.contains('github')) return false;
        if (activeRemote == 'gitlab' && !remote.contains('gitlab')) return false;
        if (activeRemote == 'bitbucket' && !remote.contains('bitbucket')) return false;
        if (activeRemote == 'local' && (remote.contains('github') || remote.contains('gitlab') || remote.contains('bitbucket'))) return false;
      }

      // Branch Filter
      if (activeBranch != null && s.branch != activeBranch) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = repo.name.toLowerCase().contains(q);
        final pathMatches = repo.path.toLowerCase().contains(q);
        final branchMatches = s.branch.toLowerCase().contains(q);
        final commitMatches = s.lastCommitMessage?.toLowerCase().contains(q) ?? false;
        final authorMatches = s.lastCommitAuthor?.toLowerCase().contains(q) ?? false;
        final projectMatches = repo.linkedProjects.any((p) =>
            p.name.toLowerCase().contains(q) ||
            p.techStack.label.toLowerCase().contains(q));

        if (!nameMatches && !pathMatches && !branchMatches && !commitMatches && !authorMatches && !projectMatches) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      final sa = a.status;
      final sb = b.status;

      switch (_activeSort) {
        case GitRadarSort.needsAttention:
          int priority(GitRepoStatus s) {
            if (s.isDirty) return 1;
            if (s.behindCount > 0 && s.aheadCount > 0) return 2;
            if (s.behindCount > 0) return 3;
            if (s.aheadCount > 0) return 4;
            return 5; // Clean
          }
          final pA = priority(sa);
          final pB = priority(sb);
          if (pA != pB) return pA.compareTo(pB);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());

        case GitRadarSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());

        case GitRadarSort.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());

        case GitRadarSort.mostChanges:
          final changesA = sa.totalChanges;
          final changesB = sb.totalChanges;
          if (changesA != changesB) return changesB.compareTo(changesA);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());

        case GitRadarSort.aheadBehind:
          final divA = sa.aheadCount + sa.behindCount;
          final divB = sb.aheadCount + sb.behindCount;
          if (divA != divB) return divB.compareTo(divA);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    final mainContent = Container(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header with Integrated Search, Sort, Metrics & Batch Actions
          _buildRadarHeader(
            context,
            p,
            totalRepos: totalRepos,
            matchingCount: filtered.length,
            cleanCount: cleanCount,
            dirtyCount: dirtyCount,
            aheadCount: aheadCount,
            behindCount: behindCount,
          ),

          // Batch operation banner (if running)
          if (_isBatchOperating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: p.accent.withOpacity(0.12),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                  ),
                  const SizedBox(width: 10),
                  T(_batchOperationLabel, size: 12, weight: FontWeight.w600, color: p.accent),
                ],
              ),
            ),

          // 2. Repository Cards List & Detailed Sidepane
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final selectedRepo = _selectedRepoPath != null
                    ? allRepos.where((r) => r.path == _selectedRepoPath).firstOrNull
                    : null;

                final showSidepane = selectedRepo != null;

                if (!showSidepane) {
                  return filtered.isEmpty
                      ? _buildEmptyState(
                          p,
                          hasAnyProjects: widget.state.projects.isNotEmpty,
                          hasAnyRepos: allRepos.isNotEmpty,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final repo = filtered[idx];
                            final isLoading = repo.linkedProjects.any((p) => widget.state.gitLoading[p.id] == true);

                            return _buildEnhancedRepoCard(
                              context,
                              p,
                              repo: repo,
                              isLoading: isLoading,
                              isSelected: false,
                              onTap: () => _selectRepo(repo.path),
                            );
                          },
                        );
                }

                final availableW = constraints.maxWidth;
                final double sideW;
                if (availableW < 850) {
                  final maxSide = (availableW - 300.0).clamp(240.0, 480.0);
                  sideW = (availableW * 0.42).clamp(240.0, maxSide);
                } else {
                  final maxSide = (availableW - 360.0).clamp(300.0, 640.0);
                  sideW = _sidepaneWidth.clamp(300.0, maxSide);
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Repository Cards List
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(
                              p,
                              hasAnyProjects: widget.state.projects.isNotEmpty,
                              hasAnyRepos: allRepos.isNotEmpty,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final repo = filtered[idx];
                                final isLoading = repo.linkedProjects.any((p) => widget.state.gitLoading[p.id] == true);

                                return _buildEnhancedRepoCard(
                                  context,
                                  p,
                                  repo: repo,
                                  isLoading: isLoading,
                                  isSelected: repo.path == _selectedRepoPath,
                                  onTap: () => _selectRepo(repo.path),
                                );
                              },
                            ),
                    ),

                    // Resizable Splitter Handle
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        supportedDevices: kDragDevices,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _sidepaneWidth = (_sidepaneWidth - details.delta.dx).clamp(300.0, 640.0);
                          });
                        },
                        child: Container(
                          width: 6,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 1,
                              color: p.border,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right: Detailed Sidepane
                    SizedBox(
                      width: sideW,
                      child: _buildRepoDetailSidepane(context, p, selectedRepo),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selectedRepoPath != null) {
            setState(() => _selectedRepoPath = null);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: mainContent,
      ),
    );
  }

  // --- Header & Multi-Repo Control Ribbon (with Integrated Search & Sort) ---

  Widget _buildRadarHeader(
    BuildContext context,
    Pal p, {
    required int totalRepos,
    required int matchingCount,
    required int cleanCount,
    required int dirtyCount,
    required int aheadCount,
    required int behindCount,
  }) {
    Widget buildSearchBox() {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(AppIcons.search, size: 12.5, color: p.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                maxLines: 1,
                style: TextStyle(color: p.text, fontSize: 11.5),
                decoration: InputDecoration.collapsed(
                  hintText: 'Search by repo, branch, path, author, commit…',
                  hintStyle: TextStyle(color: p.muted, fontSize: 11.5),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              IconBtn(
                icon: AppIcons.close,
                size: 16,
                iconSize: 9,
                onClick: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              ),
          ],
        ),
      );
    }

    Widget buildSortButton({bool compact = false}) {
      return Builder(
        builder: (btnCtx) => compact
            ? IconBtn(
                icon: Icons.swap_vert_rounded,
                tooltip: 'Sort: ${_activeSort.label}',
                size: 30,
                iconSize: 15,
                onClick: () {
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                    ContextMenu.show(btnCtx, pos, [
                      for (final s in GitRadarSort.values)
                        ContextMenuItem(
                          label: s.label,
                          leading: s == _activeSort
                              ? Icon(Icons.check_rounded, size: 14, color: p.accent)
                              : const SizedBox(width: 14),
                          action: () => setState(() => _activeSort = s),
                        ),
                    ]);
                  }
                },
              )
            : Btn(
                icon: Icons.swap_vert_rounded,
                label: _activeSort.label,
                height: 30,
                outlined: true,
                fontSize: 11,
                onClick: () {
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                    ContextMenu.show(btnCtx, pos, [
                      for (final s in GitRadarSort.values)
                        ContextMenuItem(
                          label: s.label,
                          leading: s == _activeSort
                              ? Icon(Icons.check_rounded, size: 14, color: p.accent)
                              : const SizedBox(width: 14),
                          action: () => setState(() => _activeSort = s),
                        ),
                    ]);
                  }
                },
              ),
      );
    }

    Widget buildBatchButtons({double height = 30, double fontSize = 11.5}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Btn(
            label: 'Fetch All',
            icon: AppIcons.refresh,
            outlined: true,
            height: height,
            fontSize: fontSize,
            onClick: _isBatchOperating ? null : _handleFetchAll,
          ),
          if (behindCount > 0) ...[
            const SizedBox(width: 6),
            Btn(
              label: 'Pull Clean ($behindCount)',
              icon: AppIcons.pull,
              outlined: true,
              height: height,
              fontSize: fontSize,
              onClick: _isBatchOperating ? null : _handlePullAllClean,
            ),
          ],
          if (aheadCount > 0) ...[
            const SizedBox(width: 6),
            Btn(
              label: 'Push All ($aheadCount)',
              icon: AppIcons.push,
              outlined: true,
              height: height,
              fontSize: fontSize,
              onClick: _isBatchOperating ? null : _handlePushAllAhead,
            ),
          ],
        ],
      );
    }

    Widget buildOverflowMenu() {
      return Builder(
        builder: (btnCtx) => IconBtn(
          icon: AppIcons.dots,
          tooltip: 'More Git Radar actions',
          size: 30,
          iconSize: 15,
          onClick: () {
            final box = btnCtx.findRenderObject() as RenderBox?;
            if (box != null) {
              final pos = box.localToGlobal(Offset(0, box.size.height + 4));
              ContextMenu.show(btnCtx, pos, [
                ContextMenuItem(
                  label: 'Fetch All Repos',
                  icon: AppIcons.refresh,
                  action: _handleFetchAll,
                ),
                if (behindCount > 0)
                  ContextMenuItem(
                    label: 'Pull All Clean Repos ($behindCount)',
                    icon: AppIcons.pull,
                    action: _handlePullAllClean,
                  ),
                if (aheadCount > 0)
                  ContextMenuItem(
                    label: 'Push All Ahead Repos ($aheadCount)',
                    icon: AppIcons.push,
                    action: _handlePushAllAhead,
                  ),
                const ContextMenuItem(label: ''),
                ContextMenuItem(
                  label: 'Rescan Git Statuses',
                  icon: AppIcons.refresh,
                  action: () => widget.state.refreshAllGit(),
                ),
                ContextMenuItem(
                  label: 'Stash All Dirty Repos ($dirtyCount)',
                  icon: Icons.archive_rounded,
                  action: _handleStashAllDirty,
                ),
                const ContextMenuItem(label: ''),
                ContextMenuItem(
                  label: 'Open Terminal at Root',
                  icon: AppIcons.terminal,
                  action: () => widget.state.openTerminal('/'),
                ),
              ]);
            }
          },
        ),
      );
    }

    Widget? buildActiveFilterBadge() {
      final activeFilter = widget.state.gitRadarFilter;
      final activeRemote = widget.state.gitRadarRemoteFilter;
      final activeBranch = widget.state.gitRadarBranchFilter;

      if (activeFilter == 'all' && activeRemote == null && activeBranch == null) {
        return null;
      }

      String label;
      Color col = p.accent;
      IconData icon = AppIcons.filter;

      if (activeRemote != null) {
        label = 'Remote: $activeRemote';
        icon = AppIcons.link;
      } else if (activeBranch != null) {
        label = 'Branch: $activeBranch';
        icon = AppIcons.branch;
      } else {
        switch (activeFilter) {
          case 'dirty':
            label = 'Uncommitted';
            col = p.warn;
            icon = AppIcons.alert;
            break;
          case 'ahead':
            label = 'Needs Push';
            col = p.accent;
            icon = AppIcons.push;
            break;
          case 'behind':
            label = 'Needs Pull';
            col = p.err;
            icon = AppIcons.pull;
            break;
          case 'stash':
            label = 'Stashes';
            col = const Color(0xFFC084FC);
            icon = Icons.archive_rounded;
            break;
          case 'clean':
            label = 'Clean';
            col = p.ok;
            icon = Icons.check_circle_outline_rounded;
            break;
          default:
            label = activeFilter;
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: col.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: col.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: col),
            const SizedBox(width: 4),
            T(label, size: 10.5, weight: FontWeight.w600, color: col),
            const SizedBox(width: 4),
            ClickableNoRipple(
              onClick: () {
                widget.state.setGitRadarFilter('all');
                widget.state.setGitRadarRemoteFilter(null);
                widget.state.setGitRadarBranchFilter(null);
              },
              child: Icon(Icons.close_rounded, size: 12, color: col),
            ),
          ],
        ),
      );
    }

    final activeBadge = buildActiveFilterBadge();

    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(bottom: BorderSide(color: p.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final isMedium = constraints.maxWidth >= 500;
          final isCompact = constraints.maxWidth < 420;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Search Box
              if (isWide)
                SizedBox(
                  width: (constraints.maxWidth * 0.35).clamp(220.0, 320.0),
                  child: buildSearchBox(),
                )
              else
                Expanded(
                  child: buildSearchBox(),
                ),
              const SizedBox(width: 6),

              // 2. Sort Dropdown (compact icon on very narrow widths)
              buildSortButton(compact: isCompact),

              // 3. Active filter badge (if filtered, on medium+ widths)
              if (activeBadge != null && isMedium) ...[
                const SizedBox(width: 6),
                activeBadge,
              ],

              // 4. Spacer when space is ample
              if (isWide) const Spacer() else const SizedBox(width: 6),

              // 5. Batch Action Buttons (Fetch, Pull, Push - when width permits)
              if (isWide) ...[
                buildBatchButtons(height: 30, fontSize: 11),
                const SizedBox(width: 6),
              ],

              // 6. Overflow / More Menu
              buildOverflowMenu(),
            ],
          );
        },
      ),
    );
  }

  // --- Enhanced Repository Card ---

  Widget _buildEnhancedRepoCard(
    BuildContext context,
    Pal p, {
    required RadarRepository repo,
    required bool isLoading,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final status = repo.status;
    final isDirty = status.isDirty;

    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final isCompact = cardConstraints.maxWidth < 560;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onSecondaryTapDown: (details) => _showRepoContextMenu(context, details.globalPosition, repo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? p.accent.withOpacity(0.04) : p.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? p.accent : p.border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? p.accent.withOpacity(0.12) : Colors.black.withOpacity(0.03),
                    blurRadius: isSelected ? 6 : 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              // 1. Repository First Leading Emblem
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDirty
                      ? p.warn.withOpacity(0.12)
                      : (status.aheadCount > 0
                          ? p.accent.withOpacity(0.12)
                          : p.ok.withOpacity(0.10)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDirty
                        ? p.warn.withOpacity(0.35)
                        : (status.aheadCount > 0
                            ? p.accent.withOpacity(0.35)
                            : p.ok.withOpacity(0.25)),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    AppIcons.branch,
                    size: 16,
                    color: isDirty
                        ? p.warn
                        : (status.aheadCount > 0 ? p.accent : p.ok),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Repository Identity & Changes (Repository-First hierarchy)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isCompact ? 140 : 200),
                          child: T(
                            repo.name,
                            size: 13.5,
                            weight: FontWeight.w700,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Branch Switcher Button
                        Builder(
                          builder: (btnCtx) => HoverBuilder(
                            cursor: SystemMouseCursors.click,
                            onTap: () {
                              final box = btnCtx.findRenderObject() as RenderBox?;
                              if (box != null) {
                                final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                                _showBranchSwitcher(btnCtx, pos, repo);
                              }
                            },
                            builder: (context, hovered) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: hovered
                                      ? p.accent.withOpacity(0.18)
                                      : p.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: p.accent.withOpacity(hovered ? 0.6 : 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.branch, size: 11, color: p.accent),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 130),
                                      child: T(
                                        status.branch,
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: p.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_drop_down_rounded, size: 14, color: p.muted),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Upstream ahead/behind pills
                        if (status.aheadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: T(
                              '↑${status.aheadCount}',
                              size: 10.5,
                              weight: FontWeight.w700,
                              color: p.accent,
                            ),
                          ),

                        if (status.behindCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.err.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: T(
                              '↓${status.behindCount}',
                              size: 10.5,
                              weight: FontWeight.w700,
                              color: p.err,
                            ),
                          ),

                        _buildRepoStatusChip(status, p),

                        // Workspace Changes Breakdown Chips
                        if (!status.isClean) ...[
                          if (status.modifiedCount > 0)
                            _buildChangeChip('~${status.modifiedCount}', p.warn, () => widget.state.modal = ModalGitDetails(repo.linkedProjects.first, status)),
                          if (status.stagedCount > 0)
                            _buildChangeChip('+${status.stagedCount}', p.ok, () => widget.state.modal = ModalGitDetails(repo.linkedProjects.first, status)),
                          if (status.untrackedCount > 0)
                            _buildChangeChip('?${status.untrackedCount}', p.muted, () => widget.state.modal = ModalGitDetails(repo.linkedProjects.first, status)),
                          if (status.hasStash)
                            _buildChangeChip('📦 Stash', const Color(0xFFC084FC), () => widget.state.modal = ModalGitDetails(repo.linkedProjects.first, status)),
                        ],

                        if (status.remoteUrl != null)
                          _buildRemoteUrlButton(status.remoteUrl!, p),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Subtitle line: Last Commit / Path + Linked Projects Tag(s)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        if (status.lastCommitMessage != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.commit, size: 11, color: p.muted),
                              const SizedBox(width: 4),
                              if (status.lastCommitHash != null) ...[
                                ClickableNoRipple(
                                  onClick: () {
                                    Platform.copy(status.lastCommitHash!);
                                    widget.state.showToast('Copied commit ${status.lastCommitHash}');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                    decoration: BoxDecoration(
                                      color: p.accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: MonoText(
                                      status.lastCommitHash!,
                                      size: 9.5,
                                      weight: FontWeight.w600,
                                      color: p.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isCompact ? 110 : 170),
                                  child: T(
                                    status.lastCommitMessage!,
                                    size: 10.5,
                                    color: p.text.withOpacity(0.85),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (status.lastCommitDate != null) ...[
                                const SizedBox(width: 5),
                                T(
                                  _formatRelativeDate(status.lastCommitDate!),
                                  size: 10,
                                  color: p.muted,
                                ),
                              ],
                            ],
                          ),
                          T('•', size: 10, color: p.muted),
                        ],
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isCompact ? 120 : 180),
                          child: MonoText(
                            repo.path,
                            size: 10,
                            color: p.muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Linked Projects Badges
                        for (final proj in repo.linkedProjects)
                          ClickableNoRipple(
                            onClick: () => widget.state.launchProject(proj),
                            child: Container(
                              constraints: BoxConstraints(maxWidth: isCompact ? 110 : 160),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: proj.techStack.color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: proj.techStack.color.withOpacity(0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.folder, size: 9.5, color: proj.techStack.color),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: T(
                                      proj.name,
                                      size: 9.5,
                                      color: proj.techStack.color,
                                      weight: FontWeight.w600,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 3. Action Buttons Toolbar
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                // Push button (when ahead)
                if (status.aheadCount > 0) ...[
                  IconBtn(
                    icon: AppIcons.push,
                    tooltip: 'Push ${status.aheadCount} ${status.aheadCount == 1 ? "commit" : "commits"} to remote',
                    size: 28,
                    iconSize: 14,
                    color: p.accent,
                    onClick: () async {
                      final ok = await GitService.push(repo.path);
                      for (final pr in repo.linkedProjects) {
                        await widget.state.refreshProjectGit(pr);
                      }
                      widget.state.showToast(ok ? 'Pushed to remote' : 'Git push failed');
                    },
                  ),
                  const SizedBox(width: 2),
                ],

                // Pull button (when behind)
                if (status.behindCount > 0) ...[
                  IconBtn(
                    icon: AppIcons.pull,
                    tooltip: 'Pull ${status.behindCount} ${status.behindCount == 1 ? "commit" : "commits"} from remote',
                    size: 28,
                    iconSize: 14,
                    color: p.err,
                    onClick: () async {
                      final ok = await GitService.pull(repo.path);
                      for (final pr in repo.linkedProjects) {
                        await widget.state.refreshProjectGit(pr);
                      }
                      widget.state.showToast(ok ? 'Pulled from remote' : 'Git push failed');
                    },
                  ),
                  const SizedBox(width: 2),
                ],

                // More Menu
                Builder(
                  builder: (btnCtx) => IconBtn(
                    icon: AppIcons.moreVert,
                    tooltip: 'More actions',
                    size: 28,
                    iconSize: 14,
                    onClick: () {
                      final box = btnCtx.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                        _showRepoContextMenu(btnCtx, pos, repo);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isSelected ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: isSelected ? p.accent : p.muted.withOpacity(0.35),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
      },
    );
  }

  Widget _buildRepoStatusChip(GitRepoStatus? status, Pal p) {
    if (status == null || !status.isGitRepo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: p.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.border, width: 1),
        ),
        child: T('Non-Git', size: 10, color: p.muted, weight: FontWeight.w600),
      );
    }

    if (status.isDirty) {
      final total = status.totalChanges;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: p.warn.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.warn.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.alert, size: 10.5, color: p.warn),
            const SizedBox(width: 4),
            Flexible(
              child: T(
                'Uncommitted ($total)',
                size: 10,
                color: p.warn,
                weight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (status.behindCount > 0 && status.aheadCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: p.err.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.err.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem_rounded, size: 11, color: p.err),
            const SizedBox(width: 4),
            Flexible(
              child: T(
                'Diverged (↑${status.aheadCount} ↓${status.behindCount})',
                size: 10,
                color: p.err,
                weight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (status.behindCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: p.err.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.err.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.pull, size: 10.5, color: p.err),
            const SizedBox(width: 4),
            Flexible(
              child: T(
                'Needs Pull (${status.behindCount})',
                size: 10,
                color: p.err,
                weight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (status.aheadCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: p.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.accent.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.push, size: 10.5, color: p.accent),
            const SizedBox(width: 4),
            Flexible(
              child: T(
                'Needs Push (${status.aheadCount})',
                size: 10,
                color: p.accent,
                weight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: p.ok.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.ok.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.check, size: 10.5, color: p.ok),
          const SizedBox(width: 4),
          T('Clean', size: 10, color: p.ok, weight: FontWeight.w600),
        ],
      ),
    );
  }

  Widget _buildChangeChip(String label, Color color, [VoidCallback? onTap]) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: T(label, size: 10.5, color: color, weight: FontWeight.w700),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: onTap != null
          ? ClickableNoRipple(onClick: onTap, child: chip)
          : chip,
    );
  }

  Widget _buildRemoteUrlButton(String url, Pal p) {
    String label = 'Remote';
    if (url.contains('github.com')) label = 'GitHub';
    if (url.contains('gitlab.com')) label = 'GitLab';
    if (url.contains('bitbucket.org')) label = 'Bitbucket';

    String webUrl = url;
    if (url.startsWith('git@') || url.startsWith('ssh://')) {
      // Convert git@github.com:user/repo.git to https://github.com/user/repo
      final cleaned = url.replaceAll(RegExp(r'^(git@|ssh://git@)'), '').replaceAll(':', '/');
      webUrl = 'https://${cleaned.replaceAll(RegExp(r'\.git$'), '')}';
    } else if (url.endsWith('.git')) {
      webUrl = url.substring(0, url.length - 4);
    }

    return ClickableNoRipple(
      onClick: () => Platform.openUrl(webUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.link, size: 10, color: p.accent),
            const SizedBox(width: 4),
            T(label, size: 10, weight: FontWeight.w600, color: p.text),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    Pal p, {
    required bool hasAnyProjects,
    required bool hasAnyRepos,
  }) {
    if (!hasAnyProjects) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.radar, size: 36, color: p.muted.withOpacity(0.5)),
              const SizedBox(height: 12),
              T(
                'No projects in workspace',
                size: 13.5,
                weight: FontWeight.w600,
                color: p.text,
              ),
              const SizedBox(height: 4),
              T(
                'Add projects to your workspace to monitor their Git repositories.',
                size: 11.5,
                color: p.muted,
              ),
            ],
          ),
        ),
      );
    }

    if (!hasAnyRepos) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.radar, size: 36, color: p.muted.withOpacity(0.5)),
              const SizedBox(height: 12),
              T(
                'No Git repositories found',
                size: 13.5,
                weight: FontWeight.w600,
                color: p.text,
              ),
              const SizedBox(height: 4),
              T(
                'None of the projects in your workspace are inside a Git repository.',
                size: 11.5,
                color: p.muted,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.radar, size: 36, color: p.muted.withOpacity(0.5)),
            const SizedBox(height: 12),
            T(
              _searchQuery.isNotEmpty
                  ? 'No repositories match "$_searchQuery"'
                  : 'No repositories in current filter',
              size: 13.5,
              weight: FontWeight.w600,
              color: p.text,
            ),
            const SizedBox(height: 4),
            T(
              'Try adjusting your search terms or clearing the status filter above.',
              size: 11.5,
              color: p.muted,
            ),
            const SizedBox(height: 12),
            Btn(
              label: 'Reset Filters',
              outlined: true,
              height: 30,
              fontSize: 11.5,
              onClick: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                });
                widget.state.setGitRadarFilter('all');
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Detailed Repository Sidepane & Tools ---

  Widget _buildRepoDetailSidepane(BuildContext context, Pal p, RadarRepository repo) {
    final status = repo.status;
    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(left: BorderSide(color: p.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: p.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(AppIcons.branch, size: 14, color: p.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: T(
                        repo.name,
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: p.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildRepoStatusChip(status, p),
                    const SizedBox(width: 4),
                    IconBtn(
                      icon: Icons.close_rounded,
                      tooltip: 'Close sidepane (Esc)',
                      size: 26,
                      iconSize: 15,
                      onClick: () => setState(() => _selectedRepoPath = null),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Path with Copy & Reveal
                Row(
                  children: [
                    Expanded(
                      child: MonoText(
                        repo.path,
                        size: 10,
                        color: p.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconBtn(
                      icon: AppIcons.copy,
                      tooltip: 'Copy path',
                      size: 22,
                      iconSize: 11,
                      onClick: () {
                        Platform.copy(repo.path);
                        widget.state.showToast('Copied ${repo.path}');
                      },
                    ),
                    IconBtn(
                      icon: AppIcons.folder,
                      tooltip: Platform.revealLabel,
                      size: 22,
                      iconSize: 11,
                      onClick: () => Platform.reveal(repo.path),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick Action Buttons Ribbon
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Btn(
                      icon: AppIcons.refresh,
                      label: 'Fetch',
                      height: 26,
                      fontSize: 10.5,
                      onClick: () => _handleSidepaneFetch(repo),
                    ),
                    Btn(
                      icon: Icons.arrow_downward_rounded,
                      label: status.behindCount > 0 ? 'Pull (${status.behindCount})' : 'Pull',
                      height: 26,
                      fontSize: 10.5,
                      onClick: () => _handleSidepanePull(repo),
                    ),
                    Btn(
                      icon: Icons.arrow_upward_rounded,
                      label: status.aheadCount > 0 ? 'Push (${status.aheadCount})' : 'Push',
                      height: 26,
                      fontSize: 10.5,
                      onClick: () => _handleSidepanePush(repo),
                    ),
                    Btn(
                      icon: AppIcons.terminal,
                      label: 'Terminal',
                      height: 26,
                      fontSize: 10.5,
                      onClick: () => widget.state.openTerminal(repo.path, title: repo.name),
                    ),
                    if (repo.linkedProjects.length > 1)
                      Builder(
                        builder: (btnCtx) => Btn(
                          leading: IdeIcon(
                            editor: repo.linkedProjects.first.defaultEditor,
                            size: 14,
                          ),
                          label: 'Open ▾',
                          height: 26,
                          fontSize: 10.5,
                          onClick: () {
                            final box = btnCtx.findRenderObject() as RenderBox?;
                            if (box != null) {
                              final pos = box.localToGlobal(Offset(0, box.size.height + 4));
                              ContextMenu.show(btnCtx, pos, _buildOpenProjectMenuItems(repo));
                            }
                          },
                        ),
                      )
                    else if (repo.linkedProjects.length == 1)
                      Btn(
                        leading: IdeIcon(
                          editor: repo.linkedProjects.first.defaultEditor,
                          size: 14,
                        ),
                        label: 'Open',
                        height: 26,
                        fontSize: 10.5,
                        onClick: () => widget.state.launchProject(repo.linkedProjects.first),
                      )
                    else
                      Btn(
                        leading: IdeIcon(
                          editor: widget.state.settings.defaultEditor,
                          size: 14,
                        ),
                        label: 'Open',
                        height: 26,
                        fontSize: 10.5,
                        onClick: () => IdeService.launchEditor(
                          widget.state.settings.defaultEditor,
                          path: repo.path,
                        ),
                      ),
                    if (status.remoteUrl != null)
                      Btn(
                        icon: AppIcons.external,
                        label: 'Web',
                        height: 26,
                        fontSize: 10.5,
                        onClick: () => Platform.openUrl(status.remoteUrl!),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Tabs Bar
          _buildSidepaneTabs(p, repo),

          // 3. Active Tab View
          Expanded(
            child: switch (_sidepaneTab) {
              RadarSidepaneTab.changes => _buildChangesTab(p, repo),
              RadarSidepaneTab.commits => _buildCommitsTab(p, repo),
              RadarSidepaneTab.branches => _buildBranchesTab(p, repo),
              RadarSidepaneTab.projects => _buildProjectsTab(p, repo),
              RadarSidepaneTab.tools => _buildToolsTab(p, repo),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidepaneTabs(Pal p, RadarRepository repo) {
    final status = repo.status;
    final changeCount = status.modifiedCount + status.stagedCount + status.untrackedCount;

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: p.field.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: p.border, width: 0.5),
          bottom: BorderSide(color: p.border, width: 1),
        ),
      ),
      child: Row(
        children: RadarSidepaneTab.values.map((tab) {
          final isSelected = _sidepaneTab == tab;
          String label = tab.label;
          if (tab == RadarSidepaneTab.changes && changeCount > 0) {
            label = 'Changes ($changeCount)';
          } else if (tab == RadarSidepaneTab.projects) {
            label = 'Projects (${repo.linkedProjects.length})';
          }

          return Expanded(
            child: ClickableNoRipple(
              onClick: () {
                setState(() => _sidepaneTab = tab);
                _loadSidepaneData();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? p.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: T(
                  label,
                  size: 11,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? p.accent : p.muted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Sidepane Tab: Changes & Working Tree ---

  Widget _buildChangesTab(Pal p, RadarRepository repo) {
    final status = repo.status;
    if (status.isClean && (_sidepaneChangedFiles == null || _sidepaneChangedFiles!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 36, color: p.ok),
              const SizedBox(height: 10),
              T('Working tree clean', size: 13, weight: FontWeight.w700, color: p.text),
              const SizedBox(height: 4),
              T('No uncommitted modifications found in ${repo.name}.', size: 11, color: p.muted),
            ],
          ),
        ),
      );
    }

    final files = _sidepaneChangedFiles ?? [];

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        // Quick Commit Section
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.commit, size: 13, color: p.accent),
                      const SizedBox(width: 6),
                      const T('Quick Commit', size: 11.5, weight: FontWeight.w700),
                    ],
                  ),
                  if (status.hasStash)
                    Btn(
                      label: 'Pop Stash',
                      icon: Icons.unarchive_rounded,
                      height: 22,
                      fontSize: 10,
                      onClick: () => _handleSidepanePopStash(repo),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: TextField(
                  controller: _sidepaneCommitCtrl,
                  style: TextStyle(fontSize: 11.5, color: p.text),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Commit message…',
                    hintStyle: TextStyle(fontSize: 11.5, color: p.muted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onSubmitted: (_) => _handleSidepaneCommit(repo),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Btn(
                    label: _isCommitting ? 'Committing…' : 'Commit All',
                    primary: true,
                    height: 26,
                    fontSize: 10.5,
                    onClick: _isCommitting ? null : () => _handleSidepaneCommit(repo),
                  ),
                  Btn(
                    label: 'Stash',
                    icon: Icons.archive_rounded,
                    height: 26,
                    fontSize: 10.5,
                    onClick: () => _handleSidepaneStash(repo),
                  ),
                  Btn(
                    label: 'Discard All…',
                    danger: true,
                    height: 26,
                    fontSize: 10.5,
                    onClick: () async {
                      final ok = await GitService.discardAllChanges(repo.path);
                      if (ok) {
                        widget.state.showToast('Discarded all changes in ${repo.name}');
                        for (final p in repo.linkedProjects) {
                          await widget.state.refreshProjectGit(p);
                        }
                        await _loadSidepaneData(force: true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Diff Viewer (if active)
        if (_diffFilePath != null) ...[
          Row(
            children: [
              Icon(Icons.difference_outlined, size: 12, color: p.accent),
              const SizedBox(width: 4),
              Expanded(
                child: MonoText(
                  'Diff: $_diffFilePath ${_diffIsStaged ? "(staged)" : ""}',
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: p.accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconBtn(
                icon: Icons.close_rounded,
                size: 20,
                iconSize: 12,
                onClick: () => setState(() => _diffFilePath = null),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildDiffViewer(p),
          const SizedBox(height: 12),
        ],

        // Changed Files Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            T('Changed Files (${files.length})', size: 11.5, weight: FontWeight.w700, color: p.text),
            if (_loadingChangedFiles)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
          ],
        ),
        const SizedBox(height: 6),

        // Changed Files List
        for (final file in files) ...[
          _buildChangedFileItem(p, repo, file),
        ],
      ],
    );
  }

  Widget _buildChangedFileItem(Pal p, RadarRepository repo, GitChangedFile file) {
    Color statusCol;
    String statusLetter = file.status;
    if (file.status == 'M') {
      statusCol = p.warn;
    } else if (file.status == 'A' || file.isStaged) {
      statusCol = p.ok;
    } else if (file.status == 'D') {
      statusCol = p.err;
    } else {
      statusCol = p.muted;
    }

    final segments = file.path.split(RegExp(r'[\\/]'));
    final fileName = segments.last;
    final dirPath = segments.length > 1 ? segments.sublist(0, segments.length - 1).join('/') : '';
    final isDiffOpen = _diffFilePath == file.path && _diffIsStaged == file.isStaged;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDiffOpen ? p.accent.withOpacity(0.08) : p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDiffOpen ? p.accent.withOpacity(0.4) : p.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusCol.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: MonoText(
              statusLetter,
              size: 9.5,
              weight: FontWeight.w800,
              color: statusCol,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(fileName, size: 11, weight: FontWeight.w600, color: p.text),
                if (dirPath.isNotEmpty)
                  MonoText(dirPath, size: 9, color: p.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Diff button
          IconBtn(
            icon: Icons.difference_outlined,
            tooltip: isDiffOpen ? 'Hide diff' : 'View diff',
            size: 24,
            iconSize: 13,
            onClick: () => _handleViewDiff(repo, file),
          ),
          // Stage / unstage toggle
          IconBtn(
            icon: file.isStaged ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
            tooltip: file.isStaged ? 'Unstage' : 'Stage',
            size: 24,
            iconSize: 13,
            onClick: () => _handleToggleStageFile(repo, file),
          ),
          // Discard button
          IconBtn(
            icon: AppIcons.delete,
            tooltip: 'Discard changes',
            size: 24,
            iconSize: 13,
            color: p.err,
            onClick: () => _handleDiscardFile(repo, file),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffViewer(Pal p) {
    if (_loadingDiff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final content = _diffContent ?? '';
    if (content.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(6)),
        child: T('No diff output (untracked or binary file)', size: 11, color: p.muted),
      );
    }
    final lines = content.split('\n');
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: lines.map((line) {
            Color lineCol = p.text;
            Color bgCol = Colors.transparent;
            if (line.startsWith('+') && !line.startsWith('+++')) {
              lineCol = p.ok;
              bgCol = p.ok.withOpacity(0.08);
            } else if (line.startsWith('-') && !line.startsWith('---')) {
              lineCol = p.err;
              bgCol = p.err.withOpacity(0.08);
            } else if (line.startsWith('@@')) {
              lineCol = p.accent;
              bgCol = p.accent.withOpacity(0.06);
            }
            return Container(
              color: bgCol,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: MonoText(line, size: 10, color: lineCol),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Sidepane Tab: Commits History ---

  Widget _buildCommitsTab(Pal p, RadarRepository repo) {
    if (_loadingCommits) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final commits = _sidepaneCommits ?? [];
    if (commits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: T('No recent commits found', size: 12, color: p.muted),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: commits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = commits[idx];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClickableNoRipple(
                    onClick: () {
                      Platform.copy(c.hash);
                      widget.state.showToast('Copied hash "${c.hash}"');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: p.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: MonoText(c.hash, size: 10, weight: FontWeight.w700, color: p.accent),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (c.author.isNotEmpty)
                    T(c.author, size: 10.5, weight: FontWeight.w600, color: p.text.withOpacity(0.9)),
                  const Spacer(),
                  if (c.date != null)
                    T(_formatRelativeDate(c.date!), size: 10, color: p.muted),
                ],
              ),
              const SizedBox(height: 4),
              T(c.message, size: 11, color: p.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  // --- Sidepane Tab: Branches ---

  Widget _buildBranchesTab(Pal p, RadarRepository repo) {
    if (_loadingBranches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final branches = _sidepaneBranches ?? [];
    final current = repo.status.branch;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            T('Branches (${branches.length})', size: 11.5, weight: FontWeight.w700, color: p.text),
            Btn(
              icon: Icons.add,
              label: 'New Branch',
              height: 26,
              fontSize: 10.5,
              onClick: () => _handleCreateBranch(repo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in branches) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: b == current ? p.accent.withOpacity(0.08) : p.field,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: b == current ? p.accent.withOpacity(0.3) : p.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.branch, size: 13, color: b == current ? p.accent : p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: T(
                    b,
                    size: 11.5,
                    weight: b == current ? FontWeight.w700 : FontWeight.w500,
                    color: b == current ? p.accent : p.text,
                  ),
                ),
                if (b == current)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: T('Active', size: 9.5, weight: FontWeight.w700, color: p.accent),
                  )
                else
                  Btn(
                    label: 'Checkout',
                    height: 22,
                    fontSize: 10,
                    onClick: () => _handleCheckoutBranch(repo, b),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Sidepane Tab: Projects ---

  Widget _buildProjectsTab(Pal p, RadarRepository repo) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        T('Linked Workspace Projects (${repo.linkedProjects.length})', size: 11.5, weight: FontWeight.w700, color: p.text),
        const SizedBox(height: 8),
        for (final proj in repo.linkedProjects) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TechBadge(
                      label: proj.techStack.label,
                      color: proj.techStack.color,
                      stack: proj.techStack,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: T(proj.name, size: 12, weight: FontWeight.w700, color: p.text),
                    ),
                    Btn(
                      leading: IdeIcon(
                        editor: proj.defaultEditor,
                        size: 13,
                      ),
                      label: 'Open',
                      height: 24,
                      fontSize: 10.5,
                      onClick: () => widget.state.launchProject(proj),
                    ),
                    const SizedBox(width: 4),
                    Btn(
                      icon: AppIcons.terminal,
                      label: 'Terminal',
                      height: 24,
                      fontSize: 10.5,
                      onClick: () => widget.state.openTerminal(proj.path, title: proj.name),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MonoText(proj.path, size: 9.5, color: p.muted),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Sidepane Tab: Git Tools ---

  Widget _buildToolsTab(Pal p, RadarRepository repo) {
    final status = repo.status;
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        T('Repository Quick Tools', size: 11.5, weight: FontWeight.w700, color: p.text),
        const SizedBox(height: 8),
        _buildToolTile(
          p,
          icon: Icons.cleaning_services_rounded,
          title: 'Fetch & Prune',
          subtitle: 'Fetch remote branches and prune deleted remote-tracking references',
          btnLabel: 'Run Prune',
          onAction: () => _handleFetchPrune(repo),
        ),
        _buildToolTile(
          p,
          icon: Icons.delete_sweep_rounded,
          title: 'Clean Untracked Files',
          subtitle: 'Permanently remove all untracked files and directories (git clean -fd)',
          btnLabel: 'Clean',
          danger: true,
          onAction: () => _handleCleanUntracked(repo),
        ),
        if (status.remoteUrl != null)
          _buildToolTile(
            p,
            icon: AppIcons.external,
            title: 'Open in Browser',
            subtitle: status.remoteUrl!,
            btnLabel: 'Open Web',
            onAction: () => Platform.openUrl(status.remoteUrl!),
          ),
        _buildToolTile(
          p,
          icon: AppIcons.terminal,
          title: 'Terminal at Repo Root',
          subtitle: repo.path,
          btnLabel: 'Terminal',
          onAction: () => widget.state.openTerminal(repo.path, title: repo.name),
        ),
        _buildToolTile(
          p,
          icon: AppIcons.folder,
          title: Platform.revealLabel,
          subtitle: 'Open repository root in system file manager',
          btnLabel: 'Reveal',
          onAction: () => Platform.reveal(repo.path),
        ),
        _buildToolTile(
          p,
          icon: AppIcons.copy,
          title: 'Copy Git Info',
          subtitle: 'Branch: ${status.branch} | Commit: ${status.lastCommitHash ?? 'N/A'}',
          btnLabel: 'Copy All',
          onAction: () {
            final info = 'Repo: ${repo.name}\nPath: ${repo.path}\nBranch: ${status.branch}\nCommit: ${status.lastCommitHash ?? ''}\nRemote: ${status.remoteUrl ?? 'none'}';
            Platform.copy(info);
            widget.state.showToast('Copied Git summary to clipboard');
          },
        ),
      ],
    );
  }

  Widget _buildToolTile(
    Pal p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onAction,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: danger ? p.err : p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(title, size: 11.5, weight: FontWeight.w700, color: p.text),
                const SizedBox(height: 2),
                T(subtitle, size: 10, color: p.muted, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Btn(
            label: btnLabel,
            height: 26,
            fontSize: 10.5,
            danger: danger,
            onClick: onAction,
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
