import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfArabicFonts {
  final pw.Font? regular;
  final pw.Font? bold;

  const PdfArabicFonts({required this.regular, required this.bold});
}

class PdfArabicUtils {
  PdfArabicUtils._();

  static Future<PdfArabicFonts> loadFonts() async {
    try {
      final regular = File(r'C:\Windows\Fonts\tahoma.ttf');
      final bold = File(r'C:\Windows\Fonts\tahomabd.ttf');
      if (regular.existsSync() && bold.existsSync()) {
        return PdfArabicFonts(
          regular: pw.Font.ttf(regular.readAsBytesSync().buffer.asByteData()),
          bold: pw.Font.ttf(bold.readAsBytesSync().buffer.asByteData()),
        );
      }
    } catch (_) {}

    try {
      return PdfArabicFonts(
        regular: await PdfGoogleFonts.notoNaskhArabicRegular(),
        bold: await PdfGoogleFonts.notoNaskhArabicBold(),
      );
    } catch (_) {}

    return const PdfArabicFonts(regular: null, bold: null);
  }

  static pw.MemoryImage? loadImage(String? path) {
    final clean = path?.trim() ?? '';
    if (clean.isEmpty) return null;
    try {
      final file = File(clean);
      if (!file.existsSync()) return null;
      return pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static String safeFileName(String value, {String fallback = 'document'}) {
    final clean = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
    if (clean.isEmpty) return fallback;
    return clean.length > 90 ? clean.substring(0, 90) : clean;
  }

  static String uniquePath(String directory, String fileName) {
    final extension = p.extension(fileName);
    final stem = p.basenameWithoutExtension(fileName);
    var candidate = p.join(directory, fileName);
    var counter = 2;
    while (File(candidate).existsSync()) {
      candidate = p.join(directory, '${stem}_$counter$extension');
      counter++;
    }
    return candidate;
  }

  static String text(Object? value, [String fallback = '']) {
    final clean = value?.toString().trim() ?? '';
    return clean.isEmpty ? fallback : clean;
  }

  static int? integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String date(int? value) {
    if (value == null || value <= 0) return 'غير محدد';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String dateTime(int? value) {
    if (value == null || value <= 0) return 'غير محدد';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final day =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day $time';
  }

  static String money(double value, String currency) {
    return '${value.toStringAsFixed(2)} $currency';
  }
}
