import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/shell/app_shell.dart';
import 'package:devspace/features/shell/window_chrome.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_docs_screens_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);
    GitService.disableExecutionForTesting = true;
  });

  tearDown(() {
    GitService.disableExecutionForTesting = false;
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  List<Project> createMockProjects() {
    final now = DateTime.now();
    return [
      Project(
        id: 'proj_devspace',
        name: 'DevSpace',
        path: '/Users/developer/Workspace/devspace',
        techStack: TechStack.flutter,
        defaultEditor: EditorType.vscode,
        tags: ['flutter', 'desktop', 'dart'],
        pinned: true,
        workspaceId: 'grp_core',
        createdAt: now.subtract(const Duration(days: 30)),
        lastOpenedAt: now.subtract(const Duration(minutes: 5)),
      ),
      Project(
        id: 'proj_openrest',
        name: 'OpenRest',
        path: '/Users/developer/Workspace/open_rest',
        techStack: TechStack.flutter,
        defaultEditor: EditorType.intellij,
        tags: ['desktop', 'api-client', 'http'],
        pinned: true,
        workspaceId: 'grp_core',
        createdAt: now.subtract(const Duration(days: 45)),
        lastOpenedAt: now.subtract(const Duration(hours: 1)),
      ),
      Project(
        id: 'proj_gateway',
        name: 'Apollo Gateway',
        path: '/Users/developer/Workspace/services/apollo-gateway',
        techStack: TechStack.go,
        defaultEditor: EditorType.cursor,
        tags: ['go', 'graphql', 'backend'],
        workspaceId: 'grp_infra',
        createdAt: now.subtract(const Duration(days: 60)),
        lastOpenedAt: now.subtract(const Duration(hours: 3)),
      ),
      Project(
        id: 'proj_hyperdrive',
        name: 'HyperDrive Engine',
        path: '/Users/developer/Workspace/systems/hyperdrive',
        techStack: TechStack.rust,
        defaultEditor: EditorType.zed,
        tags: ['rust', 'streaming', 'perf'],
        workspaceId: 'grp_infra',
        createdAt: now.subtract(const Duration(days: 90)),
        lastOpenedAt: now.subtract(const Duration(days: 1)),
      ),
      Project(
        id: 'proj_web',
        name: 'Web Dashboard',
        path: '/Users/developer/Workspace/web/dashboard',
        techStack: TechStack.node,
        defaultEditor: EditorType.vscode,
        tags: ['react', 'typescript', 'tailwind'],
        workspaceId: 'grp_web',
        createdAt: now.subtract(const Duration(days: 20)),
        lastOpenedAt: now.subtract(const Duration(days: 2)),
      ),
      Project(
        id: 'proj_pipeline',
        name: 'Telemetry Pipeline',
        path: '/Users/developer/Workspace/data/pipeline',
        techStack: TechStack.python,
        defaultEditor: EditorType.vscode,
        tags: ['python', 'ml', 'kafka'],
        workspaceId: 'grp_infra',
        createdAt: now.subtract(const Duration(days: 15)),
        lastOpenedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<WorkspaceGroup> createMockGroups() {
    return const [
      WorkspaceGroup(id: 'grp_core', name: 'Core Products', color: Color(0xFF06B6D4)),
      WorkspaceGroup(id: 'grp_infra', name: 'Infrastructure & APIs', color: Color(0xFFA855F7)),
      WorkspaceGroup(id: 'grp_web', name: 'Frontend Applications', color: Color(0xFF10B981)),
    ];
  }

  List<Note> createMockNotes() {
    final now = DateTime.now();
    return [
      Note(
        id: 'note_release',
        title: 'v1.1.0 Desktop Release Checklist',
        content: '''## Final Launch Items
- [x] Integrate repository-first Git Radar
- [x] Responsive single-row compact toolbar
- [x] Trackpad-safe splitters via kDragDevices
- [ ] Build universal macOS DMG and Windows MSIX installers
- [ ] Publish signed release notes to GitHub''',
        projectIds: ['proj_devspace'],
        tags: ['#release', '#checklist', '#desktop'],
        pinned: true,
        checklist: const [
          ChecklistItem(id: 'c1', text: 'Integrate repository-first Git Radar', checked: true),
          ChecklistItem(id: 'c2', text: 'Responsive single-row compact toolbar', checked: true),
          ChecklistItem(id: 'c3', text: 'Trackpad-safe splitters via kDragDevices', checked: true),
          ChecklistItem(id: 'c4', text: 'Build universal macOS DMG and Windows MSIX installers', checked: false),
          ChecklistItem(id: 'c5', text: 'Publish signed release notes to GitHub', checked: false),
        ],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
      ),
      Note(
        id: 'note_notes_architecture',
        title: 'Local Storage & Data Isolation',
        content: 'DevSpace enforces zero external telemetry. All configs reside in ~/.devspace in plain JSON format with atomic sync writes.',
        projectIds: ['proj_devspace'],
        tags: ['#architecture', '#storage'],
        pinned: false,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Note(
        id: 'note_gateway_auth',
        title: 'Apollo Gateway OAuth2 Migration',
        content: 'Migrate legacy token headers to PKCE authorization code grant flow. Keep backward compatibility with service accounts.',
        projectIds: ['proj_gateway'],
        tags: ['#auth', '#security'],
        pinned: false,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  Future<void> saveScreenshot(GlobalKey key, String name, {double pixelRatio = 1.0}) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    // Legacy generator (test fonts, no real text). It used to overwrite the docs
    // on every `flutter test`; the real screenshots come from
    // test/screenshots/generate_docs_screenshots_test.dart instead.
    if (byteData != null && Platform.environment['GEN_LEGACY_SCREENSHOTS'] == '1') {
      final outDir = Directory('docs/screenshots');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('docs/screenshots/$name.png').writeAsBytesSync(byteData.buffer.asUint8List());
    }
  }

  testWidgets('Generate comprehensive docs screenshots', (tester) async {
    tester.view.physicalSize = const Size(1360, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final projects = createMockProjects();
    final groups = createMockGroups();
    final notes = createMockNotes();

    AppStore.saveProjects(projects);
    AppStore.saveWorkspaces(groups);
    AppStore.saveNotes(notes);

    final state = AppState();
    final boundaryKey = GlobalKey();

    Widget buildAppShell({Pal pal = DarkPal}) {
      return PalScope(
        pal: pal,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: pal.bg,
            body: RepaintBoundary(
              key: boundaryKey,
              child: AppShell(
                state: state,
                chrome: const WindowChrome(leftInset: 76),
              ),
            ),
          ),
        ),
      );
    }

    // 1. Capture Project Catalog (Main Window)
    await tester.pumpWidget(buildAppShell());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'project-catalog'));

    // 2. Capture Git Radar View
    state.updateUiState((s) => s.copyWith(activeTab: 'git_radar'));
    await tester.pumpWidget(buildAppShell());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'git-radar'));

    // 2b. Tap a repository card to open the interactive Git Sidepane
    final devspaceCard = find.text('DevSpace').first;
    await tester.tap(devspaceCard);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'git-sidepane'));

    // 3. Capture Notes & Checklists in Sidepane
    state.updateUiState((s) => s.copyWith(activeTab: 'projects', notesPaneVisible: true));
    await tester.pumpWidget(buildAppShell());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'notes-scratchpad'));

    // 4. Capture Light Theme Catalog
    state.updateUiState((s) => s.copyWith(notesPaneVisible: false));
    await tester.pumpWidget(buildAppShell(pal: LightPal));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'light-theme'));

    // 5. Capture Settings & Preferences Modal
    state.modal = const ModalSettings();
    await tester.pumpWidget(buildAppShell());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'preferences'));
    state.modal = null;

    // 6. Capture Command Palette
    state.paletteOpen = true;
    await tester.pumpWidget(buildAppShell());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => saveScreenshot(boundaryKey, 'command-palette'));
    state.paletteOpen = false;

    state.dispose();
  });
}
