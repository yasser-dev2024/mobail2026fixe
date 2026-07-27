import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/services/document_share_service.dart';

void main() {
  group('WhatsApp invoice recipient normalization', () {
    test('normalizes a local Saudi mobile number', () {
      expect(
        DocumentShareService.normalizeWhatsAppPhone('050 123 4567'),
        '966501234567',
      );
    });

    test('removes a zero after the Saudi country code', () {
      expect(
        DocumentShareService.normalizeWhatsAppPhone('+966 050 123 4567'),
        '966501234567',
      );
    });

    test('normalizes an international dialing prefix', () {
      expect(
        DocumentShareService.normalizeWhatsAppPhone('00966-50-123-4567'),
        '966501234567',
      );
    });

    test('normalizes Arabic and Persian digits', () {
      expect(
        DocumentShareService.normalizeWhatsAppPhone('٠٥٠١٢٣٤٥٦٧'),
        '966501234567',
      );
      expect(
        DocumentShareService.normalizeWhatsAppPhone('۰۵۰۱۲۳۴۵۶۷'),
        '966501234567',
      );
    });
  });
}
