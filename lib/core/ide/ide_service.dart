import 'dart:io';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';
import 'package:path/path.dart' as p;

class DetectedEditor {
  final EditorType type;
  final String label;
  final String launchTarget; // App bundle name, CLI binary path, or exe path
  final bool isCli;

  const DetectedEditor({
    required this.type,
    required this.label,
    required this.launchTarget,
    this.isCli = false,
  });
}

class IdeService {
  IdeService._();

  static const String _tag = 'ide';

  /// Cache of detected editors
  static final Map<EditorType, DetectedEditor> _detectedCache = {};
  static bool _detectionRun = false;

  static final List<String> _extraUnixPaths = [
    '/usr/local/bin',
    '/opt/homebrew/bin',
    '/usr/bin',
    '/bin',
    '${Platform.environment['HOME']}/.cargo/bin',
    '${Platform.environment['HOME']}/flutter/bin',
    '${Platform.environment['HOME']}/.local/bin',
    '/usr/local/go/bin',
  ];

  static Map<String, String> _buildEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    if (!Platform.isWindows) {
      final curPath = env['PATH'] ?? '';
      final parts = curPath.split(':').toSet();
      for (final p in _extraUnixPaths) {
        if (Directory(p).existsSync()) parts.add(p);
      }
      env['PATH'] = parts.join(':');
    }
    return env;
  }

  static List<String> get _macAppSearchDirs => [
        '/Applications',
        '${Platform.environment['HOME']}/Applications',
        '/System/Applications',
        '/Applications/JetBrains Toolbox',
        '${Platform.environment['HOME']}/Applications/JetBrains Toolbox',
        '${Platform.environment['HOME']}/Library/Application Support/JetBrains/Toolbox/apps',
      ];

  static List<String> get _windowsSearchDirs {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final progFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final progFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    return [
      p.join(localAppData, 'Programs'),
      progFiles,
      progFilesX86,
      p.join(localAppData, 'JetBrains', 'Toolbox', 'apps'),
    ];
  }

  static String? _findInPath(String cmd, Map<String, String> env) {
    if (cmd.isEmpty) return null;
    final pathVal = env['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final dirs = pathVal.split(separator);
    for (final d in dirs) {
      if (d.trim().isEmpty) continue;
      final target = Platform.isWindows ? p.join(d, '$cmd.exe') : p.join(d, cmd);
      if (File(target).existsSync()) {
        return target;
      }
      if (Platform.isWindows) {
        final targetCmd = p.join(d, '$cmd.cmd');
        if (File(targetCmd).existsSync()) return targetCmd;
        final targetBat = p.join(d, '$cmd.bat');
        if (File(targetBat).existsSync()) return targetBat;
      }
    }
    return null;
  }

  /// Inspects host OS and returns whether [editor] is installed, plus its launch target.
  static Future<DetectedEditor?> detectEditor(EditorType editor) async {
    if (editor == EditorType.custom) {
      return DetectedEditor(
        type: editor,
        label: editor.label,
        launchTarget: 'custom',
      );
    }

    try {
      final env = _buildEnvironment();

      // 1. Check CLI command in PATH
      if (editor.cliCmd.isNotEmpty) {
        final cliPath = _findInPath(editor.cliCmd, env);
        if (cliPath != null && cliPath.isNotEmpty) {
          return DetectedEditor(
            type: editor,
            label: editor.label,
            launchTarget: cliPath,
            isCli: true,
          );
        }
      }

      // 2. Platform-specific application bundles
      if (Platform.isMacOS) {
        for (final appName in editor.macAppVariants) {
          for (final dir in _macAppSearchDirs) {
            final appPath = p.join(dir, appName);
            if (Directory(appPath).existsSync() || File(appPath).existsSync()) {
              return DetectedEditor(
                type: editor,
                label: editor.label,
                launchTarget: appName,
                isCli: false,
              );
            }
          }
        }
      } else if (Platform.isWindows && editor.winExe.isNotEmpty) {
        for (final dir in _windowsSearchDirs) {
          if (!Directory(dir).existsSync()) continue;
          try {
            final matches = Directory(dir)
                .listSync(recursive: true, followLinks: false)
                .where((f) => p.basename(f.path).toLowerCase() == editor.winExe.toLowerCase())
                .toList();
            if (matches.isNotEmpty) {
              return DetectedEditor(
                type: editor,
                label: editor.label,
                launchTarget: matches.first.path,
                isCli: true,
              );
            }
          } catch (_) {}
        }
      } else if (Platform.isLinux) {
        // Check Linux desktop files
        final desktopDirs = [
          '/usr/share/applications',
          '${Platform.environment['HOME']}/.local/share/applications',
          '/var/lib/flatpak/exports/share/applications',
          '/var/lib/snapd/desktop/applications',
        ];
        for (final d in desktopDirs) {
          if (!Directory(d).existsSync()) continue;
          final files = Directory(d).listSync().whereType<File>();
          for (final f in files) {
            final name = p.basename(f.path).toLowerCase();
            if (name.contains(editor.cliCmd) || name.contains(editor.name.toLowerCase())) {
              return DetectedEditor(
                type: editor,
                label: editor.label,
                launchTarget: editor.cliCmd,
                isCli: true,
              );
            }
          }
        }
      }
    } catch (e) {
      Log.debug(_tag, 'Error detecting ${editor.label}: $e');
    }

    return null;
  }

  /// Scans all known editors concurrently and caches detected results.
  static Future<Map<EditorType, DetectedEditor>> detectAll() async {
    Log.info(_tag, 'Scanning for installed IDEs and editors…');
    final Map<EditorType, DetectedEditor> detected = {};

    final tasks = EditorType.values.map((editor) async {
      final res = await detectEditor(editor);
      if (res != null) {
        detected[editor] = res;
      }
    });

    await Future.wait(tasks);

    _detectedCache.clear();
    _detectedCache.addAll(detected);
    _detectionRun = true;

    final names = detected.values.map((e) => e.label).join(', ');
    Log.info(_tag, 'Installed editors detected: $names');
    return detected;
  }

  static Future<bool> isInstalled(EditorType editor) async {
    if (!_detectionRun) await detectAll();
    return _detectedCache.containsKey(editor);
  }

  static Future<List<EditorType>> getAvailableEditors() async {
    if (!_detectionRun) await detectAll();
    final list = _detectedCache.keys.where((e) => e != EditorType.custom).toList();
    if (list.isEmpty) list.add(EditorType.vscode);
    return list;
  }

  /// Launches an editor directly, optionally opening [path] (file or folder).
  static Future<bool> launchEditor(
    EditorType editor, {
    String? path,
  }) async {
    Log.info(_tag, 'Launching editor "${editor.label}"${path != null ? ' at $path' : ''}');

    try {
      if (!_detectionRun) await detectAll();
      final detected = _detectedCache[editor];

      if (Platform.isMacOS) {
        if (detected != null && !detected.isCli) {
          final args = ['-a', detected.launchTarget];
          if (path != null && path.isNotEmpty) args.add(path);
          final res = await Process.run('open', args);
          if (res.exitCode == 0) return true;
        }

        // Try CLI command
        if (editor.cliCmd.isNotEmpty) {
          final env = _buildEnvironment();
          try {
            final args = path != null && path.isNotEmpty ? [path] : <String>[];
            final res = await Process.run(editor.cliCmd, args, environment: env);
            if (res.exitCode == 0) return true;
          } catch (_) {}
        }

        // Try any macApp variant
        for (final app in editor.macAppVariants) {
          final args = ['-a', app];
          if (path != null && path.isNotEmpty) args.add(path);
          final res = await Process.run('open', args);
          if (res.exitCode == 0) return true;
        }

        if (path != null && path.isNotEmpty) {
          await Process.run('open', [path]);
          return true;
        }
        return false;
      } else if (Platform.isWindows) {
        if (detected != null && detected.launchTarget.isNotEmpty) {
          final args = path != null && path.isNotEmpty ? [path] : <String>[];
          await Process.start(detected.launchTarget, args, runInShell: true);
          return true;
        }
        if (editor.cliCmd.isNotEmpty) {
          final args = ['/c', editor.cliCmd];
          if (path != null && path.isNotEmpty) args.add(path);
          await Process.start('cmd.exe', args, runInShell: true);
          return true;
        }
        if (path != null && path.isNotEmpty) {
          await Process.start('explorer.exe', [path], runInShell: true);
          return true;
        }
        return false;
      } else {
        // Linux
        if (editor.cliCmd.isNotEmpty) {
          final args = path != null && path.isNotEmpty ? [path] : <String>[];
          await Process.start(editor.cliCmd, args, runInShell: true);
          return true;
        }
        if (path != null && path.isNotEmpty) {
          await Process.start('xdg-open', [path], runInShell: true);
          return true;
        }
        return false;
      }
    } catch (e, st) {
      Log.error(_tag, 'Failed to launch editor ${editor.label}', e, st);
      return false;
    }
  }

  static Future<bool> openProject(
    Project project, {
    EditorType? overrideEditor,
  }) async {
    final editor = overrideEditor ?? project.defaultEditor;
    final path = project.path;

    if (!Directory(path).existsSync()) {
      Log.warning(_tag, 'Target path does not exist: $path');
      return false;
    }

    Log.info(_tag, 'Opening project "${project.name}" in ${editor.label} at $path');

    try {
      if (project.customEditorCommand != null &&
          project.customEditorCommand!.trim().isNotEmpty) {
        final parts = project.customEditorCommand!.split(' ');
        final cmd = parts.first;
        final args = [...parts.skip(1), path];
        await Process.start(cmd, args, runInShell: true);
        return true;
      }

      return await launchEditor(editor, path: path);
    } catch (e, st) {
      Log.error(_tag, 'Failed to launch editor for project $path', e, st);
      return false;
    }
  }
}
