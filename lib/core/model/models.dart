import 'dart:io';
import 'package:devspace/core/model/note_markdown.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Supported/detected technology stacks.
enum TechStack {
  flutter('Flutter', Color(0xFF02569B), 'assets/icons/flutter.svg'),
  react('React', Color(0xFF61DAFB), 'assets/icons/react.svg'),
  node('Node.js', Color(0xFF339933), 'assets/icons/node.svg'),
  rust('Rust', Color(0xFFDEA584), 'assets/icons/rust.svg'),
  go('Go', Color(0xFF00ADD8), 'assets/icons/go.svg'),
  python('Python', Color(0xFF3776AB), 'assets/icons/python.svg'),
  kotlin('Kotlin', Color(0xFF7F52FF), 'assets/icons/kotlin.svg'),
  swift('Swift', Color(0xFFFA7343), 'assets/icons/swift.svg'),
  java('Java', Color(0xFFED8B00), 'assets/icons/java.svg'),
  cpp('C / C++', Color(0xFF00599C), 'assets/icons/cpp.svg'),
  general('Generic', Color(0xFF6C757D), 'assets/icons/code.svg');

  const TechStack(this.label, this.color, this.assetPath);
  final String label;
  final Color color;
  final String assetPath;

  static TechStack detect(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return TechStack.general;

      final files = dir.listSync().map((e) => p.basename(e.path)).toSet();

      if (files.contains('pubspec.yaml')) return TechStack.flutter;
      if (files.contains('Cargo.toml')) return TechStack.rust;
      if (files.contains('go.mod')) return TechStack.go;
      if (files.contains('pyproject.toml') ||
          files.contains('requirements.txt') ||
          files.contains('Pipfile')) {
        return TechStack.python;
      }
      if (files.contains('package.json')) {
        try {
          final pkgJson = File(p.join(dirPath, 'package.json')).readAsStringSync();
          if (pkgJson.contains('"react"') || pkgJson.contains('"next"')) {
            return TechStack.react;
          }
        } catch (_) {}
        return TechStack.node;
      }
      if (files.contains('build.gradle') || files.contains('build.gradle.kts')) {
        return files.contains('build.gradle.kts') ? TechStack.kotlin : TechStack.java;
      }
      if (files.any((f) => f.endsWith('.xcodeproj') || f == 'Podfile')) {
        return TechStack.swift;
      }
      if (files.contains('CMakeLists.txt') || files.contains('Makefile')) {
        return TechStack.cpp;
      }
    } catch (_) {}
    return TechStack.general;
  }
}

/// Known IDEs and code editors.
enum EditorType {
  vscode('Visual Studio Code', 'code', ['Visual Studio Code.app'], 'Code.exe'),
  cursor('Cursor', 'cursor', ['Cursor.app'], 'Cursor.exe'),
  vscodium('VSCodium', 'codium', ['VSCodium.app'], 'VSCodium.exe'),
  androidStudio('Android Studio', 'studio', ['Android Studio.app', 'Android Studio Preview.app'], 'studio64.exe'),
  intellij('IntelliJ IDEA', 'idea', ['IntelliJ IDEA.app', 'IntelliJ IDEA Ultimate.app', 'IntelliJ IDEA CE.app', 'IntelliJ IDEA Community Edition.app'], 'idea64.exe'),
  xcode('Xcode', 'xcode', ['Xcode.app', 'Xcode-beta.app'], ''),
  zed('Zed', 'zed', ['Zed.app', 'Zed Preview.app'], 'zed.exe'),
  sublime('Sublime Text', 'subl', ['Sublime Text.app'], 'sublime_text.exe'),
  webstorm('WebStorm', 'webstorm', ['WebStorm.app'], 'webstorm64.exe'),
  pycharm('PyCharm', 'pycharm', ['PyCharm.app', 'PyCharm Professional.app', 'PyCharm CE.app', 'PyCharm Community Edition.app'], 'pycharm64.exe'),
  rustrover('RustRover', 'rustrover', ['RustRover.app'], 'rustrover64.exe'),
  goland('GoLand', 'goland', ['GoLand.app'], 'goland64.exe'),
  clion('CLion', 'clion', ['CLion.app'], 'clion64.exe'),
  fleet('Fleet', 'fleet', ['Fleet.app'], 'Fleet.exe'),
  terminal('Terminal / Neovim', 'nvim', ['Terminal.app', 'Ghostty.app', 'iTerm.app'], 'cmd.exe'),
  custom('Custom IDE', '', [], '');

