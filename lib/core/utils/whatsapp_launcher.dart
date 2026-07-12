import 'package:url_launcher/url_launcher.dart';

/// Centralised WhatsApp launcher.
///
/// Strategy (desktop-first):
///   1. Try `whatsapp://send?phone=&text=` — opens in the *existing*
///      WhatsApp Desktop window without spawning a new browser tab.
///   2. If WhatsApp Desktop is not installed, fall back to `https://wa.me/`
///      using [LaunchMode.platformDefault] so the OS decides how to open it
///      (usually the current browser window rather than forcing a new one).
class WhatsAppLauncher {
  WhatsAppLauncher._();

  static Future<bool> send({
    required String phone,
    required String message,
  }) async {
    if (phone.trim().isEmpty) return false;

    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Normalize Saudi numbers: leading 0 → country code 966
    final withCode = clean.startsWith('0') ? '966${clean.substring(1)}' : clean;
    final encoded = Uri.encodeComponent(message);

    final appUri = Uri.parse('whatsapp://send?phone=$withCode&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$withCode?text=$encoded');

    try {
      if (await canLaunchUrl(appUri)) {
        return launchUrl(appUri);
      } else {
        // platformDefault lets the OS reuse an existing browser window
        return launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      return false;
    }
  }
}
