import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:path/path.dart' as p;

/// Represents a detected desktop GUI developer application (not a code editor).
class DesktopApp {
  final String id;
  final String name;
  final String category;
  final List<String> macAppVariants;
  final List<String> winExeVariants;
  final List<String> linuxCmdVariants;
  final Widget Function(Pal p) iconBuilder;
  final String? resolvedPath;
  final String? iconPath;

  const DesktopApp({
    required this.id,
    required this.name,
    required this.category,
    required this.macAppVariants,
    required this.winExeVariants,
    required this.linuxCmdVariants,
    required this.iconBuilder,
    this.resolvedPath,
    this.iconPath,
  });

  DesktopApp copyWith({String? resolvedPath, String? iconPath}) {
    return DesktopApp(
      id: id,
      name: name,
      category: category,
      macAppVariants: macAppVariants,
      winExeVariants: winExeVariants,
      linuxCmdVariants: linuxCmdVariants,
      iconBuilder: iconBuilder,
      resolvedPath: resolvedPath ?? this.resolvedPath,
      iconPath: iconPath ?? this.iconPath,
    );
  }
}

/// Service to detect and launch installed desktop GUI developer applications.
class DesktopAppService {
  DesktopAppService._();

  static const String _tag = 'desktop_apps';

  /// Catalog of known developer desktop GUI applications.
  static final List<DesktopApp> knownApps = [
    DesktopApp(
      id: 'docker',
      name: 'Docker Desktop',
      category: 'Containers',
      macAppVariants: ['Docker.app'],
      winExeVariants: [
        'Docker Desktop.exe',
        r'Docker\Docker\Docker Desktop.exe',
      ],
      linuxCmdVariants: ['docker-desktop'],
      iconBuilder: (p) => const Icon(
        Icons.view_in_ar_rounded,
        size: 17,
        color: Color(0xFF2496ED),
      ),
    ),
    DesktopApp(
      id: 'github_desktop',
      name: 'GitHub Desktop',
      category: 'Git Client',
      macAppVariants: ['GitHub Desktop.app'],
      winExeVariants: [
        'GitHubDesktop.exe',
        r'GitHubDesktop\GitHubDesktop.exe',
      ],
      linuxCmdVariants: ['github-desktop'],
      iconBuilder: (p) => GitHubIcon(size: 16, color: p.text),
    ),
    DesktopApp(
      id: 'openrest',
      name: 'OpenRest',
      category: 'API Client',
      macAppVariants: ['OpenRest.app'],
      winExeVariants: ['OpenRest.exe', r'OpenRest\OpenRest.exe'],
      linuxCmdVariants: ['openrest'],
      iconBuilder: (p) => const Icon(
        Icons.api_rounded,
        size: 17,
        color: Color(0xFF00BFA5),
      ),
    ),
    DesktopApp(
      id: 'postman',
      name: 'Postman',
      category: 'API Client',
      macAppVariants: ['Postman.app'],
      winExeVariants: [
        'Postman.exe',
        r'Postman\Postman.exe',
      ],
      linuxCmdVariants: ['postman'],
      iconBuilder: (p) => const Icon(
        Icons.send_rounded,
        size: 16,
        color: Color(0xFFFF6C37),
      ),
    ),
    DesktopApp(
      id: 'tableplus',
      name: 'TablePlus',
      category: 'Database GUI',
      macAppVariants: ['TablePlus.app'],
      winExeVariants: ['TablePlus.exe', r'TablePlus\TablePlus.exe'],
      linuxCmdVariants: ['tableplus'],
      iconBuilder: (p) => const Icon(
        Icons.storage_rounded,
        size: 16,
        color: Color(0xFF009688),
      ),
    ),
    DesktopApp(
      id: 'dbeaver',
      name: 'DBeaver',
      category: 'Database GUI',
      macAppVariants: ['DBeaver.app', 'dbeaver.app'],
      winExeVariants: ['dbeaver.exe', r'DBeaver\dbeaver.exe'],
      linuxCmdVariants: ['dbeaver'],
      iconBuilder: (p) => const Icon(
        Icons.dataset_rounded,
        size: 16,
        color: Color(0xFF8B5A2B),
      ),
    ),
    DesktopApp(
      id: 'gitkraken',
      name: 'GitKraken',
      category: 'Git Client',
      macAppVariants: ['GitKraken.app'],
      winExeVariants: ['gitkraken.exe', r'GitKraken\gitkraken.exe'],
      linuxCmdVariants: ['gitkraken'],
      iconBuilder: (p) => const Icon(
        AppIcons.git,
        size: 16,
        color: Color(0xFF17B890),
      ),
    ),
    DesktopApp(
      id: 'insomnia',
      name: 'Insomnia',
      category: 'API Client',
      macAppVariants: ['Insomnia.app'],
      winExeVariants: ['Insomnia.exe', r'Insomnia\Insomnia.exe'],
      linuxCmdVariants: ['insomnia'],
      iconBuilder: (p) => const Icon(
        Icons.cloud_sync_rounded,
        size: 16,
        color: Color(0xFF5849BE),
      ),
    ),
    DesktopApp(
      id: 'orbit',
      name: 'Orbit',
      category: 'Developer Tool',
      macAppVariants: ['Orbit.app'],
      winExeVariants: ['Orbit.exe'],
      linuxCmdVariants: ['orbit'],
      iconBuilder: (p) => const Icon(
        Icons.all_inclusive_rounded,
        size: 16,
        color: Color(0xFF6C5CE7),
      ),
    ),
    DesktopApp(
      id: 'utm',
      name: 'UTM Virtual Machines',
      category: 'Virtualization',
      macAppVariants: ['UTM.app'],
      winExeVariants: ['UTM.exe'],
      linuxCmdVariants: ['utm'],
      iconBuilder: (p) => const Icon(
        Icons.computer_rounded,
        size: 16,
        color: Color(0xFF3498DB),
      ),
    ),
  ];

