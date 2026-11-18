import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:devspace/theme/icons.dart';
import 'package:path/path.dart' as p;

enum SuggestionCategory {
  history('History', Icons.history_rounded),
  git('Git', AppIcons.branch),
  project('Project', AppIcons.play),
  shell('Shell', AppIcons.terminal),
  file('File / Path', AppIcons.folder);

  const SuggestionCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A rich autocomplete suggestion for the integrated terminal.
class TerminalSuggestion {
  final String command;
  final String description;
  final SuggestionCategory category;
  final String? badge;

  const TerminalSuggestion({
    required this.command,
    required this.description,
    required this.category,
    this.badge,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalSuggestion && runtimeType == other.runtimeType && command == other.command;

  @override
  int get hashCode => command.hashCode;
}

/// Autocomplete and suggestion engine for integrated terminal commands.
class TerminalSuggestionsEngine {
  TerminalSuggestionsEngine._();

  /// Synchronously discovers current git branch by looking for .git/HEAD up the directory tree.
  static String? getGitBranch(String dirPath) {
    try {
      var current = io.Directory(dirPath);
      for (int i = 0; i < 6; i++) {
        final gitHead = io.File(p.join(current.path, '.git', 'HEAD'));
        if (gitHead.existsSync()) {
          final content = gitHead.readAsStringSync().trim();
          if (content.startsWith('ref: refs/heads/')) {
            return content.substring('ref: refs/heads/'.length);
          }
          return content.length > 7 ? content.substring(0, 7) : content;
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}
    return null;
  }

  /// Detects project capabilities in the given working directory.
  static Set<String> detectProjectCapabilities(String dirPath) {
    final caps = <String>{};
    try {
      if (io.File(p.join(dirPath, 'pubspec.yaml')).existsSync()) caps.add('flutter');
      if (io.File(p.join(dirPath, 'package.json')).existsSync()) caps.add('node');
      if (io.File(p.join(dirPath, 'Cargo.toml')).existsSync()) caps.add('rust');
      if (io.File(p.join(dirPath, 'requirements.txt')).existsSync() ||
          io.File(p.join(dirPath, 'pyproject.toml')).existsSync()) {
        caps.add('python');
      }
      if (io.File(p.join(dirPath, 'go.mod')).existsSync()) caps.add('go');
      if (io.File(p.join(dirPath, 'docker-compose.yml')).existsSync() ||
          io.File(p.join(dirPath, 'Dockerfile')).existsSync()) {
        caps.add('docker');
      }
      if (getGitBranch(dirPath) != null) caps.add('git');
    } catch (_) {}
    return caps;
  }

  /// Returns contextual suggestions filtered by [query] and working directory [cwd].
  static List<TerminalSuggestion> getSuggestions({
    required String query,
    required String cwd,
    List<String> history = const [],
    int limit = 7,
  }) {
    final trimmed = query.trim();
    final lower = trimmed.toLowerCase();
    final caps = detectProjectCapabilities(cwd);

    final results = <TerminalSuggestion>[];
    final seen = <String>{};

    // 1. History matches (matching user's previously executed commands)
    if (trimmed.isNotEmpty) {
      for (final cmd in history.reversed) {
        final cl = cmd.toLowerCase();
        if (cl.startsWith(lower) && !seen.contains(cmd)) {
          seen.add(cmd);
          results.add(TerminalSuggestion(
            command: cmd,
            description: 'Recent command from history',
            category: SuggestionCategory.history,
            badge: 'HIST',
          ));
          if (results.length >= limit) return results;
        }
      }
    }

    // 2. Local directory / file completion (for cd, cat, ls, open, etc.)
    final fileSuggestions = _suggestFilesAndDirs(trimmed, cwd);
    for (final s in fileSuggestions) {
      if (!seen.contains(s.command)) {
        seen.add(s.command);
        results.add(s);
        if (results.length >= limit) return results;
      }
    }

    // 3. Built-in command knowledge base
    final candidates = _buildCandidateList(caps, includeGit: caps.contains('git') || lower.startsWith('git') || trimmed.isEmpty);

    if (trimmed.isEmpty) {
      // Empty query: provide top contextual starting actions
      for (final s in candidates) {
        if (!seen.contains(s.command)) {
          seen.add(s.command);
          results.add(s);
          if (results.length >= limit) break;
        }
      }
      return results;
    }

    // Prefix matches first
    for (final s in candidates) {
      final cmd = s.command.toLowerCase();
      if (cmd.startsWith(lower) && !seen.contains(s.command)) {
        seen.add(s.command);
        results.add(s);
        if (results.length >= limit) return results;
      }
    }

    // Substring / fuzzy matches next
    for (final s in candidates) {
      final cmd = s.command.toLowerCase();
      if (cmd.contains(lower) && !seen.contains(s.command)) {
        seen.add(s.command);
        results.add(s);
        if (results.length >= limit) return results;
      }
    }

    return results;
  }

  static List<TerminalSuggestion> _suggestFilesAndDirs(String query, String cwd) {
    final list = <TerminalSuggestion>[];
    String prefixCmd = '';
    String pathPrefix = '';

    const pathCommands = ['cd ', 'cat ', 'ls ', 'open ', 'rm ', 'vim ', 'nano '];
    for (final cmd in pathCommands) {
      if (query.startsWith(cmd)) {
        prefixCmd = cmd;
        pathPrefix = query.substring(cmd.length);
        break;
      }
    }

    if (prefixCmd.isEmpty) return list;

    try {
      final dir = io.Directory(cwd);
      if (!dir.existsSync()) return list;

      final entries = dir.listSync(followLinks: false);
      for (final e in entries) {
        final name = p.basename(e.path);
        if (name.startsWith('.') && !pathPrefix.startsWith('.')) continue;

        final isDir = e is io.Directory;
        if (prefixCmd == 'cd ' && !isDir) continue;

        if (name.toLowerCase().startsWith(pathPrefix.toLowerCase())) {
          final target = isDir ? '$name/' : name;
          list.add(TerminalSuggestion(
            command: '$prefixCmd$target',
            description: isDir ? 'Directory in current folder' : 'File in current folder',
            category: SuggestionCategory.file,
            badge: isDir ? 'DIR' : 'FILE',
          ));
        }
      }
    } catch (_) {}

    return list;
  }

  static List<TerminalSuggestion> _buildCandidateList(Set<String> caps, {bool includeGit = true}) {
    final list = <TerminalSuggestion>[];

    // Project-specific suggestions prioritized
    if (caps.contains('flutter')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'flutter run',
          description: 'Run app in debug mode on active device',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'flutter test',
          description: 'Run all Flutter unit and widget tests',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'flutter pub get',
          description: 'Download and resolve package dependencies',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'flutter analyze',
          description: 'Analyze the project Dart source code for issues',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'flutter clean',
          description: 'Delete the build/ and .dart_tool/ cache folders',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'flutter build macos',
          description: 'Build production macOS release bundle',
          category: SuggestionCategory.project,
          badge: 'FLUTTER',
        ),
        TerminalSuggestion(
          command: 'dart format .',
          description: 'Format all Dart code in current directory',
          category: SuggestionCategory.project,
          badge: 'DART',
        ),
      ]);
    }

    if (caps.contains('node')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'npm run dev',
          description: 'Start local development server',
          category: SuggestionCategory.project,
          badge: 'NPM',
        ),
        TerminalSuggestion(
          command: 'npm test',
          description: 'Execute test runner script',
          category: SuggestionCategory.project,
          badge: 'NPM',
        ),
        TerminalSuggestion(
          command: 'npm start',
          description: 'Start application in production mode',
          category: SuggestionCategory.project,
          badge: 'NPM',
        ),
        TerminalSuggestion(
          command: 'npm install',
          description: 'Install dependencies from package.json',
          category: SuggestionCategory.project,
          badge: 'NPM',
        ),
        TerminalSuggestion(
          command: 'pnpm dev',
          description: 'Start development server with pnpm',
          category: SuggestionCategory.project,
          badge: 'PNPM',
        ),
      ]);
    }

