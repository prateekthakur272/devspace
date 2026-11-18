import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/features/shell/status_bar.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final opened = <String>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeUrlLauncher fakeLauncher;
  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('developer_dialog_test_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);

    fakeLauncher = _FakeUrlLauncher();
    originalLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalLauncher;
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('StatusBar has GitHub and Report Issue buttons and supports right-click menu', (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: StatusBar(state: state),
          ),
        ),
      ),
    );

    // Old repository button should not exist
    expect(find.byTooltip('Repository'), findsNothing);

    // GitHub and Report Issue buttons exist
    final githubBtn = find.byTooltip('GitHub');
    final reportBtn = find.byKey(const ValueKey('report-issue'));
    expect(githubBtn, findsOneWidget);
    expect(reportBtn, findsOneWidget);

    // Report issue button sits right after GitHub button
    final ghRect = tester.getRect(githubBtn);
    final reportRect = tester.getRect(reportBtn);
    expect(reportRect.left, greaterThan(ghRect.left));
    expect(reportRect.left - ghRect.right, lessThanOrEqualTo(10));

    // Secondary click (right-click) shows popup menu
    final gesture = await tester.startGesture(
      tester.getCenter(githubBtn),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Developer & Project…'), findsOneWidget);
    expect(find.text('DevSpace Repository'), findsOneWidget);
    expect(find.text('Star on GitHub'), findsOneWidget);
    expect(find.text('Releases & Changelog'), findsOneWidget);

    // Dismiss menu by clicking item
    await tester.tap(find.text('Developer & Project…'));
    await tester.pumpAndSettle();
    expect(state.modal, isA<ModalDeveloper>());

    // Reset modal
    state.modal = null;
    await tester.pump();

    // Normal left click on GitHub button opens Developer modal directly
    await tester.tap(githubBtn);
    await tester.pump();
    expect(state.modal, isA<ModalDeveloper>());

    // Tapping Report Issue opens URL with environment template
    await tester.tap(reportBtn);
    await tester.pump();
    expect(fakeLauncher.opened, hasLength(1));
    final issueUri = Uri.parse(fakeLauncher.opened.single);
    expect('${issueUri.scheme}://${issueUri.host}${issueUri.path}', AppConfig.ISSUES_URL);
    expect(issueUri.queryParameters['body'], contains('**What happened?**'));
    expect(issueUri.queryParameters['body'], contains(AppConfig.NAME));

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('StatusBar does not overflow across narrow and wide widths', (tester) async {
    final state = AppState();

    for (final width in [700.0, 800.0, 960.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalScope(
              pal: DarkPal,
              child: StatusBar(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflowed at width $width');
    }

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('DeveloperDialog renders vendor, badges, interactive tiles and copy actions', (tester) async {
    final state = AppState();
    state.modal = const ModalDeveloper();

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        copiedText = (methodCall.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: Builder(
              builder: (ctx) => Stack(
                children: [
                  const SizedBox.expand(),
                  buildActiveModal(ctx, state),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Title and Header
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text(AppConfig.VENDOR), findsOneWidget);
    expect(find.text('Developer of ${AppConfig.NAME}'), findsOneWidget);
    expect(find.text('@prateekthakur272'), findsOneWidget);

    // Badges
    expect(find.text('Public Repo'), findsOneWidget);
    expect(find.text('Flutter Desktop'), findsOneWidget);
    expect(find.text('Open Source'), findsOneWidget);

    // Quick Action Tiles
    expect(find.text('Source Code'), findsOneWidget);
    expect(find.text('Star on GitHub'), findsOneWidget);
    expect(find.text('Releases & Notes'), findsOneWidget);
    expect(find.text('Report an Issue'), findsOneWidget);

    // Tap quick action tile
    await tester.tap(find.text('Source Code'));
    await tester.pump();
    expect(fakeLauncher.opened, contains(AppConfig.REPOSITORY));

    // Profile and repository URL sections removed; only Explore More Apps card remains
    expect(find.text('PROFILE'), findsNothing);
    expect(find.text('PROJECT REPOSITORY'), findsNothing);
    expect(find.text('EXPLORE MORE APPS'), findsOneWidget);

    // Verify URLs
    expect(find.text(AppConfig.MORE_APPS_URL), findsOneWidget);

    // Verify GitHub mark widget
    expect(find.byType(GitHubIcon), findsWidgets);

    // Test Copy button (on the remaining link card)
    final copyButtons = find.text('Copy');
    expect(copyButtons, findsOneWidget);

    await tester.tap(copyButtons.first);
    await tester.pump();

    expect(find.text('Copied'), findsOneWidget);
    expect(copiedText, AppConfig.MORE_APPS_URL);

    // Test Open button (on the remaining link card)
    final openButtons = find.text('Open');
    expect(openButtons, findsOneWidget);

    await tester.tap(openButtons.first);
    await tester.pump();
    expect(fakeLauncher.opened, contains(AppConfig.MORE_APPS_URL));

    // Test Close button dismisses modal
    await tester.tap(find.text('Close'));
    await tester.pump();

    expect(state.modal, isNull);

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('StatusBar right-hand buttons are pinned to the end of the bar', (tester) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: SizedBox(
              width: 1200,
              child: StatusBar(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statusBarRect = tester.getRect(find.byType(StatusBar));
    final cmdRect = tester.getRect(find.text('commands'));

    // Command palette trigger should be pinned within 30px of the far right end
    expect(statusBarRect.right - cmdRect.right, lessThanOrEqualTo(30.0));

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Settings dialog displays "None" option for git radar polling and disables polling', (tester) async {
    final state = AppState();
    state.modal = const ModalSettings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: Builder(
              builder: (ctx) => Stack(
                children: [
                  const SizedBox.expand(),
                  buildActiveModal(ctx, state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Git & Radar tab
    await tester.tap(find.text('Git & Radar'));
    await tester.pumpAndSettle();

    // Find the "None" interval option
    final noneOption = find.text('None');
    expect(noneOption, findsOneWidget);

    // Tap "None" option
    await tester.tap(noneOption);
    await tester.pumpAndSettle();

    expect(state.settings.gitRefreshIntervalSeconds, equals(0));

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
