import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class DocumentShareService {
  DocumentShareService._();

  static const MethodChannel _channel =
      MethodChannel('com.proshop.mobile_shop_pro/document_share');

  static Future<bool> sharePdfToWhatsApp({
    required String filePath,
    required String phone,
    required String message,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'sharePdfToWhatsApp',
          {
            'filePath': filePath,
            'phone': _normalizePhone(phone),
            'message': message,
          },
        );
        return ok ?? false;
      } on PlatformException {
        return false;
      }
    }

    try {
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: p.basename(filePath),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> savePdfToDownloads({
    required String filePath,
    String? fileName,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final safeFileName = _normalizePdfName(fileName ?? p.basename(filePath));
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>(
          'savePdfToDownloads',
          {
            'filePath': filePath,
            'fileName': safeFileName,
          },
        );
      } on PlatformException {
        return null;
      }
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) return null;
      final dir = Directory(p.join(downloads.path, 'ProShop'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final targetPath = _uniquePath(dir.path, safeFileName);
      await file.copy(targetPath);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  static String _normalizePhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0') && clean.length >= 9) {
      return '966${clean.substring(1)}';
    }
    return clean;
  }

  static String _normalizePdfName(String fileName) {
    final clean = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final fallback = clean.isEmpty ? 'ProShop-document.pdf' : clean;
    return fallback.toLowerCase().endsWith('.pdf') ? fallback : '$fallback.pdf';
  }

  static String _uniquePath(String directory, String fileName) {
    final parsed =
        p.Context(style: Platform.isWindows ? p.Style.windows : p.Style.posix);
    final base = parsed.basenameWithoutExtension(fileName);
    final extension = parsed.extension(fileName);
    var candidate = parsed.join(directory, fileName);
    var index = 1;
    while (File(candidate).existsSync()) {
      candidate = parsed.join(directory, '${base}_$index$extension');
      index += 1;
    }
    return candidate;
  }
}
