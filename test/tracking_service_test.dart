import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/tracking/data/tracking_service.dart';
import 'package:mobile_shop_pro/features/whatsapp/data/whatsapp_repository.dart';

void main() {
  group('tracking URL', () {
    test('builds an app deep link that routes to the tracking screen', () {
      expect(
        TrackingService.buildUrlFromBase(
          'https://yasser-dev2024.github.io/mobail2026fixe/track/?ticket={ticket}',
          'MNT-20260718-0005',
        ),
        'https://yasser-dev2024.github.io/mobail2026fixe/track/?ticket=MNT-20260718-0005',
      );
    });

    test('supports hosted templates and safely encodes ticket numbers', () {
      expect(
        TrackingService.buildUrlFromBase(
          'https://shop.example/track/{ticket}',
          'A 12/3',
        ),
        'https://shop.example/track/A%2012%2F3',
      );
    });

    test('does not produce incomplete links', () {
      expect(TrackingService.buildUrlFromBase('', 'MNT-1'), isEmpty);
      expect(
        TrackingService.buildUrlFromBase(
          'https://yasser-dev2024.github.io/mobail2026fixe/track/?ticket={ticket}',
          '  ',
        ),
        isEmpty,
      );
    });

    test('WhatsApp keeps app links and rejects obsolete placeholder links', () {
      expect(
        WhatsappRepository.isUnsupportedTrackingLink(
          'proshop:///track/MNT-1',
        ),
        isTrue,
      );
      expect(
        WhatsappRepository.isUnsupportedTrackingLink(
          'https://proshop.example.com/track/MNT-1',
        ),
        isTrue,
      );
    });

    test('received message contains only the requested customer details', () {
      final message = WhatsappRepository.buildReceivedCustomerMessage(
        customerName: 'سند',
        trackingUrl: 'https://track.example/MNT-1',
        receivedDate: '2026/07/18',
        device: 'iPhone 15',
        problem: 'لا يشحن',
      );

      expect(message, contains('رابط تتبع الجهاز:'));
      expect(message, contains('تاريخ الاستلام: 2026/07/18'));
      expect(message, contains('نوع الجوال: iPhone 15'));
      expect(message, contains('المشكلة: لا يشحن'));
      expect(message, contains('شكراً لثقتكم بنا'));
      expect(message, isNot(contains('بدون إدخال')));
      expect(message, isNot(contains('رقم الطلب')));
    });
  });
}
