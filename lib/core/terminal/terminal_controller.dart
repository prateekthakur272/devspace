import 'package:flutter/foundation.dart';
import 'package:devspace/core/terminal/terminal_session.dart';
import 'package:devspace/utils/paths.dart';
import 'package:path/path.dart' as p;

/// Coordinates multiple terminal session tabs and active tab switching.
class TerminalController with ChangeNotifier {
  TerminalController({String? defaultCwd}) {
    if (defaultCwd != null) {
      createSession(cwd: defaultCwd);
    }
  }

  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;
  int _counter = 1;

  /// Callback invoked when the last terminal session is closed.
  VoidCallback? onAllSessionsClosed;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;

  TerminalSession get activeSession {
    if (_sessions.isEmpty) {
      return createSession();
    }
    if (_activeIndex < 0 || _activeIndex >= _sessions.length) {
      _activeIndex = 0;
    }
    return _sessions[_activeIndex];
  }

  /// Creates a new terminal tab session.
  TerminalSession createSession({String? cwd, String? title}) {
    final effectiveCwd = cwd ?? Paths.home;
    final defaultTitle = title ?? (p.basename(effectiveCwd).isNotEmpty ? p.basename(effectiveCwd) : 'zsh');

    final session = TerminalSession(
      id: 'term_${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      initialCwd: effectiveCwd,
      title: defaultTitle,
    );

    session.onExitRequested = () {
      closeSession(session.id);
    };

    session.addListener(_onSessionChanged);
    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    notifyListeners();
    return session;
  }

  /// Switches active terminal session tab.
  void selectSession(int index) {
    if (index >= 0 && index < _sessions.length && index != _activeIndex) {
      _activeIndex = index;
      notifyListeners();
    }
  }

  /// Closes the given session. If this was the last session, invokes [onAllSessionsClosed].
  void closeSession(String id) {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;

    final session = _sessions.removeAt(idx);
    session.removeListener(_onSessionChanged);
    session.dispose();

    if (_sessions.isEmpty) {
      _activeIndex = 0;
      notifyListeners();
      onAllSessionsClosed?.call();
      return;
    }

    _activeIndex = _activeIndex.clamp(0, _sessions.length - 1);
    notifyListeners();
  }

  /// Closes all open terminal sessions and invokes [onAllSessionsClosed].
  void closeAllSessions() {
    for (final s in _sessions) {
      s.removeListener(_onSessionChanged);
      s.dispose();
    }
    _sessions.clear();
    _activeIndex = 0;
    notifyListeners();
    onAllSessionsClosed?.call();
  }

  /// Opens a new terminal session for the specified directory.
  /// Each terminal open click starts a new session tab (allowing multiple sessions).
  TerminalSession openDirectory(String dirPath, {String? title}) {
    // If there is only one session that is completely untouched at the default home path,
    // adopt it so we don't leave an unused empty default tab behind.
    if (_sessions.length == 1 &&
        _sessions.first.history.isEmpty &&
        !_sessions.first.isExecuting &&
        _sessions.first.cwd == Paths.home) {
      _sessions.first.changeDirectory(dirPath);
      if (title != null) _sessions.first.title = title;
      notifyListeners();
      return _sessions.first;
    }

    // Every terminal open action creates and switches to a new terminal session tab
    return createSession(cwd: dirPath, title: title);
  }

  void _onSessionChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _sessions) {
      s.removeListener(_onSessionChanged);
      s.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
