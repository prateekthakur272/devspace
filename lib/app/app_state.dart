import 'dart:async';
import 'dart:io' hide Platform;
import 'package:flutter/widgets.dart';
import 'package:devspace/app/modal.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/ide/ide_service.dart';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/note_markdown.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/core/terminal/terminal_controller.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';
import 'package:devspace/core/tools/tool_detection_service.dart';
import 'package:devspace/platform/platform.dart';

export 'package:devspace/app/modal.dart';

class AppState with ChangeNotifier {
  AppState() {
    _init();
  }

  static const String _tag = 'app_state';

  List<Project> _projects = [];
  List<WorkspaceGroup> _workspaces = [];
  List<Note> _notes = [];
  AppSettings _settings = const AppSettings();
  SavedState _uiState = const SavedState();

  final Map<String, GitRepoStatus> _gitStatuses = {};
  final Map<String, bool> _gitLoading = {};

  List<EditorType> _availableEditors = [EditorType.vscode];
  List<DetectedTool> _detectedTools = [];
  List<DesktopApp> _installedDesktopApps = [];
  bool _toolsScanning = false;

  AppModal? _modal;
  bool _paletteOpen = false;
  Timer? _gitPollTimer;
  String? _availableUpdate;
  String? _toast;
  Timer? _toastTimer;
  late final TerminalController terminalController;

  // Getters
  List<Project> get projects => List.unmodifiable(_projects);
  List<WorkspaceGroup> get workspaces => List.unmodifiable(_workspaces);
  List<Note> get notes => List.unmodifiable(_notes);
  AppSettings get settings => _settings;
  SavedState get uiState => _uiState;
  Map<String, GitRepoStatus> get gitStatuses => Map.unmodifiable(_gitStatuses);
  Map<String, bool> get gitLoading => Map.unmodifiable(_gitLoading);
  GitRepoStatus? gitStatusFor(String projectId) => _gitStatuses[projectId];
  bool isGitLoading(String projectId) => _gitLoading[projectId] ?? false;
  List<EditorType> get availableEditors => List.unmodifiable(_availableEditors);
  List<DetectedTool> get detectedTools => List.unmodifiable(_detectedTools);
  List<DesktopApp> get installedDesktopApps => List.unmodifiable(_installedDesktopApps);
  bool get toolsScanning => _toolsScanning;

  AppModal? get modal => _modal;
  set modal(AppModal? m) {
    _modal = m;
    notifyListeners();
  }

  final Set<String> _testingStatusOverrides = {};

  @visibleForTesting
  void setGitStatusForTesting(String projectId, GitRepoStatus status) {
    _testingStatusOverrides.add(projectId);
    _gitStatuses[projectId] = status;
    notifyListeners();
  }

  bool get paletteOpen => _paletteOpen;
  set paletteOpen(bool open) {
    _paletteOpen = open;
    notifyListeners();
  }

  /// Non-null when a newer GitHub release has been detected.
  String? get availableUpdate => _availableUpdate;
  set availableUpdate(String? v) {
    if (_availableUpdate != v) {
      _availableUpdate = v;
      notifyListeners();
    }
  }

  /// Transient feedback toast.
  String? get toast => _toast;
  set toast(String? v) {
    _toast = v;
    notifyListeners();
  }

