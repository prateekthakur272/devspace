// ignore_for_file: constant_identifier_names

/// Static application configuration: the name, credits and links shown in the About and developer dialogs.
///
/// Compile-time constants only. What the running app reports about itself (version, build number, bundle id) is
/// read at runtime by `AppMetadata` in utils/app_metadata.dart.
final class AppConfig {
  const AppConfig._();

  static const String NAME = 'DevSpace';
  static const String COPYRIGHT = 'Copyright © 2026 dev.prateekthakur. All rights reserved.';
  static const String VENDOR = 'Prateek Thakur';
  static const String TAGLINE =
      'A fast, file-first desktop workspace and project dashboard for developers.';
  static const String DESCRIPTION =
      'DevSpace is a fast, file-first desktop dashboard for developers to organize projects, track git status, and launch tools seamlessly.';
  static const String REPOSITORY = 'https://github.com/prateekthakur272/devspace';
  static const String HOMEPAGE = REPOSITORY;
  static const String DEVELOPER_URL = 'https://github.com/prateekthakur272';
  static const String MORE_APPS_URL =
      'https://prateekthakur272.github.io/github-marketplace/';
  static const String ISSUES_URL = '$HOMEPAGE/issues/new';

  /// GitHub Releases page — opened when the user clicks "Download" in the update dialog.
  static const String RELEASES_URL = '$HOMEPAGE/releases/latest';

  /// GitHub REST API endpoint for the latest release — used by UpdateChecker.
  static const String RELEASES_API_URL =
      'https://api.github.com/repos/prateekthakur272/devspace/releases/latest';
}
