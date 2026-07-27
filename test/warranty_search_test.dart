import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/warranty/data/warranty_model.dart';
import 'package:mobile_shop_pro/features/warranty/presentation/screens/warranty_screen.dart';

void main() {
  WarrantyModel warranty({
    required String id,
    required String customerName,
    required String customerPhone,
    required String ticketNumber,
    required String deviceInfo,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WarrantyModel(
      id: id,
      maintenanceId: 'maintenance_$id',
      customerId: 'customer_$id',
      deviceInfo: deviceInfo,
      warrantyType: 'custom',
      warrantyDays: 30,
      startDate: now,
      endDate: now + const Duration(days: 30).inMilliseconds,
      isVoid: false,
      createdAt: now,
      updatedAt: now,
      customerName: customerName,
      customerPhone: customerPhone,
      ticketNumber: ticketNumber,
    );
  }

  final warranties = [
    warranty(
      id: '1',
      customerName: 'سامي محمد',
      customerPhone: '0501234567',
      ticketNumber: 'MNT-1001',
      deviceInfo: 'Samsung S24',
    ),
    warranty(
      id: '2',
      customerName: 'خالد علي',
      customerPhone: '0557654321',
      ticketNumber: 'MNT-1002',
      deviceInfo: 'iPhone 15 Pro',
    ),
  ];

  test('filters warranty rows by customer name', () {
    final result = filterWarrantyRows(warranties, nameQuery: 'سامي');

    expect(result.map((item) => item.id), ['1']);
  });

  test('filters phone numbers using Arabic digits', () {
    final result = filterWarrantyRows(
      warranties,
      phoneQuery: '٠٥٥٧٦٥',
    );

    expect(result.map((item) => item.id), ['2']);
  });

  test('filters by ticket number or device', () {
    expect(
      filterWarrantyRows(warranties, recordQuery: 'mnt-1001')
          .map((item) => item.id),
      ['1'],
    );
    expect(
      filterWarrantyRows(warranties, recordQuery: 'iphone')
          .map((item) => item.id),
      ['2'],
    );
  });

  test('combines the flexible search fields', () {
    final result = filterWarrantyRows(
      warranties,
      nameQuery: 'خالد',
      phoneQuery: '0557',
      recordQuery: '1002',
    );

    expect(result.map((item) => item.id), ['2']);
  });
}