  void showToast(String msg) {
    toast = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 3500), () => toast = null);
  }

  void _init() {
    _settings = AppStore.loadSettings();
    _projects = AppStore.loadProjects().toList();
    _workspaces = AppStore.loadWorkspaces().toList();
    _notes = AppStore.loadNotes().where((n) => !n.isEmpty).toList();
    _uiState = AppStore.loadState();
    terminalController = TerminalController();
    terminalController.addListener(notifyListeners);
    terminalController.onAllSessionsClosed = () {
      if (_uiState.terminalVisible) {
        toggleTerminal(false);
      }
    };

    // Start background git status polling
    _scheduleGitPolling();

    // Initial git status check across all projects
    refreshAllGit();

    // Auto-detect installed editors and developer tools
    refreshDetectedTools();

    // Launch initial onboarding tour on first run
    if (AppStore.needsOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        modal = const ModalOnboarding();
      });
    }
  }

  Future<void> refreshDetectedTools() async {
    _toolsScanning = true;
    notifyListeners();

    try {
      final editors = await IdeService.detectAll();
      final tools = await ToolDetectionService.detectAllTools();
      final apps = await DesktopAppService.detectAll();

      _availableEditors = editors.keys.where((e) => e != EditorType.custom).toList();
      if (_availableEditors.isEmpty) _availableEditors = [EditorType.vscode];
      _detectedTools = tools;
      _installedDesktopApps = apps;

      // Extract and cache real application icons from installed OS apps
      await AppIconService.extractAllInstalled(
        editors: _availableEditors,
        desktopApps: _installedDesktopApps,
      );
      for (final a in _settings.pinnedApps) {
        await _extractPinnedIcon(a);
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed auto-detecting tools', e, st);
    } finally {
      _toolsScanning = false;
      notifyListeners();
    }
  }

  void _scheduleGitPolling() {
    _gitPollTimer?.cancel();
    _gitPollTimer = null;
    if (_settings.gitRefreshIntervalSeconds <= 0) {
      Log.info(_tag, 'Git background polling disabled (none)');
      return;
    }
    final interval = Duration(
      seconds: _settings.gitRefreshIntervalSeconds.clamp(10, 300),
    );
    _gitPollTimer = Timer.periodic(interval, (_) => refreshAllGit());
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    AppStore.saveSettings(_settings);
    _scheduleGitPolling();
    notifyListeners();
  }

  List<PinnedApp> get pinnedApps => _settings.pinnedApps;

  /// Pins an application (a `.app` bundle on macOS, an executable elsewhere)
  /// to the tools rail and caches its icon.
  Future<void> pinApp(String path) async {
    final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    var name = trimmed.split(RegExp(r'[\\/]')).last;
    name = name.replaceFirst(RegExp(r'\.(app|exe|lnk)$', caseSensitive: false), '');
    if (name.isEmpty) return;

    final already = _settings.pinnedApps.any((a) => a.path == trimmed) ||
        _installedDesktopApps.any((a) => a.resolvedPath == trimmed);
    if (already) {
      toast = '$name is already on the rail';
      return;
    }
    final app = PinnedApp(name: name, path: trimmed);
    updateSettings(_settings.copyWith(pinnedApps: [..._settings.pinnedApps, app]));
    await _extractPinnedIcon(app);
    notifyListeners();
  }

  void unpinApp(String path) {
    updateSettings(_settings.copyWith(
      pinnedApps: _settings.pinnedApps.where((a) => a.path != path).toList(),
    ));
  }

  Future<void> _extractPinnedIcon(PinnedApp app) async {
    try {
      await AppIconService.extractAppIcon(app.path, app.name);
    } catch (e, st) {
      Log.warning(_tag, 'Could not extract icon for ${app.name}', e, st);
    }
  }

  void toggleToolsRail() {
    updateSettings(_settings.copyWith(showToolsRail: !_settings.showToolsRail));
  }

  void updateUiState(SavedState Function(SavedState current) update) {
    _uiState = update(_uiState);
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  void persist() {
    AppStore.saveProjects(_projects);
    AppStore.saveWorkspaces(_workspaces);
    AppStore.saveSettings(_settings);
    AppStore.saveState(_uiState);
    Log.info(_tag, 'State flushed to disk successfully');
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _gitPollTimer?.cancel();
    _toastTimer?.cancel();
    terminalController.removeListener(notifyListeners);
    terminalController.dispose();
    super.dispose();
  }

  // --- Project Actions ---

  Future<void> addProject({
    required String path,
    String? name,
    EditorType? defaultEditor,
    String? workspaceId,
    List<String>? tags,
  }) async {
    final finalName = name != null && name.trim().isNotEmpty
        ? name.trim()
        : path.split(RegExp(r'[\\/]')).lastWhere((e) => e.isNotEmpty, orElse: () => 'Project');

    final detectedStack = TechStack.detect(path);
    final editor = defaultEditor ?? _settings.defaultEditor;

    final newProject = Project(
      id: 'proj_${DateTime.now().microsecondsSinceEpoch}',
      name: finalName,
      path: path,
      techStack: detectedStack,
      defaultEditor: editor,
      workspaceId: workspaceId ?? 'default',
      tags: tags ?? [],
      createdAt: DateTime.now(),
    );

    _projects.add(newProject);
    AppStore.saveProjects(_projects);
    notifyListeners();

    // Check git immediately for new project
    await refreshProjectGit(newProject);
  }

  Future<int> scanAndImportWorkspace(String parentDirectoryPath) async {
    final dir = Directory(parentDirectoryPath);
    if (!dir.existsSync()) return 0;

    int importedCount = 0;
    try {
      final entries = dir.listSync(followLinks: false);
      for (final entry in entries) {
        if (entry is Directory) {
          final alreadyAdded = _projects.any((p) => p.path == entry.path);
          if (alreadyAdded) continue;

          final isRepo = Directory('${entry.path}/.git').existsSync();
          final isProject = isRepo ||
              File('${entry.path}/pubspec.yaml').existsSync() ||
              File('${entry.path}/package.json').existsSync() ||
              File('${entry.path}/Cargo.toml').existsSync() ||
              File('${entry.path}/go.mod').existsSync() ||
              File('${entry.path}/pom.xml').existsSync() ||
              File('${entry.path}/build.gradle').existsSync();

          if (isProject) {
            await addProject(path: entry.path);
            importedCount++;
          }
        }
      }
    } catch (e, st) {
      Log.warning(_tag, 'Error scanning directory $parentDirectoryPath', e, st);
    }
    return importedCount;
  }

  void updateProject(Project updated) {
    final idx = _projects.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _projects[idx] = updated;
      AppStore.saveProjects(_projects);
      notifyListeners();
    }
  }

  void removeProject(String projectId) {
    _projects.removeWhere((p) => p.id == projectId);
    _gitStatuses.remove(projectId);
    _gitLoading.remove(projectId);
    AppStore.saveProjects(_projects);
    notifyListeners();
  }

  void togglePin(String projectId) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      final p = _projects[idx];
      _projects[idx] = p.copyWith(pinned: !p.pinned);
      AppStore.saveProjects(_projects);
      notifyListeners();
    }
  }

  // --- Workspace Group Actions ---

  void addWorkspaceGroup({required String name, Color? color, IconData? icon}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = 'ws_${DateTime.now().microsecondsSinceEpoch}';
    final newGroup = WorkspaceGroup(
      id: id,
      name: trimmed,
      color: color ?? const Color(0xFF6750A4),
      icon: icon,
    );

    _workspaces.add(newGroup);
    AppStore.saveWorkspaces(_workspaces);
    _uiState = _uiState.copyWith(selectedWorkspaceId: id);
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  void updateWorkspaceGroup(WorkspaceGroup updated) {
    final idx = _workspaces.indexWhere((w) => w.id == updated.id);
    if (idx != -1) {
      _workspaces[idx] = updated;
      AppStore.saveWorkspaces(_workspaces);
      notifyListeners();
    }
  }

  void removeWorkspaceGroup(String id) {
    if (id == 'default') return; // Protect default General group

    bool projectsModified = false;
    for (int i = 0; i < _projects.length; i++) {
      if (_projects[i].workspaceId == id) {
        _projects[i] = _projects[i].copyWith(workspaceId: 'default');
        projectsModified = true;
      }
    }
    if (projectsModified) {
      AppStore.saveProjects(_projects);
    }

    _workspaces.removeWhere((w) => w.id == id);
    AppStore.saveWorkspaces(_workspaces);

    if (_uiState.selectedWorkspaceId == id) {
      _uiState = _uiState.copyWith(selectedWorkspaceId: 'all');
      AppStore.saveState(_uiState);
    }

    notifyListeners();
  }

  void moveProjectToWorkspace(String projectId, String targetWorkspaceId) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx] = _projects[idx].copyWith(workspaceId: targetWorkspaceId);
      AppStore.saveProjects(_projects);
      notifyListeners();
    }
  }

  Future<void> launchProject(Project project, {EditorType? overrideEditor}) async {
    final success = await IdeService.openProject(
      project,
      overrideEditor: overrideEditor,
    );
    if (success) {
      updateProject(project.copyWith(lastOpenedAt: DateTime.now()));
    }
  }

  // --- Git Health Actions ---

  String get gitRadarFilter => _uiState.gitRadarFilter;
  String? get gitRadarRemoteFilter => _uiState.gitRadarRemoteFilter;
  String? get gitRadarBranchFilter => _uiState.gitRadarBranchFilter;
  String? get selectedGitRepoPath => _uiState.selectedGitRepoPath;

  void setGitRadarFilter(String filter) {
    updateUiState((s) => s.copyWith(
      gitRadarFilter: filter,
      clearGitRadarRemoteFilter: true,
      clearGitRadarBranchFilter: true,
    ));
  }

  void setGitRadarRemoteFilter(String? remote) {
    updateUiState((s) => s.copyWith(
      gitRadarFilter: 'all',
      gitRadarRemoteFilter: remote,
      clearGitRadarRemoteFilter: remote == null,
      clearGitRadarBranchFilter: true,
    ));
  }

  void setGitRadarBranchFilter(String? branch) {
    updateUiState((s) => s.copyWith(
      gitRadarFilter: 'all',
      clearGitRadarRemoteFilter: true,
      gitRadarBranchFilter: branch,
      clearGitRadarBranchFilter: branch == null,
    ));
  }

  void setSelectedGitRepoPath(String? path) {
    updateUiState((s) => s.copyWith(
      selectedGitRepoPath: path,
      clearSelectedGitRepoPath: path == null,
    ));
  }

  List<RadarRepository> get radarRepositories {
    final Map<String, RadarRepository> repoMap = {};
    for (final pr in _projects) {
      final s = _gitStatuses[pr.id];
      if (s == null || !s.isGitRepo) continue;
      final repoPath = s.repoRoot ?? pr.path;
      if (repoMap.containsKey(repoPath)) {
        repoMap[repoPath]!.linkedProjects.add(pr);
      } else {
        final segments = repoPath.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty).toList();
        final repoName = segments.isNotEmpty ? segments.last : pr.name;
        repoMap[repoPath] = RadarRepository(
          path: repoPath,
          name: repoName,
          status: s,
          linkedProjects: [pr],
        );
      }
    }
    return repoMap.values.toList();
  }

  Future<void> refreshAllGit() async {
    for (final p in _projects) {
      refreshProjectGit(p);
    }
  }

  Future<void> refreshProjectGit(Project project) async {
    if (_testingStatusOverrides.contains(project.id)) {
      return;
    }
    _gitLoading[project.id] = true;
    notifyListeners();

    final status = await GitService.checkStatus(project.path);
    if (_testingStatusOverrides.contains(project.id)) {
      _gitLoading[project.id] = false;
      return;
    }
    _gitStatuses[project.id] = status;
    _gitLoading[project.id] = false;
    notifyListeners();
  }

  // Filtered projects
  List<Project> get filteredProjects {
    var list = _projects;

    // Filter by workspace
    if (_uiState.selectedWorkspaceId != 'all') {
      if (_uiState.selectedWorkspaceId == 'pinned') {
        list = list.where((p) => p.pinned).toList();
      } else if (_uiState.selectedWorkspaceId == 'dirty') {
        list = list.where((p) {
          final s = _gitStatuses[p.id];
          return s != null && s.isDirty;
        }).toList();
      } else {
        list = list
            .where((p) => p.workspaceId == _uiState.selectedWorkspaceId)
            .toList();
      }
    }

    // Filter by tag
    if (_uiState.activeTagFilter != null && _uiState.activeTagFilter!.isNotEmpty) {
      list = list.where((p) => p.tags.contains(_uiState.activeTagFilter)).toList();
    }

    // Filter by search query
    if (_uiState.searchQuery.trim().isNotEmpty) {
      final q = _uiState.searchQuery.trim().toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.path.toLowerCase().contains(q) ||
            p.techStack.label.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // Sort projects
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;

      return switch (_uiState.sortBy) {
        ProjectSortOption.lastOpened => () {
          if (a.lastOpenedAt != null && b.lastOpenedAt != null) {
            return b.lastOpenedAt!.compareTo(a.lastOpenedAt!);
          }
          if (a.lastOpenedAt != null) return -1;
          if (b.lastOpenedAt != null) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }(),
        ProjectSortOption.nameAsc =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ProjectSortOption.nameDesc =>
          b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        ProjectSortOption.recentlyAdded =>
          b.createdAt.compareTo(a.createdAt),
        ProjectSortOption.gitStatus => () {
          final aDirty = _gitStatuses[a.id]?.isDirty ?? false;
          final bDirty = _gitStatuses[b.id]?.isDirty ?? false;
          if (aDirty != bDirty) return aDirty ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }(),
      };
    });

    return list;
  }

  // --- Notes Management ---

  void addNote(Note note) {
    if (note.isEmpty) return;
    _notes.insert(0, note);
    AppStore.saveNotes(_notes);
    notifyListeners();
  }

  void updateNote(Note updated) {
    if (updated.isEmpty) {
      deleteNote(updated.id);
      return;
    }
    final idx = _notes.indexWhere((n) => n.id == updated.id);
    if (idx != -1) {
      _notes[idx] = updated.copyWith(updatedAt: DateTime.now());
      if (_paneEditingNote?.id == updated.id) {
        _paneEditingNote = _notes[idx];
      }
      AppStore.saveNotes(_notes);
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    if (_paneEditingNote?.id == id) {
      _paneEditingNote = null;
      _paneCreatingNote = false;
    }
    AppStore.saveNotes(_notes);
    notifyListeners();
  }

  void togglePinNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final note = _notes[idx];
      _notes[idx] = note.copyWith(
        pinned: !note.pinned,
        updatedAt: DateTime.now(),
      );
      AppStore.saveNotes(_notes);
      notifyListeners();
    }
  }

  void toggleChecklistItem(String noteId, String itemId) {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      final note = _notes[idx];
      // Keep the markdown body (source of truth for the editor) in sync.
      var content = note.content;
      final ci = note.checklist.indexWhere((c) => c.id == itemId);
      if (ci >= 0 &&
          NoteMarkdown.todoLineCount(content) == note.checklist.length) {
        content = NoteMarkdown.toggleTodoLine(content, ci) ?? content;
      }
      final newChecklist = note.checklist.map((item) {
        if (item.id == itemId) {
          return item.copyWith(checked: !item.checked);
        }
        return item;
      }).toList();
      _notes[idx] = note.copyWith(
        content: content,
        checklist: newChecklist,
        updatedAt: DateTime.now(),
      );
      AppStore.saveNotes(_notes);
      notifyListeners();
    }
  }

  List<Note> getNotesForProject(String projectId) {
    return _notes.where((n) => n.projectIds.contains(projectId)).toList();
  }

  void toggleNotesPane() {
    _uiState = _uiState.copyWith(notesPaneVisible: !_uiState.notesPaneVisible);
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  void setNotesPaneWidth(double w) {
    _uiState = _uiState.copyWith(notesPaneWidth: w);
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  bool get terminalVisible => _uiState.terminalVisible;
  double get terminalHeight => _uiState.terminalHeight;

  void toggleTerminal([bool? visible]) {
    final nextVisible = visible ?? !_uiState.terminalVisible;
    if (nextVisible && terminalController.sessions.isEmpty) {
      terminalController.createSession();
    }
    _uiState = _uiState.copyWith(
      terminalVisible: nextVisible,
    );
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  void closeAllTerminals() {
    terminalController.closeAllSessions();
  }

  void setTerminalHeight(double h) {
    _uiState = _uiState.copyWith(
      terminalHeight: h.clamp(140.0, 600.0),
    );
    AppStore.saveState(_uiState);
    notifyListeners();
  }

  void openTerminal(String dirPath, {String? title}) {
    if (settings.defaultTerminal == DefaultTerminalType.system) {
      Platform.openInTerminal(dirPath);
    } else {
      _uiState = _uiState.copyWith(terminalVisible: true);
      AppStore.saveState(_uiState);
      terminalController.openDirectory(dirPath, title: title);
      notifyListeners();
    }
  }

  void openIntegratedTerminal(String dirPath, {String? title}) {
    _uiState = _uiState.copyWith(terminalVisible: true);
    AppStore.saveState(_uiState);
    terminalController.openDirectory(dirPath, title: title);
    notifyListeners();
  }

  void openSystemTerminal(String dirPath) {
    Platform.openInTerminal(dirPath);
  }

  void openTerminalInProject(Project project) {
    openTerminal(project.path, title: project.name);
  }

  // --- In-Pane Note Editor State ---
  Note? _paneEditingNote;
  bool _paneCreatingNote = false;
  String? _paneInitialProjectId;
  String? _paneInitialTag;
  bool _paneInitialChecklist = false;

  Note? get paneEditingNote => _paneEditingNote;
  bool get paneCreatingNote => _paneCreatingNote;
  String? get paneInitialProjectId => _paneInitialProjectId;
  String? get paneInitialTag => _paneInitialTag;
  bool get paneInitialChecklist => _paneInitialChecklist;

  void openNoteInPane(Note note) {
    _paneEditingNote = note;
    _paneCreatingNote = false;
    _paneInitialProjectId = null;
    _paneInitialTag = null;
    _paneInitialChecklist = false;
    if (!_uiState.notesPaneVisible) {
      _uiState = _uiState.copyWith(notesPaneVisible: true);
      AppStore.saveState(_uiState);
    }
    notifyListeners();
  }

  void openNewNoteInPane({
    String? initialProjectId,
    String? initialTag,
    bool initialChecklist = false,
  }) {
    _paneEditingNote = null;
    _paneCreatingNote = true;
    _paneInitialProjectId = initialProjectId;
    _paneInitialTag = initialTag;
    _paneInitialChecklist = initialChecklist;
    if (!_uiState.notesPaneVisible) {
      _uiState = _uiState.copyWith(notesPaneVisible: true);
      AppStore.saveState(_uiState);
    }
    notifyListeners();
  }

  void closePaneNoteEditor() {
    _paneEditingNote = null;
    _paneCreatingNote = false;
    _paneInitialProjectId = null;
    _paneInitialTag = null;
    _paneInitialChecklist = false;
    notifyListeners();
  }
}
