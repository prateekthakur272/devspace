import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';
import 'package:devspace/utils/paths.dart';
import 'package:path/path.dart' as p;

/// Service that extracts and caches the actual operating system application icons
/// from installed desktop applications, IDEs, and system utilities.
class AppIconService {
  AppIconService._();

  static const String _tag = 'app_icons';

  /// Memory cache of extracted icon IDs present on disk to avoid redundant file stats.
  static final Set<String> _cachedIds = {};

  /// Custom override directory for testing.
  @visibleForTesting
  static String? testCacheDir;

  /// Directory where converted 64x64 PNG icons are cached.
  static String get cacheDir {
    final dir = testCacheDir ?? p.join(Paths.dataDir, 'app_icons');
    try {
      final d = io.Directory(dir);
      if (!d.existsSync()) d.createSync(recursive: true);
    } catch (e, st) {
      Log.warning(_tag, 'Could not create icon cache directory $dir', e, st);
    }
    return dir;
  }

  /// Clears the in-memory cache index (useful for tests and rescanning).
  static void clearMemoryCache() {
    _cachedIds.clear();
  }

  /// Sanitizes an ID string into a safe filename.
  static String sanitizeId(String id) {
    return id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  /// Returns the cached icon [File] for [id] if it exists on disk, or null.
  static io.File? getIconFile(String id) {
    final sanitized = sanitizeId(id);
    final filePath = p.join(cacheDir, '$sanitized.png');

    if (_cachedIds.contains(sanitized)) {
      return io.File(filePath);
    }

    try {
      final file = io.File(filePath);
      if (file.existsSync()) {
        _cachedIds.add(sanitized);
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the cached icon [File] for a [PinnedApp] or app path,
  /// checking multiple candidate IDs (sanitized name, custom iconId, path basename).
  static io.File? getIconFileForApp(PinnedApp app) {
    // 1. By sanitized name (e.g. "android_studio.png", "app_store.png", "calculator.png")
    final nameId = sanitizeId(app.name);
    final byName = getIconFile(nameId);
    if (byName != null) return byName;

    // 2. By custom iconId
    final byId = getIconFile(app.iconId);
    if (byId != null) return byId;

    // 3. By path basename
    final baseName = sanitizeId(p.basenameWithoutExtension(app.path));
    if (baseName != nameId) {
      final byBase = getIconFile(baseName);
      if (byBase != null) return byBase;
    }

    return null;
  }

  /// Extracts the icon for an arbitrary application by its path and name.
  static Future<String?> extractAppIcon(String appPath, String name) async {
    final sanitized = sanitizeId(name);
    final existing = getIconFile(sanitized);
    if (existing != null) return existing.path;

    if (io.Platform.isMacOS) {
      return await extractMacIcon(appPath, sanitized);
    } else if (io.Platform.isWindows) {
      return await extractWinIcon(appPath, sanitized);
    }
    return null;
  }

  /// Extracts icons in parallel or batch for a group of apps.
  static Future<void> extractBatch(List<PinnedApp> apps) async {
    if (apps.isEmpty) return;

    if (io.Platform.isMacOS) {
      final missingPairs = <String>[];
      for (final app in apps) {
        final sanitized = sanitizeId(app.name);
        final outPath = p.join(cacheDir, '$sanitized.png');
        if (!io.File(outPath).existsSync() && !_cachedIds.contains(sanitized)) {
          missingPairs.addAll([app.path, outPath]);
        }
      }

      if (missingPairs.isNotEmpty) {
        final ok = await _extractBatchSwift(missingPairs);
        if (ok) return;
      }
    }

    final futures = <Future>[];
    for (final app in apps) {
      final sanitized = sanitizeId(app.name);
      if (getIconFile(sanitized) == null) {
        futures.add(extractAppIcon(app.path, app.name));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<bool> _extractBatchSwift(List<String> pairs) async {
    try {
      const swiftScript = '''
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
var i = 0
let size = NSSize(width: 64, height: 64)
while i + 1 < args.count {
    let appPath = args[i]
    let outPath = args[i + 1]
    i += 2
    
    if FileManager.default.fileExists(atPath: outPath) { continue }
    let img = NSWorkspace.shared.icon(forFile: appPath)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: outPath))
    }
}
''';
      final res = await io.Process.run('/usr/bin/swift', ['-e', swiftScript, ...pairs]);
      if (res.exitCode == 0) {
        for (int i = 1; i < pairs.length; i += 2) {
          final outPath = pairs[i];
          final id = p.basenameWithoutExtension(outPath);
          if (io.File(outPath).existsSync()) {
            _cachedIds.add(id);
          }
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Extracts the application icon for the macOS system terminal (or installed terminal emulator).
  static Future<String?> extractTerminalIcon() async {
    const termId = 'terminal';
    final existing = getIconFile(termId);
    if (existing != null) return existing.path;

    if (io.Platform.isMacOS) {
      final candidateApps = [
        '/System/Applications/Utilities/Terminal.app',
        '/Applications/Utilities/Terminal.app',
        '/Applications/iTerm.app',
        '/Applications/Ghostty.app',
        '/Applications/Warp.app',
        '/Applications/Alacritty.app',
      ];

      for (final appPath in candidateApps) {
        if (io.Directory(appPath).existsSync()) {
          final res = await extractMacIcon(appPath, termId);
          if (res != null) return res;
        }
      }
    } else if (io.Platform.isWindows) {
      final localAppData = io.Platform.environment['LOCALAPPDATA'] ?? '';
      final candidateExes = [
        p.join(localAppData, r'Microsoft\WindowsApps\wt.exe'),
        r'C:\Windows\System32\cmd.exe',
      ];
      for (final exePath in candidateExes) {
        if (io.File(exePath).existsSync()) {
          final res = await extractWinIcon(exePath, termId);
          if (res != null) return res;
        }
      }
    }

    return null;
  }

  /// Resolves the installed app bundle or binary path for [editor] and extracts its icon.
  static Future<String?> extractEditorIcon(EditorType editor) async {
    final sanitized = sanitizeId(editor.name);
    final existing = getIconFile(sanitized);
    if (existing != null) return existing.path;

    if (io.Platform.isMacOS) {
      final searchDirs = [
        '/Applications',
        '${io.Platform.environment['HOME']}/Applications',
        '/System/Applications',
        '/Applications/JetBrains Toolbox',
        '${io.Platform.environment['HOME']}/Applications/JetBrains Toolbox',
      ];

      for (final appName in editor.macAppVariants) {
        for (final dir in searchDirs) {
          final appPath = p.join(dir, appName);
          if (io.Directory(appPath).existsSync()) {
            final res = await extractMacIcon(appPath, sanitized);
            if (res != null) return res;
          }
        }
      }
    } else if (io.Platform.isWindows && editor.winExe.isNotEmpty) {
      final searchDirs = [
        p.join(io.Platform.environment['LOCALAPPDATA'] ?? '', 'Programs'),
        io.Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
        io.Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
      ];

      for (final dir in searchDirs) {
        if (!io.Directory(dir).existsSync()) continue;
        try {
          final matches = io.Directory(dir)
              .listSync(recursive: true, followLinks: false)
              .whereType<io.File>()
              .where((f) => p.basename(f.path).toLowerCase() == editor.winExe.toLowerCase())
              .toList();
          if (matches.isNotEmpty) {
            final res = await extractWinIcon(matches.first.path, sanitized);
            if (res != null) return res;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Extracts the icon for an installed [DesktopApp].
  static Future<String?> extractDesktopAppIcon(DesktopApp app) async {
    final sanitized = sanitizeId(app.id);
    final existing = getIconFile(sanitized);
    if (existing != null) return existing.path;

    if (io.Platform.isMacOS) {
      if (app.resolvedPath != null && io.Directory(app.resolvedPath!).existsSync()) {
        final res = await extractMacIcon(app.resolvedPath!, sanitized);
        if (res != null) return res;
      }

      final searchDirs = [
        '/Applications',
        '${io.Platform.environment['HOME']}/Applications',
        '/System/Applications',
      ];
      for (final variant in app.macAppVariants) {
        for (final dir in searchDirs) {
          final appPath = p.join(dir, variant);
          if (io.Directory(appPath).existsSync()) {
            final res = await extractMacIcon(appPath, sanitized);
            if (res != null) return res;
          }
        }
      }
    } else if (io.Platform.isWindows) {
      if (app.resolvedPath != null && io.File(app.resolvedPath!).existsSync()) {
        final res = await extractWinIcon(app.resolvedPath!, sanitized);
        if (res != null) return res;
      }
    }

    return null;
  }

  /// Extracts icons for all provided installed editors and desktop apps in parallel.
  static Future<void> extractAllInstalled({
    required List<EditorType> editors,
    required List<DesktopApp> desktopApps,
  }) async {
    final tasks = <Future>[
      extractTerminalIcon(),
      ...editors.map(extractEditorIcon),
      ...desktopApps.map(extractDesktopAppIcon),
    ];
    await Future.wait(tasks);
  }

  /// Extracts the macOS icon from [appPath] and converts it to a 64x64 PNG.
  /// Uses native NSWorkspace via Swift (works for all apps including system apps),
  /// falling back to .icns / sips if needed.
  static Future<String?> extractMacIcon(String appPath, String id) async {
    final sanitized = sanitizeId(id);
    final outPath = p.join(cacheDir, '$sanitized.png');

    if (io.File(outPath).existsSync()) {
      _cachedIds.add(sanitized);
      return outPath;
    }

    // 1. Try native Cocoa NSWorkspace extraction
    final ok = await _extractBatchSwift([appPath, outPath]);
    if (ok && io.File(outPath).existsSync()) {
      _cachedIds.add(sanitized);
      return outPath;
    }

    try {
      final resDir = p.join(appPath, 'Contents', 'Resources');
      if (!io.Directory(resDir).existsSync()) return null;

      String? icnsPath;

      // 1. Check CFBundleIconFile from Info.plist via PlistBuddy
      final plistPath = p.join(appPath, 'Contents', 'Info.plist');
      if (io.File(plistPath).existsSync()) {
        try {
          final plistRes = await io.Process.run('/usr/libexec/PlistBuddy', [
            '-c',
            'Print :CFBundleIconFile',
            plistPath,
          ]);
          if (plistRes.exitCode == 0) {
            var iconName = plistRes.stdout.toString().trim();
            if (iconName.isNotEmpty) {
              if (!iconName.endsWith('.icns')) iconName = '$iconName.icns';
              final candidate = p.join(resDir, iconName);
              if (io.File(candidate).existsSync()) {
                icnsPath = candidate;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Fallback: inspect Resources directory for .icns files
      if (icnsPath == null) {
        final icnsFiles = io.Directory(resDir)
            .listSync()
            .whereType<io.File>()
            .where((f) => f.path.toLowerCase().endsWith('.icns'))
            .toList();

        if (icnsFiles.isNotEmpty) {
          // Prefer AppIcon.icns or file matching app name
          icnsPath = icnsFiles.firstWhere(
            (f) => p.basename(f.path).toLowerCase().contains('appicon'),
            orElse: () => icnsFiles.firstWhere(
              (f) => p.basename(f.path).toLowerCase().contains(sanitized),
              orElse: () => icnsFiles.first,
            ),
          ).path;
        }
      }

      if (icnsPath != null && io.File(icnsPath).existsSync()) {
        final sipsRes = await io.Process.run('sips', [
          '-s',
          'format',
          'png',
          '-z',
          '64',
          '64',
          icnsPath,
          '--out',
          outPath,
        ]);

        if (sipsRes.exitCode == 0 && io.File(outPath).existsSync()) {
          _cachedIds.add(sanitized);
          Log.info(_tag, 'Successfully extracted icon for $id -> $outPath');
          return outPath;
        }
      }
    } catch (e) {
      Log.debug(_tag, 'Failed extracting macOS icon for $appPath: $e');
    }
    return null;
  }

  /// Extracts the Windows icon from [exePath] via PowerShell into a PNG.
  static Future<String?> extractWinIcon(String exePath, String id) async {
    final sanitized = sanitizeId(id);
    final outPath = p.join(cacheDir, '$sanitized.png');

    if (io.File(outPath).existsSync()) {
      _cachedIds.add(sanitized);
      return outPath;
    }

    try {
      final script =
          "try { Add-Type -AssemblyName System.Drawing; "
          "[System.Drawing.Icon]::ExtractAssociatedIcon('$exePath').ToBitmap().Save('$outPath', [System.Drawing.Imaging.ImageFormat]::Png) } catch {}";
      final res = await io.Process.run('powershell', ['-NoProfile', '-Command', script]);
      if (res.exitCode == 0 && io.File(outPath).existsSync()) {
        _cachedIds.add(sanitized);
        Log.info(_tag, 'Successfully extracted Windows icon for $id -> $outPath');
        return outPath;
      }
    } catch (e) {
      Log.debug(_tag, 'Failed extracting Windows icon for $exePath: $e');
    }
    return null;
  }
}
