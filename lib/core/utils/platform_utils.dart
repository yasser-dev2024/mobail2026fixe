import 'dart:io';

class AppPlatform {
  const AppPlatform._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isAppleDesktop => Platform.isMacOS;

  static bool get isAppleMobile => Platform.isIOS;

  static bool get isAppleFamily => Platform.isMacOS || Platform.isIOS;

  static bool get supportsWindowControls => isDesktop;

  static String get currentId {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ipados';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String get currentLabel {
    switch (currentId) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'ipados':
        return 'iPadOS';
      case 'android':
        return 'Android';
      case 'linux':
        return 'Linux';
      default:
        return 'غير معروف';
    }
  }
}