  const EditorType(this.label, this.cliCmd, this.macAppVariants, this.winExe);
  final String label;
  final String cliCmd;
  final List<String> macAppVariants;
  final String winExe;

  String get macApp => macAppVariants.isNotEmpty ? macAppVariants.first : '';

  static EditorType fromId(String? id) {
    if (id == null) return EditorType.vscode;
    for (final e in EditorType.values) {
      if (e.name == id || e.cliCmd == id) return e;
    }
    return EditorType.vscode;
  }
}

/// Git status of a project repository.
class GitRepoStatus {
  final bool isGitRepo;
  final String branch;
  final int modifiedCount;
  final int stagedCount;
  final int untrackedCount;
  final int aheadCount;
  final int behindCount;
  final bool hasStash;
  final DateTime lastChecked;
  final String? errorMessage;
  final String? lastCommitMessage;
  final String? lastCommitHash;
  final DateTime? lastCommitDate;
  final String? lastCommitAuthor;
  final String? lastTag;
  final String? upstream;
  final String? remoteUrl;

  const GitRepoStatus({
    this.isGitRepo = false,
    this.branch = '',
    this.modifiedCount = 0,
    this.stagedCount = 0,
    this.untrackedCount = 0,
    this.aheadCount = 0,
    this.behindCount = 0,
    this.hasStash = false,
    required this.lastChecked,
    this.errorMessage,
    this.lastCommitMessage,
    this.lastCommitHash,
    this.lastCommitDate,
    this.lastCommitAuthor,
    this.lastTag,
    this.upstream,
    this.remoteUrl,
  });

  bool get isClean =>
      isGitRepo &&
      modifiedCount == 0 &&
      stagedCount == 0 &&
      untrackedCount == 0;

  bool get isDirty => isGitRepo && !isClean;

  bool get needsSync => isGitRepo && (aheadCount > 0 || behindCount > 0);

  bool get isSynced =>
      isGitRepo && aheadCount == 0 && behindCount == 0 && upstream != null;

  int get totalChanges => modifiedCount + stagedCount + untrackedCount;

  static GitRepoStatus empty() => GitRepoStatus(
        isGitRepo: false,
        lastChecked: DateTime.now(),
      );
}

/// Individual project entry in DevSpace.
class Project {
  final String id;
  final String name;
  final String path;
  final TechStack techStack;
  final EditorType defaultEditor;
  final String? customEditorCommand;
  final List<String> tags;
  final bool pinned;
  final String workspaceId;
  final DateTime? lastOpenedAt;
  final DateTime createdAt;
  final List<String> customScripts;

  const Project({
    required this.id,
    required this.name,
    required this.path,
    required this.techStack,
    this.defaultEditor = EditorType.vscode,
    this.customEditorCommand,
    this.tags = const [],
    this.pinned = false,
    this.workspaceId = 'default',
    this.lastOpenedAt,
    required this.createdAt,
    this.customScripts = const [],
  });

