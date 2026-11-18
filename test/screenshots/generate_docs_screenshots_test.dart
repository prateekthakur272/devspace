// Regenerates the screenshots in docs/screenshots from the real UI.
//
//   GEN_SCREENSHOTS=1 flutter test test/screenshots/generate_docs_screenshots_test.dart
//
// The app is rendered with real fonts and a seeded, fictional demo workspace,
// so no personal paths or notes end up in the docs. Skipped unless
// GEN_SCREENSHOTS is set, so normal `flutter test` runs never touch docs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/core/tools/tool_detection_service.dart';
import 'package:devspace/features/shell/app_shell.dart';
import 'package:devspace/features/shell/window_chrome.dart';
import 'package:devspace/theme/theme.dart';

const _sansFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
const _monoFamily = 'SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final icons = FontLoader('MaterialIcons')..addFont(bytes('$fonts/MaterialIcons-Regular.otf'));
  await icons.load();

  final sans = FontLoader(_sansFamily);
  const sf = '/System/Library/Fonts/SFNS.ttf';
  if (File(sf).existsSync()) {
    sans.addFont(bytes(sf));
    sans.addFont(bytes('/System/Library/Fonts/SFNSItalic.ttf'));
  } else {
    for (final f in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold', 'Roboto-Italic']) {
      sans.addFont(bytes('$fonts/$f.ttf'));
    }
  }
  await sans.load();

  const monoCandidates = ['/System/Library/Fonts/SFNSMono.ttf', '/System/Library/Fonts/Menlo.ttc'];
  final mono = FontLoader(_monoFamily);
  var haveMono = false;
  for (final m in monoCandidates) {
    if (File(m).existsSync()) {
      mono.addFont(bytes(m));
      haveMono = true;
      break;
    }
  }
  if (!haveMono) mono.addFont(bytes('$fonts/Roboto-Regular.ttf'));
  await mono.load();
}

DateTime _ago(Duration d) => DateTime.now().subtract(d);

GitRepoStatus _git({
  String branch = 'main',
  int mod = 0,
  int staged = 0,
  int untracked = 0,
  int ahead = 0,
  int behind = 0,
  bool stash = false,
  String? msg,
  String? hash,
  Duration? when,
  String? tag,
}) =>
    GitRepoStatus(
      isGitRepo: true,
      branch: branch,
      modifiedCount: mod,
      stagedCount: staged,
      untrackedCount: untracked,
      aheadCount: ahead,
      behindCount: behind,
      hasStash: stash,
      lastChecked: DateTime.now(),
      lastCommitMessage: msg,
      lastCommitHash: hash,
      lastCommitDate: when == null ? null : _ago(when),
      lastCommitAuthor: 'Alex Rivera',
      lastTag: tag,
      upstream: 'origin/$branch',
      remoteUrl: 'git@github.com:acme/demo.git',
    );

