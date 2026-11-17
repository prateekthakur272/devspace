import 'dart:io';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/utils/json.dart';
import 'package:devspace/utils/paths.dart';
import 'package:path/path.dart' as p;

class AppStore {
  AppStore._();

  static const String _tag = 'storage';

  /// Override of the data directory; set before first use (tests).
  static String? homeOverride;

  static String? _dirCache;
  static String? _dirCacheKey;

  static String get dir {
    final key = homeOverride ?? '';
    if (_dirCache != null && _dirCacheKey == key) return _dirCache!;
    final String d;
    if (homeOverride != null) {
      d = homeOverride!;
    } else {
      d = Paths.dataDir;
    }
    Directory(d).createSync(recursive: true);
    Log.writeTo(Paths.logFile(d));
    _dirCache = d;
    _dirCacheKey = key;
    return d;
  }

  static String get _settingsFile => p.join(dir, 'settings.json');
  static String get _projectsFile => p.join(dir, 'projects.json');
  static String get _workspacesFile => p.join(dir, 'workspaces.json');
  static String get _notesFile => p.join(dir, 'notes.json');
  static String get _stateFile => p.join(dir, 'state.json');

  /// True when nothing has been saved yet: a fresh installation.
  static bool isFirstRun() =>
      !File(_settingsFile).existsSync() && !File(_projectsFile).existsSync();

  // Settings
  static AppSettings loadSettings() {
    try {
      final f = File(_settingsFile);
      if (!f.existsSync()) return const AppSettings();
      final data = Json.obj(Json.parse(f.readAsStringSync()));
      return AppSettings.fromJson(data);
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load settings', e, st);
      return const AppSettings();
    }
  }

  static void saveSettings(AppSettings settings) {
    try {
      File(_settingsFile).writeAsStringSync(
        Json.encode(settings.toJson(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save settings', e, st);
    }
  }

  // Projects
  static List<Project> loadProjects() {
    try {
      final f = File(_projectsFile);
      if (!f.existsSync()) return [];
      final list = Json.list(Json.parse(f.readAsStringSync()));
      if (list == null) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load projects', e, st);
      return [];
    }
  }

  static void saveProjects(List<Project> projects) {
    try {
      File(_projectsFile).writeAsStringSync(
        Json.encode(projects.map((p) => p.toJson()).toList(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save projects', e, st);
    }
  }

  // Workspaces
  static List<WorkspaceGroup> loadWorkspaces() {
    try {
      final f = File(_workspacesFile);
      if (!f.existsSync()) {
        return [
          const WorkspaceGroup(id: 'default', name: 'General'),
          const WorkspaceGroup(id: 'work', name: 'Work'),
          const WorkspaceGroup(id: 'personal', name: 'Personal'),
          const WorkspaceGroup(id: 'open_source', name: 'Open Source'),
        ];
      }
      final list = Json.list(Json.parse(f.readAsStringSync()));
      if (list == null) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(WorkspaceGroup.fromJson)
          .toList();
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load workspaces', e, st);
      return [const WorkspaceGroup(id: 'default', name: 'General')];
    }
  }

  static void saveWorkspaces(List<WorkspaceGroup> workspaces) {
    try {
      File(_workspacesFile).writeAsStringSync(
        Json.encode(workspaces.map((w) => w.toJson()).toList(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save workspaces', e, st);
    }
  }

  // Notes
  static List<Note> loadNotes() {
    try {
      final f = File(_notesFile);
      if (!f.existsSync()) return [];
      final list = Json.list(Json.parse(f.readAsStringSync()));
      if (list == null) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load notes', e, st);
      return [];
    }
  }

  static void saveNotes(List<Note> notes) {
    try {
      File(_notesFile).writeAsStringSync(
        Json.encode(notes.map((n) => n.toJson()).toList(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save notes', e, st);
    }
  }

  // UI State
  static SavedState loadState() {
    try {
      final f = File(_stateFile);
      if (!f.existsSync()) return const SavedState();
      final data = Json.obj(Json.parse(f.readAsStringSync()));
      return SavedState.fromJson(data);
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load UI state', e, st);
      return const SavedState();
    }
  }

  static void saveState(SavedState state) {
    try {
      File(_stateFile).writeAsStringSync(
        Json.encode(state.toJson(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save UI state', e, st);
    }
  }

  // Window geometry convenience
  static WindowGeometry? loadWindow() => loadState().window;

  static void saveWindow(WindowGeometry window) {
    final cur = loadState();
    saveState(cur.copyWith(window: window));
  }
}