  Project copyWith({
    String? name,
    String? path,
    TechStack? techStack,
    EditorType? defaultEditor,
    String? customEditorCommand,
    List<String>? tags,
    bool? pinned,
    String? workspaceId,
    DateTime? lastOpenedAt,
    List<String>? customScripts,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        path: path ?? this.path,
        techStack: techStack ?? this.techStack,
        defaultEditor: defaultEditor ?? this.defaultEditor,
        customEditorCommand: customEditorCommand ?? this.customEditorCommand,
        tags: tags ?? this.tags,
        pinned: pinned ?? this.pinned,
        workspaceId: workspaceId ?? this.workspaceId,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        createdAt: createdAt,
        customScripts: customScripts ?? this.customScripts,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'techStack': techStack.name,
        'defaultEditor': defaultEditor.name,
        if (customEditorCommand != null) 'customEditorCommand': customEditorCommand,
        'tags': tags,
        'pinned': pinned,
        'workspaceId': workspaceId,
        if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'customScripts': customScripts,
      };

  factory Project.fromJson(Map<String, dynamic> m) {
    return Project(
      id: m['id'] as String? ?? UniqueKey().toString(),
      name: m['name'] as String? ?? 'Untitled Project',
      path: m['path'] as String? ?? '',
      techStack: TechStack.values.firstWhere(
        (e) => e.name == m['techStack'],
        orElse: () => TechStack.general,
      ),
      defaultEditor: EditorType.fromId(m['defaultEditor'] as String?),
      customEditorCommand: m['customEditorCommand'] as String?,
      tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pinned: m['pinned'] as bool? ?? false,
      workspaceId: m['workspaceId'] as String? ?? 'default',
      lastOpenedAt: m['lastOpenedAt'] != null
          ? DateTime.tryParse(m['lastOpenedAt'].toString())
          : null,
      createdAt: m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customScripts:
          (m['customScripts'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Preset icons available for Workspace Groups.
const List<IconData> kGroupPresetIcons = [
  Icons.folder_rounded,
  Icons.work_rounded,
  Icons.home_rounded,
  Icons.star_rounded,
  Icons.terminal_rounded,
  Icons.code_rounded,
  Icons.laptop_mac_rounded,
  Icons.smartphone_rounded,
  Icons.cloud_rounded,
  Icons.storage_rounded,
  Icons.api_rounded,
  Icons.web_rounded,
  Icons.rocket_launch_rounded,
  Icons.alt_route_rounded,
  Icons.build_rounded,
  Icons.science_rounded,
  Icons.bug_report_rounded,
  Icons.security_rounded,
  Icons.brush_rounded,
  Icons.psychology_rounded,
  Icons.smart_toy_rounded,
  Icons.gamepad_rounded,
  Icons.school_rounded,
  Icons.public_rounded,
];

/// Workspace group / folder for organizing projects.
class WorkspaceGroup {
  final String id;
  final String name;
  final Color color;
  final IconData? icon;

  const WorkspaceGroup({
    required this.id,
    required this.name,
    this.color = const Color(0xFF6750A4),
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        if (icon != null) 'iconCode': icon!.codePoint,
      };

  factory WorkspaceGroup.fromJson(Map<String, dynamic> m) => WorkspaceGroup(
        id: m['id'] as String? ?? 'default',
        name: m['name'] as String? ?? 'General',
        color: m['color'] != null
            ? Color((m['color'] as num).toInt())
            : const Color(0xFF6750A4),
        icon: m['iconCode'] != null
            ? kGroupPresetIcons.cast<IconData?>().firstWhere(
                (ic) => ic?.codePoint == m['iconCode'],
                orElse: () => null,
              )
            : null,
      );

  WorkspaceGroup copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    bool clearIcon = false,
  }) =>
      WorkspaceGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: clearIcon ? null : (icon ?? this.icon),
      );
}

/// A desktop application the user pinned to the tools rail.
class PinnedApp {
  final String name;
  final String path;

  const PinnedApp({required this.name, required this.path});

  /// Stable id used for the cached icon file.
  String get iconId => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

  Map<String, dynamic> toJson() => {'name': name, 'path': path};

  static PinnedApp? fromJson(Object? j) {
    if (j is! Map) return null;
    final path = j['path'];
    if (path is! String || path.isEmpty) return null;
    final name = j['name'];
    return PinnedApp(name: name is String && name.isNotEmpty ? name : path, path: path);
  }
}

/// Terminal preference option (Integrated DevSpace panel vs. External OS app).
enum DefaultTerminalType {
  integrated('integrated', 'Integrated Terminal', 'DevSpace built-in bottom terminal panel'),
  system('system', 'System Terminal', 'External OS terminal application');

  const DefaultTerminalType(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  bool get isIntegrated => this == DefaultTerminalType.integrated;
  bool get isSystem => this == DefaultTerminalType.system;

  static DefaultTerminalType fromId(String? id) {
    if (id == 'system') return DefaultTerminalType.system;
    return DefaultTerminalType.integrated;
  }
}

/// App settings.
class AppSettings {
  final ThemeMode themeMode;
  final EditorType defaultEditor;
  final DefaultTerminalType defaultTerminal;
  final String terminalEmulator;
  final int gitRefreshIntervalSeconds;
  final bool autoDetectProjects;
  final bool showToolsRail;
  final List<PinnedApp> pinnedApps;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultEditor = EditorType.vscode,
    this.defaultTerminal = DefaultTerminalType.integrated,
    this.terminalEmulator = 'default',
    this.gitRefreshIntervalSeconds = 30,
    this.autoDetectProjects = true,
    this.showToolsRail = true,
    this.pinnedApps = const [],
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    EditorType? defaultEditor,
    DefaultTerminalType? defaultTerminal,
    String? terminalEmulator,
    int? gitRefreshIntervalSeconds,
    bool? autoDetectProjects,
    bool? showToolsRail,
    List<PinnedApp>? pinnedApps,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultEditor: defaultEditor ?? this.defaultEditor,
        defaultTerminal: defaultTerminal ?? this.defaultTerminal,
        terminalEmulator: terminalEmulator ?? this.terminalEmulator,
        gitRefreshIntervalSeconds:
            gitRefreshIntervalSeconds ?? this.gitRefreshIntervalSeconds,
        autoDetectProjects: autoDetectProjects ?? this.autoDetectProjects,
        showToolsRail: showToolsRail ?? this.showToolsRail,
        pinnedApps: pinnedApps ?? this.pinnedApps,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultEditor': defaultEditor.name,
        'defaultTerminal': defaultTerminal.id,
        'terminalEmulator': terminalEmulator,
        'gitRefreshIntervalSeconds': gitRefreshIntervalSeconds,
        'autoDetectProjects': autoDetectProjects,
        'showToolsRail': showToolsRail,
        'pinnedApps': pinnedApps.map((a) => a.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic>? m) {
    if (m == null) return const AppSettings();
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == m['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      defaultEditor: EditorType.fromId(m['defaultEditor'] as String?),
      defaultTerminal: DefaultTerminalType.fromId(m['defaultTerminal'] as String?),
      terminalEmulator: m['terminalEmulator'] as String? ?? 'default',
      gitRefreshIntervalSeconds:
          (m['gitRefreshIntervalSeconds'] as num?)?.toInt() ?? 30,
      autoDetectProjects: m['autoDetectProjects'] as bool? ?? true,
      showToolsRail: m['showToolsRail'] as bool? ?? true,
      pinnedApps: (m['pinnedApps'] as List?)
              ?.map(PinnedApp.fromJson)
              .whereType<PinnedApp>()
              .toList() ??
          const [],
    );
  }
}

/// Window position and dimension persistence.
class WindowGeometry {
  final double width;
  final double height;
  final double? x;
  final double? y;
  final bool maximized;

  const WindowGeometry(
    this.width,
    this.height, [
    this.x,
    this.y,
    this.maximized = false,
  ]);

  WindowGeometry copyWith({bool? maximized}) => WindowGeometry(
        width,
        height,
        x,
        y,
        maximized ?? this.maximized,
      );

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        'maximized': maximized,
      };

  factory WindowGeometry.fromJson(Map<String, dynamic>? m) {
    if (m == null) return const WindowGeometry(1360, 860);
    return WindowGeometry(
      (m['width'] as num?)?.toDouble() ?? 1360,
      (m['height'] as num?)?.toDouble() ?? 860,
      (m['x'] as num?)?.toDouble(),
      (m['y'] as num?)?.toDouble(),
      m['maximized'] as bool? ?? false,
    );
  }
}

/// Checklist item within a note.
class ChecklistItem {
  final String id;
  final String text;
  final bool checked;

  const ChecklistItem({
    required this.id,
    required this.text,
    this.checked = false,
  });

  ChecklistItem copyWith({
    String? id,
    String? text,
    bool? checked,
  }) =>
      ChecklistItem(
        id: id ?? this.id,
        text: text ?? this.text,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String? ?? 'chk_${DateTime.now().microsecondsSinceEpoch}',
        text: json['text'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
      );
}

/// Developer workspace note with checklist, links, and project tagging.
class Note {
  final String id;
  final String title;
  final String content;
  final List<ChecklistItem> checklist;
  final List<String> projectIds;
  final List<String> tags;
  final List<String> links;
  final bool pinned;
  final Color? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.checklist = const [],
    this.projectIds = const [],
    this.tags = const [],
    this.links = const [],
    this.pinned = false,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Human-readable body (no markdown markers, no checklist lines) for cards.
  String get plainContent => NoteMarkdown.plain(content);

  /// True when the note has neither title nor meaningful content/checklist.
  bool get isEmpty {
    if (title.trim().isNotEmpty) return false;
    if (checklist.any((c) => c.text.trim().isNotEmpty)) return false;
    if (links.isNotEmpty) return false;
    for (final b in NoteMarkdown.parse(content)) {
      if (b.type == BlockType.todo) {
        if (b.text.trim().isNotEmpty) return false;
        continue;
      }
      final t = b.text
          .replaceAll(RegExp(r'@[a-zA-Z0-9_\-]+'), '')
          .replaceAll(RegExp(r'#[a-zA-Z0-9_\-]+'), '')
          .trim();
      if (t.isNotEmpty) return false;
    }
    return true;
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<ChecklistItem>? checklist,
    List<String>? projectIds,
    List<String>? tags,
    List<String>? links,
    bool? pinned,
    Color? color,
    bool clearColor = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        checklist: checklist ?? this.checklist,
        projectIds: projectIds ?? this.projectIds,
        tags: tags ?? this.tags,
        links: links ?? this.links,
        pinned: pinned ?? this.pinned,
        color: clearColor ? null : (color ?? this.color),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'projectIds': projectIds,
        'tags': tags,
        'links': links,
        'pinned': pinned,
        if (color != null) 'color': color!.value,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String? ?? 'note_${DateTime.now().microsecondsSinceEpoch}',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        checklist: (json['checklist'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ChecklistItem.fromJson)
                .toList() ??
            const [],
        projectIds: (json['projectIds'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        tags: (json['tags'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        links: (json['links'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        pinned: json['pinned'] as bool? ?? false,
        color: json['color'] != null ? Color(json['color'] as int) : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Sorting options for project list.
enum ProjectSortOption {
  lastOpened('Last Opened', Icons.schedule_rounded),
  nameAsc('Name (A–Z)', Icons.sort_by_alpha_rounded),
  nameDesc('Name (Z–A)', Icons.sort_by_alpha_rounded),
  recentlyAdded('Recently Added', Icons.fiber_new_rounded),
  gitStatus('Git Status (Dirty First)', Icons.sync_problem_rounded);

  const ProjectSortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Saved UI state across sessions.
class SavedState {
  final double sidebarWidth;
  final bool sidebarVisible;
  final double notesPaneWidth;
  final bool notesPaneVisible;
  final double terminalHeight;
  final bool terminalVisible;
  final String activeTab;
  final String selectedWorkspaceId;
  final String? activeTagFilter;
  final String searchQuery;
  final ProjectSortOption sortBy;
  final WindowGeometry? window;

  const SavedState({
    this.sidebarWidth = 270,
    this.sidebarVisible = true,
    this.notesPaneWidth = 320,
    this.notesPaneVisible = true,
    this.terminalHeight = 250,
    this.terminalVisible = false,
    this.activeTab = 'projects', // 'projects' | 'git_radar'
    this.selectedWorkspaceId = 'all',
    this.activeTagFilter,
    this.searchQuery = '',
    this.sortBy = ProjectSortOption.lastOpened,
    this.window,
  });

  SavedState copyWith({
    double? sidebarWidth,
    bool? sidebarVisible,
    double? notesPaneWidth,
    bool? notesPaneVisible,
    double? terminalHeight,
    bool? terminalVisible,
    String? activeTab,
    String? selectedWorkspaceId,
    String? activeTagFilter,
    bool clearTagFilter = false,
    String? searchQuery,
    ProjectSortOption? sortBy,
    WindowGeometry? window,
  }) =>
      SavedState(
        sidebarWidth: sidebarWidth ?? this.sidebarWidth,
        sidebarVisible: sidebarVisible ?? this.sidebarVisible,
        notesPaneWidth: notesPaneWidth ?? this.notesPaneWidth,
        notesPaneVisible: notesPaneVisible ?? this.notesPaneVisible,
        terminalHeight: terminalHeight ?? this.terminalHeight,
        terminalVisible: terminalVisible ?? this.terminalVisible,
        activeTab: activeTab ?? this.activeTab,
        selectedWorkspaceId: selectedWorkspaceId ?? this.selectedWorkspaceId,
        activeTagFilter: clearTagFilter ? null : (activeTagFilter ?? this.activeTagFilter),
        searchQuery: searchQuery ?? this.searchQuery,
        sortBy: sortBy ?? this.sortBy,
        window: window ?? this.window,
      );

  Map<String, dynamic> toJson() => {
        'sidebarWidth': sidebarWidth,
        'sidebarVisible': sidebarVisible,
        'notesPaneWidth': notesPaneWidth,
        'notesPaneVisible': notesPaneVisible,
        'terminalHeight': terminalHeight,
        'terminalVisible': terminalVisible,
        'activeTab': activeTab,
        'selectedWorkspaceId': selectedWorkspaceId,
        if (activeTagFilter != null) 'activeTagFilter': activeTagFilter,
        'searchQuery': searchQuery,
        'sortBy': sortBy.name,
        if (window != null) 'window': window!.toJson(),
      };

  factory SavedState.fromJson(Map<String, dynamic>? m) {
    if (m == null) return const SavedState();
    return SavedState(
      sidebarWidth: (m['sidebarWidth'] as num?)?.toDouble() ?? 240,
      sidebarVisible: m['sidebarVisible'] as bool? ?? true,
      notesPaneWidth: (m['notesPaneWidth'] as num?)?.toDouble() ?? 320,
      notesPaneVisible: m['notesPaneVisible'] as bool? ?? true,
      terminalHeight: (m['terminalHeight'] as num?)?.toDouble() ?? 250,
      terminalVisible: m['terminalVisible'] as bool? ?? false,
      activeTab: m['activeTab'] as String? ?? 'projects',
      selectedWorkspaceId: m['selectedWorkspaceId'] as String? ?? 'all',
      activeTagFilter: m['activeTagFilter'] as String?,
      searchQuery: m['searchQuery'] as String? ?? '',
      sortBy: ProjectSortOption.values.firstWhere(
        (e) => e.name == m['sortBy'],
        orElse: () => ProjectSortOption.lastOpened,
      ),
      window: m['window'] != null ? WindowGeometry.fromJson(m['window']) : null,
    );
  }
}
