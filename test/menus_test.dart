import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/shell/menus.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_menus_test_');
    AppStore.homeOverride = tempDir.path;
  });

  tearDown(() {
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('buildMacMenus returns standard native menu hierarchy', () {
    final state = AppState();
    addTearDown(state.dispose);

    final menus = buildMacMenus(state, () {});

    expect(menus.map((m) => m.label).toList(), [
      AppConfig.NAME,
      'File',
      'Edit',
      'View',
      'Window',
      'Help',
    ]);
  });

  test('buildWindowsLinuxMenuItems returns expected menu categories and items', () {
    final state = AppState();
    addTearDown(state.dispose);

    final menuMap = buildWindowsLinuxMenuItems(
      state: state,
      onQuit: () {},
    );

    expect(menuMap.keys.toList(), [
      'File',
      'Edit',
      'View',
      'Window',
      'Help',
    ]);

    expect(menuMap['File']!.any((i) => i.label == 'Add Project…'), isTrue);
    expect(menuMap['File']!.any((i) => i.label == 'New Note'), isTrue);
    expect(menuMap['View']!.any((i) => i.label == 'Command Palette…'), isTrue);
    expect(menuMap['Window']!.any((i) => i.label == 'Minimize'), isTrue);
    expect(menuMap['Help']!.any((i) => i.label == 'Check for Updates…'), isTrue);
  });

  testWidgets('WindowMenuBar renders menu bar titles and responds to clicks', (t) async {
    final state = AppState();
    addTearDown(state.dispose);

    await t.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: WindowMenuBar(
              state: state,
              onQuit: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);

    // Tap File to verify dropdown trigger
    await t.tap(find.text('File'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(find.text('Add Project…'), findsOneWidget);
  });
}
