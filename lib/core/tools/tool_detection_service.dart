import 'dart:io';
import 'package:devspace/core/logging/log.dart';

class DetectedTool {
  final String id;
  final String name;
  final String category; // 'VCS', 'Language / SDK', 'Runtime', 'Container', 'CLI'
  final String version;
  final String path;

  const DetectedTool({
    required this.id,
    required this.name,
    required this.category,
    required this.version,
    required this.path,
  });
}

class ToolDetectionService {
  ToolDetectionService._();

  static const String _tag = 'tools';

  /// Standard paths to search on Unix systems in case the process environment is minimal.
  static final List<String> _extraUnixPaths = [
    '/usr/local/bin',
    '/opt/homebrew/bin',
    '/usr/bin',
    '/bin',
    '/usr/sbin',
    '/sbin',
    '${Platform.environment['HOME']}/.cargo/bin',
    '${Platform.environment['HOME']}/flutter/bin',
    '${Platform.environment['HOME']}/.flutter/bin',
    '${Platform.environment['HOME']}/go/bin',
    '/usr/local/go/bin',
  ];

  static Map<String, String> _buildEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    if (!Platform.isWindows) {
      final curPath = env['PATH'] ?? '';
      final parts = curPath.split(':').toSet();
      for (final p in _extraUnixPaths) {
        if (Directory(p).existsSync()) {
          parts.add(p);
        }
      }
      env['PATH'] = parts.join(':');
    }
    return env;
  }

  static String? _findInPath(String cmd, Map<String, String> env) {
    if (cmd.isEmpty) return null;
    final pathVal = env['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final dirs = pathVal.split(separator);
    for (final d in dirs) {
      if (d.trim().isEmpty) continue;
      final target = Platform.isWindows ? '$d\\$cmd.exe' : '$d/$cmd';
      if (File(target).existsSync()) {
        return target;
      }
      if (Platform.isWindows) {
        final targetCmd = '$d\\$cmd.cmd';
        if (File(targetCmd).existsSync()) return targetCmd;
        final targetBat = '$d\\$cmd.bat';
        if (File(targetBat).existsSync()) return targetBat;
      }
    }
    return null;
  }

  static Future<DetectedTool?> _checkTool({
    required String id,
    required String name,
    required String category,
    required String cmd,
    required List<String> versionArgs,
    RegExp? versionPattern,
  }) async {
    try {
      final env = _buildEnvironment();
      final fullPath = _findInPath(cmd, env);
      if (fullPath == null) return null;

      final verRes = await Process.run(
        fullPath,
        versionArgs,
        environment: env,
      );

      final output = '${verRes.stdout} ${verRes.stderr}'.trim();
      String ver = 'Installed';
      if (versionPattern != null) {
        final match = versionPattern.firstMatch(output);
        if (match != null && match.groupCount >= 1) {
          ver = match.group(1) ?? match.group(0) ?? 'Installed';
        }
      } else if (output.isNotEmpty) {
        ver = output.split('\n').first.trim();
        if (ver.length > 30) ver = ver.substring(0, 30);
      }

      return DetectedTool(
        id: id,
        name: name,
        category: category,
        version: ver,
        path: fullPath,
      );
    } catch (e) {
      Log.debug(_tag, 'Tool $name not found or error checking: $e');
      return null;
    }
  }

  /// Runs detection of common developer CLI tools concurrently.
  static Future<List<DetectedTool>> detectAllTools() async {
    Log.info(_tag, 'Scanning for installed developer tools and SDKs…');

    final checks = [
      _checkTool(
        id: 'git',
        name: 'Git',
        category: 'VCS',
        cmd: 'git',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'git version ([\d\.]+)'),
      ),
      _checkTool(
        id: 'flutter',
        name: 'Flutter',
        category: 'Language / SDK',
        cmd: 'flutter',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'Flutter ([\d\.]+)'),
      ),
      _checkTool(
        id: 'node',
        name: 'Node.js',
        category: 'Runtime',
        cmd: 'node',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'v?([\d\.]+)'),
      ),
      _checkTool(
        id: 'npm',
        name: 'npm',
        category: 'Package Manager',
        cmd: 'npm',
        versionArgs: ['--version'],
      ),
      _checkTool(
        id: 'pnpm',
        name: 'pnpm',
        category: 'Package Manager',
        cmd: 'pnpm',
        versionArgs: ['--version'],
      ),
      _checkTool(
        id: 'bun',
        name: 'Bun',
        category: 'Runtime',
        cmd: 'bun',
        versionArgs: ['--version'],
      ),
      _checkTool(
        id: 'python',
        name: 'Python',
        category: 'Language / SDK',
        cmd: Platform.isWindows ? 'python' : 'python3',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'Python ([\d\.]+)'),
      ),
      _checkTool(
        id: 'go',
        name: 'Go',
        category: 'Language / SDK',
        cmd: 'go',
        versionArgs: ['version'],
        versionPattern: RegExp(r'go version go([\d\.]+)'),
      ),
      _checkTool(
        id: 'cargo',
        name: 'Rust (Cargo)',
        category: 'Language / SDK',
        cmd: 'cargo',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'cargo ([\d\.]+)'),
      ),
      _checkTool(
        id: 'docker',
        name: 'Docker',
        category: 'Container',
        cmd: 'docker',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'Docker version ([\d\.]+)'),
      ),
      _checkTool(
        id: 'gh',
        name: 'GitHub CLI',
        category: 'CLI',
        cmd: 'gh',
        versionArgs: ['--version'],
        versionPattern: RegExp(r'gh version ([\d\.]+)'),
      ),
    ];

    final results = await Future.wait(checks);
    final detected = results.whereType<DetectedTool>().toList();
    Log.info(_tag, 'Detected ${detected.length} developer tools and SDKs.');
    return detected;
  }
}