Future<void> _shot(WidgetTester t, GlobalKey key, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  await t.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('docs/screenshots/$name.png');
    await out.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['GEN_SCREENSHOTS'] == '1';

  testWidgets('generate docs screenshots', skip: !enabled, (t) async {
    await t.runAsync(_loadFonts);
    final tmp = Directory.systemTemp.createTempSync('devspace_shots_');
    AppStore.homeOverride = tmp.path;
    addTearDown(() {
      AppStore.homeOverride = null;
      tmp.deleteSync(recursive: true);
    });
    AppStore.setFlag('onboarding_completed', true);

    // ---- Demo workspace (fictional) -------------------------------------
    const ws = [
      WorkspaceGroup(id: 'work', name: 'Client Work', color: Color(0xFF06B6D4)),
      WorkspaceGroup(id: 'oss', name: 'Open Source', color: Color(0xFFA855F7)),
      WorkspaceGroup(id: 'play', name: 'Side Projects', color: Color(0xFF10B981)),
    ];
    final now = DateTime.now();
    Project pr(String id, String name, TechStack s, String w,
            {bool pinned = false, Duration? opened, EditorType ed = EditorType.vscode, List<String> tags = const []}) =>
        Project(
          id: id,
          name: name,
          path: '/Users/dev/code/${name.toLowerCase().replaceAll(' ', '-')}',
          techStack: s,
          defaultEditor: ed,
          workspaceId: w,
          pinned: pinned,
          tags: tags,
          lastOpenedAt: opened == null ? null : now.subtract(opened),
          createdAt: now.subtract(const Duration(days: 90)),
        );
    final projects = [
      pr('p1', 'Orbit Mobile', TechStack.flutter, 'work', pinned: true, opened: const Duration(minutes: 12), tags: ['mobile']),
      pr('p2', 'Atlas Dashboard', TechStack.react, 'work', pinned: true, opened: const Duration(hours: 2), tags: ['web']),
      pr('p3', 'Pulse API', TechStack.go, 'work', opened: const Duration(hours: 5), ed: EditorType.vscode),
      pr('p4', 'Forge CLI', TechStack.rust, 'oss', opened: const Duration(days: 1)),
      pr('p5', 'Nimbus SDK', TechStack.kotlin, 'oss', opened: const Duration(days: 2), ed: EditorType.androidStudio),
      pr('p6', 'Lumen Notes', TechStack.swift, 'play', opened: const Duration(days: 3), ed: EditorType.xcode),
      pr('p7', 'Quill Server', TechStack.node, 'play', opened: const Duration(days: 5)),
      pr('p8', 'Vector Lab', TechStack.python, 'play', opened: const Duration(days: 9)),
    ];
    AppStore.saveWorkspaces(ws);
    AppStore.saveProjects(projects);

    Note note(String id, String title, String content, {List<ChecklistItem> list = const [], List<String> proj = const [], List<String> tags = const [], bool pin = false, Color? color, Duration ago = const Duration(hours: 1)}) =>
        Note(
          id: id,
          title: title,
          content: content,
          checklist: list,
          projectIds: proj,
          tags: tags,
          pinned: pin,
          color: color,
          createdAt: now.subtract(ago),
          updatedAt: now.subtract(ago),
        );
    ChecklistItem ci(String i, String t, [bool c = false]) => ChecklistItem(id: i, text: t, checked: c);
    AppStore.saveNotes([
      note('n1', 'Release checklist',
          '- [x] Bump version to 2.4.0\n- [x] Update changelog\n- [ ] Tag release and push\n- [ ] Publish to stores\n- [ ] Announce in #general',
          list: [ci('a', 'Bump version to 2.4.0', true), ci('b', 'Update changelog', true), ci('c', 'Tag release and push'), ci('d', 'Publish to stores'), ci('e', 'Announce in #general')],
          proj: ['p1'], tags: ['#release'], pin: true, color: const Color(0xFF8B5CF6), ago: const Duration(minutes: 20)),
      note('n2', 'Auth flow ideas',
          'Move token refresh into an interceptor so screens never see expired sessions. Keep the refresh lock per-account to avoid duplicate calls.\n\nSee https://oauth.net/2/pkce for the PKCE details.',
          proj: ['p3'], tags: ['#backend', '#auth'], color: const Color(0xFF3B82F6), ago: const Duration(hours: 3)),
      note('n3', 'Deploy runbook',
          '```\nkubectl rollout status deploy/api\n```\nRoll back with the previous image tag if error rate > 2%.',
          tags: ['#ops'], color: const Color(0xFF14B8A6), ago: const Duration(days: 1)),
      note('n4', 'Standup',
          '- [ ] Review Atlas PR #214\n- [ ] Fix flaky pagination test\n- [x] Reply to design feedback',
          list: [ci('f', 'Review Atlas PR #214'), ci('g', 'Fix flaky pagination test'), ci('h', 'Reply to design feedback', true)],
          proj: ['p2'], tags: ['#daily'], color: const Color(0xFFF59E0B), ago: const Duration(days: 2)),
    ]);

    final state = AppState();
    addTearDown(state.dispose);
    state.setGitStatusForTesting('p1', _git(branch: 'feature/onboarding', mod: 3, staged: 1, ahead: 2, msg: 'Add onboarding carousel', hash: '62ed5d1', when: const Duration(hours: 4), tag: 'v2.3.0'));
    state.setGitStatusForTesting('p2', _git(msg: 'Fix table pagination', hash: '3c95a57', when: const Duration(hours: 26), tag: 'v1.8.2'));
    state.setGitStatusForTesting('p3', _git(branch: 'develop', behind: 4, msg: 'Refactor rate limiter', hash: '2b95755', when: const Duration(days: 1), tag: 'v0.9.0'));
    state.setGitStatusForTesting('p4', _git(mod: 2, untracked: 1, ahead: 1, msg: 'Support shell completions', hash: '5daa602', when: const Duration(days: 2), tag: 'v1.0.0'));
    state.setGitStatusForTesting('p5', _git(msg: 'Release 3.1.0', hash: '108b855', when: const Duration(days: 3), tag: 'v3.1.0'));
    state.setGitStatusForTesting('p6', _git(branch: 'fix/sync', mod: 5, untracked: 2, stash: true, msg: 'WIP sync engine', hash: 'ca4d3e7', when: const Duration(days: 4)));
    state.setGitStatusForTesting('p7', _git(msg: 'Add health endpoint', hash: '9ad01f2', when: const Duration(days: 6), tag: 'v0.4.1'));
    state.setGitStatusForTesting('p8', GitRepoStatus(lastChecked: DateTime.now()));

    state.setToolsForTesting(
      editors: [EditorType.vscode, EditorType.androidStudio, EditorType.xcode, EditorType.intellij],
      tools: [
        for (final n in ['git', 'node', 'flutter', 'docker', 'python', 'go', 'cargo'])
          DetectedTool(id: n, name: n, category: 'CLI', version: '1.0', path: '/usr/local/bin/$n'),
      ],
    );

    final key = GlobalKey();
    t.view.physicalSize = const Size(2720, 1720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    var dark = true;
    Future<void> pumpApp() async {
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DevSpaceTheme.makeTheme(false),
          darkTheme: DevSpaceTheme.makeTheme(true),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: PalScope(
            pal: DevSpaceTheme.palFor(dark),
            child: Scaffold(
              body: Stack(
                children: [
                  AppShell(
                    state: state,
                    chrome: WindowChrome.desktop(
                      isMac: true,
                      maximized: false,
                      onMinimize: () {},
                      onToggleMaximize: () {},
                      onClose: () {},
                      onDragStart: () {},
                    ),
                  ),
                  // Native macOS traffic lights are drawn by the OS, so paint
                  // them here to match a real window.
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: 12.0 + i * 20,
                      top: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)][i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 300));
    }

    await pumpApp();
    // Let asset/icon images finish decoding before the first capture.
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await pumpApp(); // rebuild so cached icon images are picked up
    await _shot(t, key, 'project-catalog');

    state.updateUiState((s) => s.copyWith(activeTab: 'git_radar'));
    await t.pump();
    await _shot(t, key, 'git-radar');
    state.updateUiState((s) => s.copyWith(activeTab: 'projects'));

    state.modal = ModalGitDetails(projects[0], state.gitStatuses['p1']!);
    await t.pump();
    await _shot(t, key, 'git-sidepane');
    state.modal = null;

    state.paletteOpen = true;
    await t.pump();
    await _shot(t, key, 'command-palette');
    state.paletteOpen = false;

    state.modal = const ModalSettings();
    await t.pump();
    await _shot(t, key, 'preferences');
    state.modal = null;

    // Notes with the editor open
    state.openNoteInPane(state.notes.first);
    await t.pump(const Duration(milliseconds: 300));
    await _shot(t, key, 'notes-scratchpad');
    state.closePaneNoteEditor();

    dark = false;
    await pumpApp();
    await _shot(t, key, 'light-theme');

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 6));
  });
}
