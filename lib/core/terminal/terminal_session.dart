import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:devspace/core/logging/log.dart';
import 'package:devspace/core/terminal/terminal_suggestions.dart';
import 'package:devspace/utils/paths.dart';
import 'package:path/path.dart' as p;

enum TerminalLineType {
  prompt,
  stdout,
  stderr,
  system,
  error,
}

class TerminalLine {
  final String text;
  final TerminalLineType type;
  final DateTime timestamp;

  TerminalLine(this.text, {this.type = TerminalLineType.stdout})
      : timestamp = DateTime.now();
}

/// A stateful terminal session with interactive command execution,
/// working directory tracking, and ANSI output buffer.
class TerminalSession with ChangeNotifier {
  TerminalSession({
    required this.id,
    required String initialCwd,
    String? title,
  })  : _cwd = initialCwd,
        _title = title ?? 'zsh' {
    _addInitialBanner();
  }

  static const String _tag = 'terminal';

  final String id;
  String _title;
  String _cwd;
  final List<TerminalLine> _lines = [];
  final List<String> _history = [];
  int _historyIndex = -1;

  io.Process? _runningProcess;
  bool _isExecuting = false;

  /// Callback when user runs `exit` or `quit` to close this session.
  VoidCallback? onExitRequested;

  String get title => _title;
  set title(String val) {
    if (_title != val) {
      _title = val;
      notifyListeners();
    }
  }

  String get cwd => _cwd;
  List<TerminalLine> get lines => List.unmodifiable(_lines);
  List<String> get history => List.unmodifiable(_history);
  bool get isExecuting => _isExecuting;

  /// Display path for the prompt (e.g. `~/my-project`).
  String get displayCwd {
    final home = Paths.home;
    if (_cwd == home) return '~';
    if (_cwd.startsWith('$home/')) {
      return '~/${_cwd.substring(home.length + 1)}';
    }
    return _cwd;
  }

  String get shortCwd {
    final base = p.basename(_cwd);
    return base.isEmpty ? _cwd : base;
  }

  /// Detected git branch for this session's working directory, if inside a repository.
  String? get branch => TerminalSuggestionsEngine.getGitBranch(_cwd);

  void _addInitialBanner() {
    _lines.add(TerminalLine('DevSpace Integrated Terminal', type: TerminalLineType.system));
    _lines.add(TerminalLine('Working directory: $displayCwd\n', type: TerminalLineType.system));
  }

  /// Clears the terminal output buffer.
  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// History navigation: previous command (Up arrow).
  String? historyPrevious() {
    if (_history.isEmpty) return null;
    if (_historyIndex == -1) {
      _historyIndex = _history.length - 1;
    } else if (_historyIndex > 0) {
      _historyIndex--;
    }
    return _history[_historyIndex];
  }