    if (caps.contains('rust')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'cargo run',
          description: 'Build and run binary package',
          category: SuggestionCategory.project,
          badge: 'CARGO',
        ),
        TerminalSuggestion(
          command: 'cargo test',
          description: 'Run unit and integration tests',
          category: SuggestionCategory.project,
          badge: 'CARGO',
        ),
        TerminalSuggestion(
          command: 'cargo check',
          description: 'Fast compilation check without code generation',
          category: SuggestionCategory.project,
          badge: 'CARGO',
        ),
        TerminalSuggestion(
          command: 'cargo build --release',
          description: 'Build optimized release binary',
          category: SuggestionCategory.project,
          badge: 'CARGO',
        ),
      ]);
    }

    if (caps.contains('python')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'python3 main.py',
          description: 'Execute main Python script',
          category: SuggestionCategory.project,
          badge: 'PYTHON',
        ),
        TerminalSuggestion(
          command: 'pytest',
          description: 'Run pytest test suite',
          category: SuggestionCategory.project,
          badge: 'PYTHON',
        ),
        TerminalSuggestion(
          command: 'pip install -r requirements.txt',
          description: 'Install Python dependencies',
          category: SuggestionCategory.project,
          badge: 'PIP',
        ),
      ]);
    }

    if (caps.contains('go')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'go run .',
          description: 'Compile and run Go package',
          category: SuggestionCategory.project,
          badge: 'GO',
        ),
        TerminalSuggestion(
          command: 'go test ./...',
          description: 'Run all Go unit tests recursively',
          category: SuggestionCategory.project,
          badge: 'GO',
        ),
        TerminalSuggestion(
          command: 'go build',
          description: 'Compile Go binary executable',
          category: SuggestionCategory.project,
          badge: 'GO',
        ),
      ]);
    }

    if (caps.contains('docker')) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'docker compose up -d',
          description: 'Start containers in detached background mode',
          category: SuggestionCategory.project,
          badge: 'DOCKER',
        ),
        TerminalSuggestion(
          command: 'docker compose down',
          description: 'Stop and remove containers, networks, and images',
          category: SuggestionCategory.project,
          badge: 'DOCKER',
        ),
        TerminalSuggestion(
          command: 'docker ps',
          description: 'List running Docker containers',
          category: SuggestionCategory.project,
          badge: 'DOCKER',
        ),
      ]);
    }

    // Git commands
    if (includeGit) {
      list.addAll(const [
        TerminalSuggestion(
          command: 'git status',
          description: 'Show modified files and working tree status',
          category: SuggestionCategory.git,
          badge: 'STATUS',
        ),
        TerminalSuggestion(
          command: 'git pull',
          description: 'Fetch and integrate remote changes',
          category: SuggestionCategory.git,
          badge: 'PULL',
        ),
        TerminalSuggestion(
          command: 'git push',
          description: 'Update remote repository with local commits',
          category: SuggestionCategory.git,
          badge: 'PUSH',
        ),
        TerminalSuggestion(
          command: 'git diff',
          description: 'Show unstaged changes in working tree',
          category: SuggestionCategory.git,
          badge: 'DIFF',
        ),
        TerminalSuggestion(
          command: 'git log --oneline -n 10',
          description: 'View recent 10 commits compactly',
          category: SuggestionCategory.git,
          badge: 'LOG',
        ),
        TerminalSuggestion(
          command: 'git commit -m ""',
          description: 'Record changes to the repository',
          category: SuggestionCategory.git,
          badge: 'COMMIT',
        ),
        TerminalSuggestion(
          command: 'git add .',
          description: 'Stage all modified and new files',
          category: SuggestionCategory.git,
          badge: 'ADD',
        ),
        TerminalSuggestion(
          command: 'git branch -a',
          description: 'List all local and remote branches',
          category: SuggestionCategory.git,
          badge: 'BRANCH',
        ),
        TerminalSuggestion(
          command: 'git checkout -b ',
          description: 'Create and switch to a new branch',
          category: SuggestionCategory.git,
          badge: 'BRANCH',
        ),
        TerminalSuggestion(
          command: 'git stash',
          description: 'Temporarily shelve dirty changes',
          category: SuggestionCategory.git,
          badge: 'STASH',
        ),
        TerminalSuggestion(
          command: 'git stash pop',
          description: 'Apply and drop latest stashed changes',
          category: SuggestionCategory.git,
          badge: 'STASH',
        ),
        TerminalSuggestion(
          command: 'git fetch --all --prune',
          description: 'Fetch all remotes and prune deleted branches',
          category: SuggestionCategory.git,
          badge: 'FETCH',
        ),
      ]);
    }

    // Universal Shell commands
    list.addAll(const [
      TerminalSuggestion(
        command: 'ls -la',
        description: 'List detailed directory contents including hidden files',
        category: SuggestionCategory.shell,
        badge: 'LIST',
      ),
      TerminalSuggestion(
        command: 'pwd',
        description: 'Print absolute path of current working directory',
        category: SuggestionCategory.shell,
        badge: 'PATH',
      ),
      TerminalSuggestion(
        command: 'clear',
        description: 'Clear terminal output buffer and screen',
        category: SuggestionCategory.shell,
        badge: 'CLEAR',
      ),
      TerminalSuggestion(
        command: 'cd ..',
        description: 'Navigate up to parent directory',
        category: SuggestionCategory.shell,
        badge: 'NAV',
      ),
      TerminalSuggestion(
        command: 'mkdir ',
        description: 'Create a new directory folder',
        category: SuggestionCategory.shell,
        badge: 'FS',
      ),
      TerminalSuggestion(
        command: 'cat ',
        description: 'Output contents of a file to screen',
        category: SuggestionCategory.shell,
        badge: 'FS',
      ),
      TerminalSuggestion(
        command: 'grep -rn "" .',
        description: 'Search recursively for text string in files',
        category: SuggestionCategory.shell,
        badge: 'SEARCH',
      ),
      TerminalSuggestion(
        command: 'open .',
        description: 'Reveal current folder in native desktop file manager',
        category: SuggestionCategory.shell,
        badge: 'DESKTOP',
      ),
    ]);

    return list;
  }
}
