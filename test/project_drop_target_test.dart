import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/project_drop_target.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('project_drop_target_test_');
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

  test('handleDroppedFiles imports a single directory and detects stack', () async {
    final state = AppState();

    // Create a mock flutter project folder
    final flutterProjDir = Directory('${tempDir.path}/my_flutter_app')..createSync();
    File('${flutterProjDir.path}/pubspec.yaml').writeAsStringSync('name: my_flutter_app\n');

    final added = await ProjectDropTarget.handleDroppedFiles(
      state,
      [XFile(flutterProjDir.path)],
      workspaceId: 'mobile',
    );

    expect(added, equals(1));
    expect(state.projects.length, equals(1));
    expect(state.projects.first.name, equals('my_flutter_app'));
    expect(state.projects.first.path, equals(flutterProjDir.path));
    expect(state.projects.first.techStack, equals(TechStack.flutter));
    expect(state.projects.first.workspaceId, equals('mobile'));
    expect(state.toast, contains('Added project "my_flutter_app"'));

    state.dispose();
  });

  test('handleDroppedFiles resolves parent directory when a project file is dropped', () async {
    final state = AppState();

    final rustProjDir = Directory('${tempDir.path}/rust_service')..createSync();
    final cargoFile = File('${rustProjDir.path}/Cargo.toml')..writeAsStringSync('[package]\nname = "rust_service"\n');

    final added = await ProjectDropTarget.handleDroppedFiles(
      state,
      [XFile(cargoFile.path)],
    );

    expect(added, equals(1));
    expect(state.projects.length, equals(1));
    expect(state.projects.first.name, equals('rust_service'));
    expect(state.projects.first.path, equals(rustProjDir.path));
    expect(state.projects.first.techStack, equals(TechStack.rust));

    state.dispose();
  });

  test('handleDroppedFiles warns when project is already added', () async {
    final state = AppState();

    final existingDir = Directory('${tempDir.path}/existing_project')..createSync();
    await state.addProject(path: existingDir.path, name: 'Existing Project');
    expect(state.projects.length, equals(1));

    final added = await ProjectDropTarget.handleDroppedFiles(
      state,
      [XFile(existingDir.path)],
    );

    expect(added, equals(0));
    expect(state.projects.length, equals(1));
    expect(state.toast, contains('already in DevSpace'));

    state.dispose();
  });

  test('handleDroppedFiles imports multiple folders simultaneously', () async {
    final state = AppState();

    final dir1 = Directory('${tempDir.path}/app_alpha')..createSync();
    final dir2 = Directory('${tempDir.path}/app_beta')..createSync();
    final dir3 = Directory('${tempDir.path}/app_gamma')..createSync();

    final added = await ProjectDropTarget.handleDroppedFiles(
      state,
      [
        XFile(dir1.path),
        XFile(dir2.path),
        XFile(dir3.path),
      ],
      workspaceId: 'infra',
    );

    expect(added, equals(3));
    expect(state.projects.length, equals(3));
    expect(state.toast, contains('Added 3 projects to DevSpace'));

    state.dispose();
  });

  testWidgets('ProjectDropTarget builds child and reacts to drag state callback', (tester) async {
    final state = AppState();
    bool isDragging = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: ProjectDropTarget(
              state: state,
              onDragStateChanged: (dragging) => isDragging = dragging,
              child: const Text('Drop Zone Content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Drop Zone Content'), findsOneWidget);
    expect(find.text('Drop to Add Project'), findsNothing);
    expect(isDragging, isFalse);

    state.dispose();
  });
}
