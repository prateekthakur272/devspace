// Application configuration and constants.
final class AppConfig {
  const AppConfig._();

  static const String NAME = 'DevSpace';
  static const String PACKAGE_ID = 'dev.prateekthakur.devspace';
  static const String VERSION = '1.0.0';
  static const String COPYRIGHT = 'Copyright © 2026 dev.prateekthakur. All rights reserved.';
  static const String VENDOR = 'Prateek Thakur';
  static const String REPOSITORY = 'https://github.com/prateekthakur272/devspace';
  static const String HOMEPAGE = REPOSITORY;
  static const String DEVELOPER_URL = 'https://github.com/prateekthakur272';
  static const String ISSUES_URL = '$HOMEPAGE/issues/new';

  /// GitHub Releases page — opened when the user clicks "Download" in the update dialog.
  static const String RELEASES_URL = '$HOMEPAGE/releases/latest';

  /// GitHub REST API endpoint for the latest release — used by UpdateChecker.
  static const String RELEASES_API_URL =
      'https://api.github.com/repos/prateekthakur272/devspace/releases/latest';
}
