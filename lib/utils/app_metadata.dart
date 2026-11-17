import 'package:devspace/utils/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

final class AppMetadata {
  AppMetadata._();

  static String version = AppConfig.VERSION;
  static String buildNumber = '1';
  static String appName = AppConfig.NAME;
  static String packageName = AppConfig.PACKAGE_ID;

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
      if (info.buildNumber.isNotEmpty) buildNumber = info.buildNumber;
      if (info.appName.isNotEmpty) appName = info.appName;
      if (info.packageName.isNotEmpty) packageName = info.packageName;
    } catch (_) {}
  }
}
