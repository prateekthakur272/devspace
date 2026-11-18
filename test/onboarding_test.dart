import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/dialogs/onboarding_dialog.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_onboarding_test_');
    AppStore.homeOverride = tempDir.path;
  });

  tearDown(() {
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('AppStore.needsOnboarding detects fresh install and respects completion flag', () {
    expect(AppStore.needsOnboarding, isTrue);

    AppStore.setFlag('onboarding_completed', true);
    expect(AppStore.needsOnboarding, isFalse);
  });

  testWidgets('OnboardingDialog navigates through steps and completes', (t) async {
    final state = AppState();
    addTearDown(state.dispose);
    state.modal = const ModalOnboarding();

    await t.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: OnboardingDialog(state: state),
          ),
        ),
      ),
    );
    await t.pump();

    // Step 0: Welcome
    expect(find.text('Workspace Catalog & Groups'), findsOneWidget);
    expect(find.text('Real-Time Combined Git Radar'), findsOneWidget);
    expect(find.text('Contextual Notes & Scratchpad'), findsOneWidget);

    // Advance to Step 1: Customize
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));

    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Preferred IDE / Editor'), findsOneWidget);

    // Click Light Theme option
    await t.tap(find.text('Light'));
    await t.pump();
    expect(state.settings.themeMode, equals(ThemeMode.light));

    // Advance to Step 2: Get Started
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));

    expect(find.text('Import Your First Project'), findsOneWidget);
    expect(find.text('Browse Local Repository'), findsOneWidget);
    expect(find.text('Create Workspace Group'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Complete onboarding
    await t.tap(find.text('Get Started'));
    await t.pump();

    expect(state.modal, isNull);
    expect(AppStore.flag('onboarding_completed'), isTrue);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('OnboardingDialog can be skipped directly', (t) async {
    final state = AppState();
    addTearDown(state.dispose);
    state.modal = const ModalOnboarding();

    await t.pumpWidget(
      MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: OnboardingDialog(state: state),
          ),
        ),
      ),
    );
    await t.pump();

    await t.tap(find.text('Skip'));
    await t.pump();

    expect(state.modal, isNull);
    expect(AppStore.flag('onboarding_completed'), isTrue);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
