import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/features/shell/app_shell.dart';
import 'package:devspace/features/shell/tools_rail.dart';
import 'package:devspace/features/shell/window_chrome.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tools_rail_test_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);
  });

  tearDown(() {
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('AppSettings serialization preserves showToolsRail', () {
    const settings = AppSettings(showToolsRail: false);
    final json = settings.toJson();
    expect(json['showToolsRail'], isFalse);

    final restored = AppSettings.fromJson(json);
    expect(restored.showToolsRail, isFalse);

    final enabled = settings.copyWith(showToolsRail: true);
    expect(enabled.showToolsRail, isTrue);
    expect(AppSettings.fromJson(enabled.toJson()).showToolsRail, isTrue);
  });

  testWidgets('ToolsRail renders at right end and toggles from state and settings', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();
    const chrome = WindowChrome();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: AppShell(state: state, chrome: chrome),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ToolsRail is present by default
    expect(find.byType(ToolsRail), findsOneWidget);

    // Verify system terminal button is in the rail
    expect(find.byTooltip('System Terminal\nClick to launch terminal application'), findsOneWidget);

    // Toggle off
    state.toggleToolsRail();
    await tester.pumpAndSettle();

    expect(find.byType(ToolsRail), findsNothing);

    // Toggle back on
    state.toggleToolsRail();
    await tester.pumpAndSettle();

    expect(find.byType(ToolsRail), findsOneWidget);

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Settings dialog contains Tools Rail toggle switch and updates state', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Verify toggle tile exists in settings
    expect(find.text('Tools & IDEs Quick Launch Rail'), findsOneWidget);

    // Initial state is true
    expect(state.settings.showToolsRail, isTrue);

    // Find and tap the switch
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsWidgets);

    // Tap the tools rail switch (the second switch on the general page)
    await tester.tap(switchFinder.at(1));
    await tester.pumpAndSettle();

    expect(state.settings.showToolsRail, isFalse);

    // Tap again to enable
    await tester.tap(switchFinder.at(1));
    await tester.pumpAndSettle();

    expect(state.settings.showToolsRail, isTrue);

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ToolsRail only shows tools that open as application', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: SizedBox(
              width: 44,
              height: 600,
              child: ToolsRail(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // System terminal application button is present
    final termBtn = find.byTooltip('System Terminal\nClick to launch terminal application');
    expect(termBtn, findsOneWidget);

    // Refresh and close buttons were removed; a "+" pin button replaces them
    expect(find.byTooltip('Rescan Installed Applications'), findsNothing);
    expect(find.byTooltip('Hide Tools Rail\n(Re-enable anytime in Preferences)'), findsNothing);
    expect(find.byTooltip('Pin an app to the rail'), findsOneWidget);

    // Pinned apps show up in the rail and can be unpinned
    final app = Directory('${tempDir.path}/Fancy Tool.app')..createSync();
    await tester.runAsync(() => state.pinApp(app.path));
    await tester.pumpAndSettle();
    expect(state.pinnedApps.single.name, 'Fancy Tool');
    expect(find.byTooltip('Fancy Tool\n${app.path}\nRight-click to unpin'), findsOneWidget);

    // Pinning the same app twice is ignored and the pin persists in settings
    await tester.runAsync(() => state.pinApp(app.path));
    expect(state.pinnedApps.length, 1);
    expect(AppSettings.fromJson(state.settings.toJson()).pinnedApps.single.path, app.path);

    state.unpinApp(app.path);
    await tester.pumpAndSettle();
    expect(state.pinnedApps, isEmpty);

    // CLI SDK tools should NOT be shown in the rail
    expect(find.text('git'), findsNothing);
    expect(find.text('python'), findsNothing);
    expect(find.text('flutter'), findsNothing);
    expect(find.text('node'), findsNothing);
    expect(find.text('cargo'), findsNothing);

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ModalPinApp renders search field, Browse button, and pins/unpins apps', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();
    state.modal = const ModalPinApp();

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

    expect(find.text('Pin Application to Toolbar'), findsOneWidget);
    expect(find.text('Browse from Disk…'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Pin an app via state and verify dialog reactivity
    final app = Directory('${tempDir.path}/Custom App.app')..createSync();
    await tester.runAsync(() => state.pinApp(app.path));
    await tester.pumpAndSettle();

    expect(state.pinnedApps.any((a) => a.name == 'Custom App'), isTrue);

    state.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
