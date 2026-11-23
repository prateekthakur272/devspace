import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/features/shell/palette.dart';
import 'package:devspace/platform/launch_at_startup.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('launch_at_startup_test_');
    AppStore.homeOverride = tempDir.path;
    LaunchAtStartup.mockEnabled = false;
    LaunchAtStartup.customAppPathForTesting = '/Applications/DevSpace.app';
  });

  tearDown(() {
    LaunchAtStartup.mockEnabled = null;
    LaunchAtStartup.customAppPathForTesting = null;
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('AppSettings serialization preserves openAtLogin flag', () {
    const defaultSettings = AppSettings();
    expect(defaultSettings.openAtLogin, isFalse);
    expect(defaultSettings.toJson()['openAtLogin'], isFalse);

    final enabled = defaultSettings.copyWith(openAtLogin: true);
    expect(enabled.openAtLogin, isTrue);
    final json = enabled.toJson();
    expect(json['openAtLogin'], isTrue);

    final restored = AppSettings.fromJson(json);
    expect(restored.openAtLogin, isTrue);

    final disabled = enabled.copyWith(openAtLogin: false);
    expect(disabled.openAtLogin, isFalse);
    expect(AppSettings.fromJson(disabled.toJson()).openAtLogin, isFalse);
  });

  test('LaunchAtStartup resolves appPath and respects mock states', () async {
    expect(LaunchAtStartup.appPath, equals('/Applications/DevSpace.app'));

    expect(await LaunchAtStartup.isEnabled(), isFalse);

    final ok = await LaunchAtStartup.setEnabled(true);
    expect(ok, isTrue);
    expect(await LaunchAtStartup.isEnabled(), isTrue);

    final okDisable = await LaunchAtStartup.setEnabled(false);
    expect(okDisable, isTrue);
    expect(await LaunchAtStartup.isEnabled(), isFalse);
  });

  test('AppState toggles openAtLogin, persists settings, and invokes service', () async {
    final state = AppState();
    addTearDown(state.dispose);

    expect(state.settings.openAtLogin, isFalse);
    expect(await LaunchAtStartup.isEnabled(), isFalse);

    await state.setOpenAtLogin(true);

    expect(state.settings.openAtLogin, isTrue);
    expect(await LaunchAtStartup.isEnabled(), isTrue);
    expect(AppStore.loadSettings().openAtLogin, isTrue);

    await state.setOpenAtLogin(false);

    expect(state.settings.openAtLogin, isFalse);
    expect(await LaunchAtStartup.isEnabled(), isFalse);
    expect(AppStore.loadSettings().openAtLogin, isFalse);
  });

  testWidgets('ModalSettings General tab displays Open at Login tile and updates state', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();
    state.modal = const ModalSettings();
    addTearDown(state.dispose);

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

    expect(find.text('Open at Login'), findsOneWidget);
    expect(find.text('Automatically launch DevSpace when you start or log in to your computer.'), findsOneWidget);

    final openAtLoginTile = find.ancestor(
      of: find.text('Open at Login'),
      matching: find.byType(Container),
    ).first;
    final switchFinder = find.descendant(
      of: openAtLoginTile,
      matching: find.byType(Switch),
    );
    expect(switchFinder, findsOneWidget);

    // Initial state is false
    final initialSwitch = tester.widget<Switch>(switchFinder);
    expect(initialSwitch.value, isFalse);

    // Scroll until switch is visible in dialog and tap
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();

    // Tap to enable
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(state.settings.openAtLogin, isTrue);
    expect(await LaunchAtStartup.isEnabled(), isTrue);
  });

  testWidgets('CommandPalette includes Open at Login action', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    state.paletteOpen = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: CommandPalette(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type 'login' in search box to filter
    await tester.enterText(find.byType(TextField), 'login');
    await tester.pumpAndSettle();

    expect(find.text('Settings: Enable Open at Login'), findsOneWidget);
  });
}