  static List<String> get _macSearchDirs => [
        '/Applications',
        '${io.Platform.environment['HOME']}/Applications',
        '/System/Applications',
      ];

  static List<String> get _winSearchDirs {
    final localAppData = io.Platform.environment['LOCALAPPDATA'] ?? '';
    final progFiles = io.Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final progFilesX86 =
        io.Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    return [
      p.join(localAppData, 'Programs'),
      localAppData,
      progFiles,
      progFilesX86,
    ];
  }

  /// Scans the operating system for installed developer desktop applications.
  static Future<List<DesktopApp>> detectAll() async {
    Log.info(_tag, 'Scanning for installed developer desktop GUI apps…');
    final detected = <DesktopApp>[];

    for (final app in knownApps) {
      final found = await _detectApp(app);
      if (found != null) {
        final icon = await AppIconService.extractDesktopAppIcon(found);
        detected.add(found.copyWith(iconPath: icon));
      }
    }

    Log.info(_tag, 'Detected ${detected.length} desktop developer apps: ${detected.map((a) => a.name).join(', ')}');
    return detected;
  }

  /// Discovers installed GUI applications across standard system paths for pinning.
  static Future<List<PinnedApp>> listSystemApplications() async {
    final apps = <String, PinnedApp>{};

    try {
      if (io.Platform.isMacOS) {
        final dirs = [
          '/Applications',
          '${io.Platform.environment['HOME']}/Applications',
          '/System/Applications',
        ];
        for (final dirPath in dirs) {
          final dir = io.Directory(dirPath);
          if (!dir.existsSync()) continue;
          try {
            final entries = dir.listSync(followLinks: false);
            for (final entry in entries) {
              if (entry is io.Directory && entry.path.endsWith('.app')) {
                final base = p.basenameWithoutExtension(entry.path);
                apps[entry.path] = PinnedApp(name: base, path: entry.path);
              }
            }
          } catch (_) {}
        }
      } else if (io.Platform.isWindows) {
        for (final dirPath in _winSearchDirs) {
          final dir = io.Directory(dirPath);
          if (!dir.existsSync()) continue;
          try {
            final entries = dir.listSync(recursive: true, followLinks: false);
            for (final entry in entries) {
              if (entry is io.File) {
                final ext = p.extension(entry.path).toLowerCase();
                if (ext == '.exe' || ext == '.lnk') {
                  final base = p.basenameWithoutExtension(entry.path);
                  if (!base.toLowerCase().contains('unins') &&
                      !base.toLowerCase().contains('setup')) {
                    apps[entry.path] = PinnedApp(name: base, path: entry.path);
                  }
                }
              }
            }
          } catch (_) {}
        }
      } else if (io.Platform.isLinux) {
        final desktopDirs = [
          '/usr/share/applications',
          '${io.Platform.environment['HOME']}/.local/share/applications',
        ];
        for (final dirPath in desktopDirs) {
          final dir = io.Directory(dirPath);
          if (!dir.existsSync()) continue;
          try {
            final entries = dir.listSync();
            for (final entry in entries) {
              if (entry is io.File && entry.path.endsWith('.desktop')) {
                final base = p.basenameWithoutExtension(entry.path);
                apps[entry.path] = PinnedApp(name: base, path: entry.path);
              }
            }
          } catch (_) {}
        }
      }
    } catch (e, st) {
      Log.warning(_tag, 'Failed listing system applications', e, st);
    }

    final list = apps.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<DesktopApp?> _detectApp(DesktopApp app) async {
    try {
      if (io.Platform.isMacOS) {
        for (final dir in _macSearchDirs) {
          for (final variant in app.macAppVariants) {
            final appPath = p.join(dir, variant);
            if (io.Directory(appPath).existsSync() || io.File(appPath).existsSync()) {
              return app.copyWith(resolvedPath: appPath);
            }
          }
        }
      } else if (io.Platform.isWindows) {
        for (final dir in _winSearchDirs) {
          for (final variant in app.winExeVariants) {
            final exePath = p.join(dir, variant);
            if (io.File(exePath).existsSync()) {
              return app.copyWith(resolvedPath: exePath);
            }
          }
        }
      } else if (io.Platform.isLinux) {
        final pathEnv = io.Platform.environment['PATH'] ?? '';
        final dirs = pathEnv.split(':');
        for (final d in dirs) {
          for (final cmd in app.linuxCmdVariants) {
            final fullPath = p.join(d, cmd);
            if (io.File(fullPath).existsSync()) {
              return app.copyWith(resolvedPath: fullPath);
            }
          }
        }
      }
    } catch (e) {
      Log.debug(_tag, 'Error detecting ${app.name}: $e');
    }
    return null;
  }

  /// Launches the given desktop application.
  static Future<bool> launchApp(DesktopApp app) async {
    Log.info(_tag, 'Launching desktop application "${app.name}"');

    try {
      if (io.Platform.isMacOS) {
        if (app.resolvedPath != null && app.resolvedPath!.isNotEmpty) {
          final res = await io.Process.run('open', [app.resolvedPath!]);
          if (res.exitCode == 0) return true;
        }
        for (final variant in app.macAppVariants) {
          final res = await io.Process.run('open', ['-a', variant]);
          if (res.exitCode == 0) return true;
        }
      } else if (io.Platform.isWindows) {
        if (app.resolvedPath != null && app.resolvedPath!.isNotEmpty) {
          await io.Process.start(app.resolvedPath!, [], runInShell: true);
          return true;
        }
        for (final exe in app.winExeVariants) {
          try {
            await io.Process.start('cmd.exe', ['/c', 'start', '""', exe], runInShell: true);
            return true;
          } catch (_) {}
        }
      } else {
        // Linux
        if (app.resolvedPath != null && app.resolvedPath!.isNotEmpty) {
          await io.Process.start(app.resolvedPath!, [], runInShell: true);
          return true;
        }
        for (final cmd in app.linuxCmdVariants) {
          try {
            await io.Process.start(cmd, [], runInShell: true);
            return true;
          } catch (_) {}
        }
      }
    } catch (e, st) {
      Log.error(_tag, 'Failed launching desktop application "${app.name}"', e, st);
    }
    return false;
  }

  /// Launches an arbitrary user-pinned application by its path.
  static Future<bool> launchPath(String path) async {
    Log.info(_tag, 'Launching pinned application "$path"');
    try {
      if (io.Platform.isMacOS) {
        final res = await io.Process.run('open', [path]);
        return res.exitCode == 0;
      }
      await io.Process.start(path, [], runInShell: true);
      return true;
    } catch (e, st) {
      Log.error(_tag, 'Failed launching pinned application "$path"', e, st);
      return false;
    }
  }
}
