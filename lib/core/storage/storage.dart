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
  static String get _projectsDir => p.join(dir, 'projects');
  static String get _workspacesFile => p.join(dir, 'workspaces.json');
  static String get _notesFile => p.join(dir, 'notes.json');
  static String get _notesDir => p.join(dir, 'notes');
  static String get _stateFile => p.join(dir, 'state.json');
  static String get _prefsFile => p.join(dir, 'prefs.json');

  /// Directory holding individual project JSON files.
  static String get projectsDir {
    final d = _projectsDir;
    Directory(d).createSync(recursive: true);
    return d;
  }

  /// Directory holding individual note JSON files.
  static String get notesDir {
    final d = _notesDir;
    Directory(d).createSync(recursive: true);
    return d;
  }

  static String _safeFilename(String id) {
    final safe = id.replaceAll(RegExp(r'[^\w-]'), '_');
    return safe.isEmpty ? 'item' : safe;
  }

  /// True when nothing has been saved yet: a fresh installation.
  static bool isFirstRun() {
    if (File(_settingsFile).existsSync()) return false;
    if (File(_projectsFile).existsSync()) return false;
    final projDir = Directory(_projectsDir);
    if (projDir.existsSync() &&
        projDir.listSync().any((e) => e.path.endsWith('.json'))) {
      return false;
    }
    return true;
  }

  /// True when the user hasn't completed initial onboarding yet.
  static bool get needsOnboarding {
    final done = flag('onboarding_completed') == true;
    if (done) return false;
    return isFirstRun();
  }

  static Map<String, dynamic> _loadFlags() {
    try {
      final f = File(_prefsFile);
      if (!f.existsSync()) return <String, dynamic>{};
      final parsed = Json.parse(f.readAsStringSync());
      return Json.obj(parsed) ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// A small named value the app remembers (e.g. dismissed update version).
  static Object? flag(String key) => _loadFlags()[key];

  /// [flag] when it holds a string, else null.
  static String? flagString(String key) {
    final v = flag(key);
    return v is String ? v : null;
  }

  /// Saves a flag; a null [value] removes it.
  static void setFlag(String key, Object? value) {
    final m = _loadFlags();
    if (value == null) {
      if (m.remove(key) == null && !File(_prefsFile).existsSync()) return;
    } else {
      m[key] = value;
    }
    try {
      File(_prefsFile).writeAsStringSync(
        Json.encode(m, pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save flags', e, st);
    }
  }

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
      final d = Directory(_projectsDir);
      if (d.existsSync()) {
        final files = d
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList();
        if (files.isNotEmpty) {
          final projects = <Project>[];
          for (final f in files) {
            try {
              final parsed = Json.parse(f.readAsStringSync());
              final obj = Json.obj(parsed);
              if (obj != null) {
                projects.add(Project.fromJson(obj));
              }
            } catch (e, st) {
              Log.warning(_tag, 'Failed to parse project file: ${f.path}', e, st);
            }
          }
          projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return projects;
        }
      }

      // Migration fallback: check legacy single file projects.json
      final legacyFile = File(_projectsFile);
      if (legacyFile.existsSync()) {
        final list = Json.list(Json.parse(legacyFile.readAsStringSync()));
        if (list != null) {
          final legacyProjects = list
              .whereType<Map<String, dynamic>>()
              .map(Project.fromJson)
              .toList();
          if (legacyProjects.isNotEmpty) {
            saveProjects(legacyProjects);
            try {
              legacyFile.renameSync('${legacyFile.path}.migrated');
            } catch (_) {}
            return legacyProjects;
          }
        }
      }
      return [];
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load projects', e, st);
      return [];
    }
  }

  static void saveProjects(List<Project> projects) {
    try {
      final d = Directory(_projectsDir);
      if (!d.existsSync()) d.createSync(recursive: true);

      final activeFiles = <String>{};
      for (final project in projects) {
        final filename = '${_safeFilename(project.id)}.json';
        activeFiles.add(filename);
        final file = File(p.join(_projectsDir, filename));
        file.writeAsStringSync(
          Json.encode(project.toJson(), pretty: true),
          flush: true,
        );
      }

      // Clean up obsolete project files
      if (d.existsSync()) {
        for (final entity in d.listSync()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final name = p.basename(entity.path);
            if (!activeFiles.contains(name)) {
              try {
                entity.deleteSync();
              } catch (e, st) {
                Log.warning(_tag, 'Failed to delete obsolete project file: $name', e, st);
              }
            }
          }
        }
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save projects', e, st);
    }
  }

  static void saveSingleProject(Project project) {
    try {
      final d = Directory(_projectsDir);
      if (!d.existsSync()) d.createSync(recursive: true);
      final file = File(p.join(_projectsDir, '${_safeFilename(project.id)}.json'));
      file.writeAsStringSync(
        Json.encode(project.toJson(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save single project: ${project.id}', e, st);
    }
  }

  static void deleteSingleProject(String projectId) {
    try {
      final file = File(p.join(_projectsDir, '${_safeFilename(projectId)}.json'));
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed to delete single project: $projectId', e, st);
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
      final d = Directory(_notesDir);
      if (d.existsSync()) {
        final files = d
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList();
        if (files.isNotEmpty) {
          final notes = <Note>[];
          for (final f in files) {
            try {
              final parsed = Json.parse(f.readAsStringSync());
              final obj = Json.obj(parsed);
              if (obj != null) {
                final note = Note.fromJson(obj);
                if (note.isEmpty) {
                  try {
                    f.deleteSync();
                  } catch (_) {}
                } else {
                  notes.add(note);
                }
              }
            } catch (e, st) {
              Log.warning(_tag, 'Failed to parse note file: ${f.path}', e, st);
            }
          }
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        }
      }

      // Migration fallback: check legacy single file notes.json
      final legacyFile = File(_notesFile);
      if (legacyFile.existsSync()) {
        final list = Json.list(Json.parse(legacyFile.readAsStringSync()));
        if (list != null) {
          final legacyNotes = list
              .whereType<Map<String, dynamic>>()
              .map(Note.fromJson)
              .where((n) => !n.isEmpty)
              .toList();
          if (legacyNotes.isNotEmpty) {
            saveNotes(legacyNotes);
            try {
              legacyFile.renameSync('${legacyFile.path}.migrated');
            } catch (_) {}
            return legacyNotes;
          }
        }
      }
      return [];
    } catch (e, st) {
      Log.warning(_tag, 'Failed to load notes', e, st);
      return [];
    }
  }

  static void saveNotes(List<Note> notes) {
    try {
      final validNotes = notes.where((n) => !n.isEmpty).toList();
      final d = Directory(_notesDir);
      if (!d.existsSync()) d.createSync(recursive: true);

      final activeFiles = <String>{};
      for (final note in validNotes) {
        final filename = '${_safeFilename(note.id)}.json';
        activeFiles.add(filename);
        final file = File(p.join(_notesDir, filename));
        file.writeAsStringSync(
          Json.encode(note.toJson(), pretty: true),
          flush: true,
        );
      }

      // Clean up obsolete note files
      if (d.existsSync()) {
        for (final entity in d.listSync()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final name = p.basename(entity.path);
            if (!activeFiles.contains(name)) {
              try {
                entity.deleteSync();
              } catch (e, st) {
                Log.warning(_tag, 'Failed to delete obsolete note file: $name', e, st);
              }
            }
          }
        }
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save notes', e, st);
    }
  }

  static void saveSingleNote(Note note) {
    if (note.isEmpty) {
      deleteSingleNote(note.id);
      return;
    }
    try {
      final d = Directory(_notesDir);
      if (!d.existsSync()) d.createSync(recursive: true);
      final file = File(p.join(_notesDir, '${_safeFilename(note.id)}.json'));
      file.writeAsStringSync(
        Json.encode(note.toJson(), pretty: true),
        flush: true,
      );
    } catch (e, st) {
      Log.warning(_tag, 'Failed to save single note: ${note.id}', e, st);
    }
  }

  static void deleteSingleNote(String noteId) {
    try {
      final file = File(p.join(_notesDir, '${_safeFilename(noteId)}.json'));
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed to delete single note: $noteId', e, st);
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
