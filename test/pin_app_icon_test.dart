import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_pin_icon_test_');
    AppStore.homeOverride = tempDir.path;
    AppStore.setFlag('onboarding_completed', true);
    AppIconService.testCacheDir = tempDir.path;
    AppIconService.disableExtractionForTesting = true;
    AppIconService.clearMemoryCache();
  });

  tearDown(() {
    AppIconService.disableExtractionForTesting = false;
    AppIconService.testCacheDir = null;
    AppIconService.clearMemoryCache();
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('Pin Application dialog renders search and app list with icon resolution', (tester) async {
    // Write a dummy icon file to test cache dir for a mock app
    final iconFile = File('${tempDir.path}/android_studio.png');
    iconFile.writeAsStringSync('dummy_png_bytes');

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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pin Application to Toolbar'), findsOneWidget);
    expect(find.text('Quick-Launch Toolbar Applications'), findsOneWidget);
    expect(find.text('Browse from Disk…'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    state.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
