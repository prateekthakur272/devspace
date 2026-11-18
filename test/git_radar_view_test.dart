import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/git_radar/git_radar_view.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('git_radar_view_test_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);
    GitService.disableExecutionForTesting = true;
  });

  tearDown(() {
    GitService.disableExecutionForTesting = false;
    AppStore.homeOverride = null;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Git Radar renders repository-first card layout and groups linked projects', (tester) async {
    final repoProj1 = Project(
      id: 'p1',
      name: 'Alpha Mobile',
      path: '/dev/alpha-repo/apps/mobile',
      techStack: TechStack.flutter,
      createdAt: DateTime.now(),
    );

    final repoProj2 = Project(
      id: 'p2',
      name: 'Alpha Backend',
      path: '/dev/alpha-repo/services/backend',
      techStack: TechStack.node,
      createdAt: DateTime.now(),
    );

    final nonRepoProj = Project(
      id: 'p3',
      name: 'Beta Docs',
      path: '/dev/beta-docs',
      techStack: TechStack.general,
      createdAt: DateTime.now(),
    );

    AppStore.saveProjects([repoProj1, repoProj2, nonRepoProj]);

    final state = AppState();
    addTearDown(state.dispose);

    final sharedRepoStatus = GitRepoStatus(
      isGitRepo: true,
      repoRoot: '/dev/alpha-repo',
      branch: 'main',
      modifiedCount: 2,
      stagedCount: 1,
      aheadCount: 3,
      behindCount: 0,
      lastCommitMessage: 'feat: add repository first view',
      lastCommitDate: DateTime.now().subtract(const Duration(hours: 2)),
      lastChecked: DateTime.now(),
    );

    state.setGitStatusForTesting(repoProj1.id, sharedRepoStatus);
    state.setGitStatusForTesting(repoProj2.id, sharedRepoStatus);
    state.setGitStatusForTesting(nonRepoProj.id, GitRepoStatus.empty());

    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: GitRadarView(state: state),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify Single-Row Header Elements (clean toolbar without redundant title row)
    expect(find.byType(TextField), findsOneWidget); // Search field in header
    expect(find.text('Needs Attention First'), findsOneWidget); // Sort button
    expect(find.widgetWithText(Btn, 'Fetch All'), findsOneWidget); // Batch action button
    expect(find.byTooltip('More Git Radar actions'), findsOneWidget); // More menu

    // Repository name (from repo root '/dev/alpha-repo')
    expect(find.text('alpha-repo'), findsOneWidget);
    expect(find.text('/dev/alpha-repo'), findsOneWidget);

    // Linked project chips inside the single repository card
    expect(find.text('Alpha Mobile'), findsOneWidget);
    expect(find.text('Alpha Backend'), findsOneWidget);

    // Non-git project should NOT have a repository card
    expect(find.text('Beta Docs'), findsNothing);

    // Status & Branch metrics
    expect(find.text('main'), findsOneWidget);
    expect(find.text('↑3'), findsOneWidget);
    expect(find.text('~2'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('feat: add repository first view'), findsOneWidget);

    // Verify refresh and expand buttons are not on the repo card
    expect(find.byTooltip('Fetch remote status'), findsNothing);
    expect(find.byTooltip('View commits and modified files'), findsNothing);
    expect(find.byTooltip('Hide repository details'), findsNothing);

    // Verify Open, Commit, and Terminal buttons are removed from the repo card
    expect(find.widgetWithText(Btn, 'Commit'), findsNothing);
    expect(find.widgetWithText(Btn, 'Open'), findsNothing);
    expect(find.byTooltip('Open Integrated Terminal'), findsNothing);
    expect(find.byTooltip('Open System Terminal'), findsNothing);

    // Clicking change chip opens Git Details Modal
    await tester.tap(find.text('~2'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.modal, isA<ModalGitDetails>());

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Clicking repository opens detailed sidepane with useful tools and options', (tester) async {
    final repoProj = Project(
      id: 'p1',
      name: 'Alpha Mobile',
      path: '/dev/alpha-repo/apps/mobile',
      techStack: TechStack.flutter,
      createdAt: DateTime.now(),
    );

    AppStore.saveProjects([repoProj]);

    final state = AppState();
    addTearDown(state.dispose);

    state.setGitStatusForTesting(
      repoProj.id,
      GitRepoStatus(
        isGitRepo: true,
        repoRoot: '/dev/alpha-repo',
        branch: 'main',
        modifiedCount: 1,
        stagedCount: 0,
        aheadCount: 0,
        behindCount: 0,
        lastCommitMessage: 'initial commit',
        lastCommitDate: DateTime.now(),
        lastChecked: DateTime.now(),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: GitRadarView(state: state),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Initially sidepane is not open
    expect(find.byTooltip('Close sidepane (Esc)'), findsNothing);
    expect(find.text('Git Tools'), findsNothing);

    // Click the repository card (using the repo title)
    await tester.tap(find.text('alpha-repo'));
    await tester.pump(const Duration(milliseconds: 100));

    // Sidepane is now open!
    expect(find.byTooltip('Close sidepane (Esc)'), findsOneWidget);
    expect(find.text('Git Tools'), findsOneWidget);
    expect(find.text('Quick Commit'), findsOneWidget);

    // Clicking the repository card again should NOT close the sidepane
    await tester.tap(find.text('alpha-repo').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Close sidepane (Esc)'), findsOneWidget);
    expect(find.text('Git Tools'), findsOneWidget);

    // Switch to Git Tools tab
    await tester.tap(find.text('Git Tools'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Fetch & Prune'), findsOneWidget);
    expect(find.text('Clean Untracked Files'), findsOneWidget);
    expect(find.text('Terminal at Repo Root'), findsOneWidget);

    // Switch to Projects tab
    await tester.tap(find.text('Projects (1)'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Linked Workspace Projects (1)'), findsOneWidget);

    // Close sidepane using close button
    await tester.tap(find.byTooltip('Close sidepane (Esc)'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Close sidepane (Esc)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Git Radar card does not overflow horizontally even with many chips and narrow width', (tester) async {
    final repoProj = Project(
      id: 'p1',
      name: 'Very Long Project Name That Could Wrap',
      path: '/dev/very-long-repository-path-for-testing/subfolder',
      techStack: TechStack.flutter,
      createdAt: DateTime.now(),
    );

    AppStore.saveProjects([repoProj]);

    final state = AppState();
    addTearDown(state.dispose);

    state.setGitStatusForTesting(
      repoProj.id,
      GitRepoStatus(
        isGitRepo: true,
        repoRoot: '/dev/very-long-repository-path-for-testing',
        branch: 'feature/extremely-long-branch-name-overflow-test',
        modifiedCount: 15,
        stagedCount: 12,
        untrackedCount: 8,
        aheadCount: 5,
        behindCount: 3,
        hasStash: true,
        remoteUrl: 'https://github.com/organization/very-long-repository-name',
        lastCommitMessage: 'feat: add support for enterprise integration with nested repositories',
        lastCommitDate: DateTime.now(),
        lastChecked: DateTime.now(),
      ),
    );

    // Narrow width constraint (e.g. 700px width)
    await tester.binding.setSurfaceSize(const Size(700, 600));

    await tester.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: GitRadarView(state: state),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Open sidepane to make the card even narrower (split screen)
    await tester.tap(find.text('very-long-repository-path-for-testing'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify sidepane is open and no RenderFlex overflowed!
    expect(find.byTooltip('Close sidepane (Esc)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('More menu has Open option with submenu for multi-project repos and direct action for single-project repos', (tester) async {
    final multiRepoProj1 = Project(
      id: 'p1',
      name: 'Alpha App',
      path: '/dev/alpha-repo/apps/mobile',
      techStack: TechStack.flutter,
      createdAt: DateTime.now(),
    );

    final multiRepoProj2 = Project(
      id: 'p2',
      name: 'Alpha Service',
      path: '/dev/alpha-repo/services/api',
      techStack: TechStack.node,
      createdAt: DateTime.now(),
    );

    final singleRepoProj = Project(
      id: 'p3',
      name: 'Single App',
      path: '/dev/beta-repo/web',
      techStack: TechStack.react,
      createdAt: DateTime.now(),
    );

    AppStore.saveProjects([multiRepoProj1, multiRepoProj2, singleRepoProj]);

    final state = AppState();
    addTearDown(state.dispose);

    state.setGitStatusForTesting(
      multiRepoProj1.id,
      GitRepoStatus(
        isGitRepo: true,
        repoRoot: '/dev/alpha-repo',
        branch: 'main',
        lastCommitMessage: 'multi proj commit',
        lastCommitDate: DateTime.now(),
        lastChecked: DateTime.now(),
      ),
    );
    state.setGitStatusForTesting(
      multiRepoProj2.id,
      GitRepoStatus(
        isGitRepo: true,
        repoRoot: '/dev/alpha-repo',
        branch: 'main',
        lastCommitMessage: 'multi proj commit',
        lastCommitDate: DateTime.now(),
        lastChecked: DateTime.now(),
      ),
    );
    state.setGitStatusForTesting(
      singleRepoProj.id,
      GitRepoStatus(
        isGitRepo: true,
        repoRoot: '/dev/beta-repo',
        branch: 'main',
        lastCommitMessage: 'single proj commit',
        lastCommitDate: DateTime.now(),
        lastChecked: DateTime.now(),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: GitRadarView(state: state),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Find More actions buttons (one for alpha-repo, one for beta-repo)
    final moreButtons = find.byTooltip('More actions');
    expect(moreButtons, findsNWidgets(2));

    // Tap first More actions button (alpha-repo has 2 projects)
    await tester.tap(moreButtons.first);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify 'Open' menu item is present
    expect(find.text('Open'), findsOneWidget);

    // Hover or Tap on 'Open' to trigger submenu
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify submenu options for the multiple projects in alpha-repo
    expect(find.text('Alpha App (Flutter)'), findsOneWidget);
    expect(find.text('Alpha Service (Node.js)'), findsOneWidget);
    expect(find.text('Repo Root (alpha-repo)'), findsOneWidget);

    // Dismiss menu
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 200));

    // Tap second More actions button (beta-repo has 1 project)
    await tester.tap(moreButtons.last);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify 'Open' menu item is present
    expect(find.text('Open'), findsOneWidget);

    // For single-project repo, clicking Open does not show submenu projects
    expect(find.text('Repo Root (beta-repo)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
