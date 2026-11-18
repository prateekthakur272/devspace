import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/catalog/project_card.dart';
import 'package:devspace/features/notes/note_card.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('card_overflow_test_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);
  });

  tearDown(() {
    AppStore.homeOverride = null;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('NoteCard does not overflow with long project name in narrow container', (tester) async {
    final project = Project(
      id: 'proj-1',
      name: 'github-marketplace',
      path: '/tmp/github-marketplace',
      techStack: TechStack.general,
      defaultEditor: EditorType.vscode,
      tags: [],
      createdAt: DateTime.now(),
    );
    AppStore.saveProjects([project]);

    final state = AppState();

    final note = Note(
      id: 'n1',
      title: 'Agenda',
      content: 'Marketplace\n@github-marketplace',
      projectIds: ['proj-1'],
      tags: ['tag1', 'tag2'],
      checklist: [],
      links: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Test across very narrow widths down to 200px
    for (final width in [200.0, 240.0, 280.0, 320.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalScope(
              pal: DarkPal,
              child: SizedBox(
                width: width,
                child: NoteCard(
                  note: note,
                  state: state,
                  formatTime: (d) => '2h ago',
                  onCopy: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflowed at width $width');

      final moreFinder = find.byTooltip('More');
      final moreBox = tester.getRect(moreFinder);
      expect(moreBox.right, greaterThanOrEqualTo(width - 10), reason: 'More button should be at the right end');
    }

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ProjectCard does not overflow with long tag, hash, and commit message', (tester) async {
    final projDir = Directory('${tempDir.path}/visionwaves-deployment')..createSync();
    Process.runSync('git', ['init'], workingDirectory: projDir.path);

    final project = Project(
      id: 'proj-2',
      name: 'visionwaves-deployment',
      path: projDir.path,
      techStack: TechStack.general,
      defaultEditor: EditorType.vscode,
      tags: ['deployment', 'infra'],
      createdAt: DateTime.now(),
    );
    AppStore.saveProjects([project]);

    final state = AppState();

    // Manually set git status with long tag, 10-char hash, commit message, author
    state.setGitStatusForTesting(
      project.id,
      GitRepoStatus(
        isGitRepo: true,
        branch: 'demo',
        upstream: 'origin/demo',
        stagedCount: 0,
        modifiedCount: 1,
        untrackedCount: 0,
        hasStash: true,
        aheadCount: 0,
        behindCount: 0,
        lastChecked: DateTime.now(),
        lastCommitHash: '0c78dadaff',
        lastTag: 'MODULITH_CHART_CHANGES_PLATFORM',
        lastCommitMessage: 'Update deployment configuration and Helm charts',
        lastCommitAuthor: 'developer',
        lastCommitDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );

    // Test across typical grid card widths (minimum card width in catalog is 316px)
    for (final width in [320.0, 360.0, 420.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalScope(
              pal: DarkPal,
              child: SizedBox(
                width: width,
                height: 220,
                child: ProjectCard(
                  project: project,
                  state: state,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'Overflowed at width $width');
    }

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
