import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/core/tools/desktop_app_service.dart';

void main() {
  test('DesktopAppService defines known developer desktop applications', () {
    final apps = DesktopAppService.knownApps;
    expect(apps, isNotEmpty);

    final appIds = apps.map((a) => a.id).toSet();
    expect(appIds.contains('docker'), isTrue);
    expect(appIds.contains('github_desktop'), isTrue);
    expect(appIds.contains('openrest'), isTrue);
    expect(appIds.contains('postman'), isTrue);
    expect(appIds.contains('tableplus'), isTrue);
    expect(appIds.contains('dbeaver'), isTrue);
  });

  test('DesktopApp copyWith updates resolvedPath correctly', () {
    final app = DesktopAppService.knownApps.first;
    final updated = app.copyWith(resolvedPath: '/Applications/Docker.app');

    expect(updated.id, app.id);
    expect(updated.name, app.name);
    expect(updated.resolvedPath, '/Applications/Docker.app');
  });

  test('DesktopAppService.detectAll scans and returns detected desktop applications', () async {
    final detected = await DesktopAppService.detectAll();
    // On macOS in this dev environment, Docker and GitHub Desktop should be detected
    expect(detected, isA<List<DesktopApp>>());
  });
}
