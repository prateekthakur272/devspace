import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/ide/ide_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/core/tools/tool_detection_service.dart';
import 'package:devspace/features/shell/app_shell.dart';
import 'package:devspace/features/shell/window_chrome.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_test_');
    AppStore.homeOverride = tempDir.path;
  });

  tearDown(() {
    AppStore.homeOverride = null;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('AppStore initializes and persists settings and projects', () {
    expect(AppStore.isFirstRun(), isTrue);

    final settings = AppStore.loadSettings();
    expect(settings.gitRefreshIntervalSeconds, equals(30));

    final testProject = Project(
      id: 'p1',
      name: 'Test Project',
      path: '/tmp/test_project',
      techStack: TechStack.flutter,
      defaultEditor: EditorType.vscode,
      tags: ['flutter', 'desktop'],
      createdAt: DateTime.now(),
    );

    AppStore.saveProjects([testProject]);
    final loaded = AppStore.loadProjects();
    expect(loaded.length, equals(1));
    expect(loaded.first.name, equals('Test Project'));
    expect(loaded.first.techStack, equals(TechStack.flutter));
    expect(loaded.first.tags, contains('flutter'));
  });

  test('AppState manages projects, pins, and filtering', () async {
    final state = AppState();
    expect(state.projects, isEmpty);

    await state.addProject(
      path: tempDir.path,
      name: 'Temp Project',
      defaultEditor: EditorType.cursor,
      tags: ['temp'],
    );

    expect(state.projects.length, equals(1));
    final proj = state.projects.first;
    expect(proj.name, equals('Temp Project'));
    expect(proj.defaultEditor, equals(EditorType.cursor));
    expect(proj.pinned, isFalse);

    // Toggle pin
    state.togglePin(proj.id);
    expect(state.projects.first.pinned, isTrue);

    // Filter
    state.updateUiState((s) => s.copyWith(searchQuery: 'Temp'));
    expect(state.filteredProjects.length, equals(1));

    state.updateUiState((s) => s.copyWith(searchQuery: 'NonExistent'));
    expect(state.filteredProjects, isEmpty);

    state.dispose();
  });

  test('AppState sorts projects by options with last opened as default', () async {
    final state = AppState();
    expect(state.uiState.sortBy, equals(ProjectSortOption.lastOpened));

    await state.addProject(path: '/a/z_repo', name: 'Zebra');
    await state.addProject(path: '/a/a_repo', name: 'Apple');

    // Default: lastOpened
    expect(state.filteredProjects.length, equals(2));

    // Sort by nameAsc
    state.updateUiState((s) => s.copyWith(sortBy: ProjectSortOption.nameAsc));
    expect(state.filteredProjects.first.name, equals('Apple'));
    expect(state.filteredProjects.last.name, equals('Zebra'));

    // Sort by nameDesc
    state.updateUiState((s) => s.copyWith(sortBy: ProjectSortOption.nameDesc));
    expect(state.filteredProjects.first.name, equals('Zebra'));
    expect(state.filteredProjects.last.name, equals('Apple'));

    state.dispose();
  });

  test('TechStack detection identifies flutter pubspec.yaml', () {
    final pubspec = File('${tempDir.path}/pubspec.yaml');
    pubspec.writeAsStringSync('name: test_app\n');

    final detected = TechStack.detect(tempDir.path);
    expect(detected, equals(TechStack.flutter));
  });

  testWidgets('Tab switching and modal triggers update AppShell reactivity', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();

    // Pump AppShell wrapped in MaterialApp and PalScope
    await tester.pumpWidget(
      PalScope(
        pal: DarkPal,
        child: MaterialApp(
          home: Scaffold(
            body: AppShell(
              state: state,
              chrome: const WindowChrome(),
            ),
          ),
        ),
      ),
    );

    // Initial view is Workspace Catalog
    expect(find.text('Workspace Catalog'), findsOneWidget);
    expect(find.text('Git Radar'), findsOneWidget);

    // Click Git Radar tab
    await tester.tap(find.text('Git Radar'));
    await tester.pumpAndSettle();

    // Verify view has switched to Combined Git Radar
    expect(find.text('Combined Git Radar'), findsWidgets);
    expect(state.uiState.activeTab, equals('git_radar'));

    // Click Projects tab
    await tester.tap(find.text('Projects').first);
    await tester.pumpAndSettle();
    expect(state.uiState.activeTab, equals('projects'));

    // Verify Notes side pane is rendered
    expect(find.text('Notes & Tasks'), findsOneWidget);
    expect(state.uiState.notesPaneVisible, isTrue);

    // Toggle Notes side pane off
    state.toggleNotesPane();
    await tester.pumpAndSettle();
    expect(state.uiState.notesPaneVisible, isFalse);
    expect(find.text('Notes & Tasks'), findsNothing);

    // Toggle Notes side pane back on
    state.toggleNotesPane();
    await tester.pumpAndSettle();
    expect(state.uiState.notesPaneVisible, isTrue);
    expect(find.text('Notes & Tasks'), findsOneWidget);

    // Click Add Project button
    await tester.tap(find.text('Add Project').first);
    await tester.pumpAndSettle();
    expect(state.modal, isA<ModalAddProject>());
    expect(find.text('Add Project to DevSpace'), findsOneWidget);

    // Click Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.modal, isNull);

    state.dispose();
  });

  test('IdeService detects available editors without hanging', () async {
    final editors = await IdeService.detectAll();
    expect(editors, contains(EditorType.custom));
    expect(editors.length, greaterThanOrEqualTo(1));
  });

  test('ToolDetectionService scans developer CLI tools', () async {
    final tools = await ToolDetectionService.detectAllTools();
    // In any standard developer environment with git or flutter installed:
    expect(tools, isA<List<DetectedTool>>());
  });

  test('AppState manages custom workspace groups safely', () {
    final state = AppState();

    // Default groups exist
    expect(state.workspaces.any((w) => w.id == 'default'), isTrue);

    // Add custom group
    state.addWorkspaceGroup(name: 'Mobile Apps', color: const Color(0xFF00668B));
    expect(state.workspaces.any((w) => w.name == 'Mobile Apps'), isTrue);
    final mobileGroup = state.workspaces.firstWhere((w) => w.name == 'Mobile Apps');
    expect(state.uiState.selectedWorkspaceId, equals(mobileGroup.id));

    // Update group
    state.updateWorkspaceGroup(mobileGroup.copyWith(name: 'Mobile & Wearables'));
    expect(state.workspaces.any((w) => w.name == 'Mobile & Wearables'), isTrue);

    // Remove group (safely reassigns projects to default)
    state.removeWorkspaceGroup(mobileGroup.id);
    expect(state.workspaces.any((w) => w.id == mobileGroup.id), isFalse);
    expect(state.uiState.selectedWorkspaceId, equals('all'));

    state.dispose();
  });

  test('AppState manages notes, checklists, and project tagging', () {
    final state = AppState();

    // 1. Add Note with checklist and project tagging
    final note = Note(
      id: 'test_note_1',
      title: 'Release Checklist',
      content: 'Steps to deploy production build',
      projectIds: ['p1'],
      tags: ['#release', '#deploy'],
      links: ['https://devspace.app', '/Users/test/devspace'],
      checklist: const [
        ChecklistItem(id: 'c1', text: 'Bump version in pubspec.yaml', checked: false),
        ChecklistItem(id: 'c2', text: 'Run flutter analyze', checked: false),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state.addNote(note);
    expect(state.notes.length, equals(1));
    expect(state.notes.first.title, equals('Release Checklist'));

    // 2. Project tagging query
    final projectNotes = state.getNotesForProject('p1');
    expect(projectNotes.length, equals(1));
    expect(state.getNotesForProject('other_id'), isEmpty);

    // 3. Toggle checklist item
    state.toggleChecklistItem('test_note_1', 'c1');
    expect(state.notes.first.checklist.first.checked, isTrue);
    expect(state.notes.first.checklist.last.checked, isFalse);

    // 4. Toggle pin
    expect(state.notes.first.pinned, isFalse);
    state.togglePinNote('test_note_1');
    expect(state.notes.first.pinned, isTrue);

    // 5. Update note
    state.updateNote(state.notes.first.copyWith(title: 'Updated Release'));
    expect(state.notes.first.title, equals('Updated Release'));

    // 6. Persistence check via AppStore
    final reloaded = AppStore.loadNotes();
    expect(reloaded.any((n) => n.id == 'test_note_1'), isTrue);

    // 7. Delete note
    state.deleteNote('test_note_1');
    expect(state.notes, isEmpty);
    expect(AppStore.loadNotes(), isEmpty);

    state.dispose();
  });

  test('Note editor opens in side pane without opening modal dialog', () {
    final state = AppState();

    // 1. Initial state
    expect(state.paneEditingNote, isNull);
    expect(state.paneCreatingNote, isFalse);

    // 2. Open new note in pane
    state.openNewNoteInPane(initialProjectId: 'p1');
    expect(state.paneCreatingNote, isTrue);
    expect(state.paneEditingNote, isNull);
    expect(state.paneInitialProjectId, equals('p1'));
    expect(state.uiState.notesPaneVisible, isTrue);
    expect(state.modal, isNull); // Ensures no blocking dialog

    // 3. Close pane editor
    state.closePaneNoteEditor();
    expect(state.paneCreatingNote, isFalse);

    // 4. Open existing note in pane
    final note = Note(
      id: 'n_edit',
      title: 'Editing in Pane',
      content: 'Seamless side pane editor',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state.addNote(note);
    state.openNoteInPane(note);
    expect(state.paneEditingNote?.id, equals('n_edit'));
    expect(state.paneCreatingNote, isFalse);
    expect(state.modal, isNull); // In-pane, not modal

    // 5. Deleting open note auto-closes editor
    state.deleteNote('n_edit');
    expect(state.paneEditingNote, isNull);

    state.dispose();
  });
}