  /// History navigation: next command (Down arrow).
  String? historyNext() {
    if (_history.isEmpty || _historyIndex == -1) return null;
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      return _history[_historyIndex];
    }
    _historyIndex = -1;
    return '';
  }

  /// Changes working directory, updating prompt path.
  bool changeDirectory(String targetPath) {
    var resolved = targetPath.trim();
    if (resolved.isEmpty || resolved == '~') {
      resolved = Paths.home;
    } else if (resolved.startsWith('~/')) {
      resolved = p.join(Paths.home, resolved.substring(2));
    } else if (!p.isAbsolute(resolved)) {
      resolved = p.normalize(p.join(_cwd, resolved));
    }

    final dir = io.Directory(resolved);
    if (dir.existsSync()) {
      _cwd = dir.resolveSymbolicLinksSync();
      _title = shortCwd;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Executes a shell or built-in command.
  Future<void> execute(String rawCommand) async {
    final cmd = rawCommand.trim();
    _historyIndex = -1;

    // Echo prompt line with rich context (cwd + branch)
    final b = branch;
    final promptText = b != null ? '$displayCwd [$b] ❯ $rawCommand' : '$displayCwd ❯ $rawCommand';
    _lines.add(TerminalLine(promptText, type: TerminalLineType.prompt));

    if (cmd.isEmpty) {
      notifyListeners();
      return;
    }

    // Record in history if not duplicate of the last entry
    if (_history.isEmpty || _history.last != cmd) {
      _history.add(cmd);
    }

    // 1. Check built-in commands
    if (cmd == 'exit' || cmd == 'quit') {
      _lines.add(TerminalLine('exit', type: TerminalLineType.system));
      notifyListeners();
      onExitRequested?.call();
      return;
    }

    if (cmd == 'clear' || cmd == 'cls') {
      clear();
      return;
    }

    if (cmd == 'pwd') {
      _lines.add(TerminalLine(_cwd, type: TerminalLineType.stdout));
      notifyListeners();
      return;
    }

    if (cmd == 'cd' || cmd.startsWith('cd ')) {
      final target = cmd == 'cd' ? '~' : cmd.substring(3).trim();
      final ok = changeDirectory(target);
      if (!ok) {
        _lines.add(TerminalLine('cd: no such file or directory: $target', type: TerminalLineType.error));
      }
      notifyListeners();
      return;
    }

    // 2. Execute via platform shell
    _isExecuting = true;
    notifyListeners();

    try {
      final String executable;
      final List<String> arguments;

      if (io.Platform.isMacOS) {
        executable = io.File('/bin/zsh').existsSync() ? '/bin/zsh' : '/bin/bash';
        arguments = ['-l', '-c', cmd];
      } else if (io.Platform.isWindows) {
        executable = 'cmd.exe';
        arguments = ['/c', cmd];
      } else {
        executable = io.File('/bin/bash').existsSync() ? '/bin/bash' : '/bin/sh';
        arguments = ['-l', '-c', cmd];
      }

      // Configure rich terminal environment with TrueColor and 256-color support
      final env = Map<String, String>.from(io.Platform.environment);
      env['TERM'] = 'xterm-256color';
      env['COLORTERM'] = 'truecolor';
      env['CLICOLOR'] = '1';
      env['CLICOLOR_FORCE'] = '1';
      env['FORCE_COLOR'] = '3';
      env['CARGO_TERM_COLOR'] = 'always';
      env['PIP_COLOR'] = 'always';

      final proc = await io.Process.start(
        executable,
        arguments,
        workingDirectory: _cwd,
        environment: env,
        runInShell: false,
      );

      _runningProcess = proc;

      // Stream stdout in real-time
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _lines.add(TerminalLine(line, type: TerminalLineType.stdout));
        _trimBuffer();
        notifyListeners();
      });

      // Stream stderr in real-time
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _lines.add(TerminalLine(line, type: TerminalLineType.stderr));
        _trimBuffer();
        notifyListeners();
      });

      final exitCode = await proc.exitCode;
      if (exitCode != 0) {
        _lines.add(TerminalLine('Process exited with code $exitCode', type: TerminalLineType.system));
      }
    } catch (e, st) {
      Log.warning(_tag, 'Execution failed: $cmd', e, st);
      _lines.add(TerminalLine('Error executing command: $e', type: TerminalLineType.error));
    } finally {
      _runningProcess = null;
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Kills any running child process.
  void kill() {
    if (_runningProcess != null) {
      try {
        _runningProcess!.kill(io.ProcessSignal.sigkill);
      } catch (_) {
        try {
          _runningProcess!.kill();
        } catch (_) {}
      }
      _lines.add(TerminalLine('^C [Terminated by user]', type: TerminalLineType.system));
      _runningProcess = null;
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Trims buffer to prevent unbounded memory growth in long sessions.
  void _trimBuffer() {
    if (_lines.length > 2500) {
      _lines.removeRange(0, _lines.length - 2000);
    }
  }

  @override
  void dispose() {
    kill();
    super.dispose();
  }
}
