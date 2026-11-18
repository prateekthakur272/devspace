import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/tools/app_icon_service.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_icon_service_test_');
    AppIconService.testCacheDir = tempDir.path;
    AppIconService.clearMemoryCache();
  });

  tearDown(() {
    AppIconService.testCacheDir = null;
    AppIconService.clearMemoryCache();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('sanitizeId normalizes application IDs correctly', () {
    expect(AppIconService.sanitizeId('Visual Studio Code'), 'visual_studio_code');
    expect(AppIconService.sanitizeId('GitHub Desktop.app'), 'github_desktop_app');
    expect(AppIconService.sanitizeId('openrest-api'), 'openrest_api');
  });

  test('getIconFile returns null when icon not in cache and File when exists', () {
    expect(AppIconService.getIconFile('sample_app'), isNull);

    // Create a dummy png file in cacheDir
    final file = File('${tempDir.path}/sample_app.png');
    file.writeAsStringSync('dummy_png_bytes');

    final cached = AppIconService.getIconFile('sample_app');
    expect(cached, isNotNull);
    expect(cached!.existsSync(), isTrue);
  });

  test('extractTerminalIcon finds and extracts terminal icon on host system', () async {
    final iconPath = await AppIconService.extractTerminalIcon();
    if (Platform.isMacOS) {
      expect(iconPath, isNotNull);
      expect(File(iconPath!).existsSync(), isTrue);
    }
  });

  test('extractEditorIcon extracts installed editor icons on host system', () async {
    if (Platform.isMacOS) {
      final vscodeIcon = await AppIconService.extractEditorIcon(EditorType.vscode);
      expect(vscodeIcon, isNotNull);
      expect(File(vscodeIcon!).existsSync(), isTrue);
    }
  });

  test('extractDesktopAppIcon extracts installed desktop app icons on host system', () async {
    if (Platform.isMacOS) {
      final docker = DesktopAppService.knownApps.firstWhere((a) => a.id == 'docker');
      final dockerIcon = await AppIconService.extractDesktopAppIcon(docker);
      expect(dockerIcon, isNotNull);
      expect(File(dockerIcon!).existsSync(), isTrue);
    }
  });

  test('extractAllInstalled runs without errors', () async {
    await AppIconService.extractAllInstalled(
      editors: [EditorType.vscode],
      desktopApps: DesktopAppService.knownApps.take(2).toList(),
    );
  });
}
