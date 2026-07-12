import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/warranty/data/warranty_model.dart';

void main() {
  WarrantyModel warrantyWith({
    required int days,
    required int warrantyDays,
    bool isVoid = false,
  }) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: days));

    return WarrantyModel(
      id: 'warranty',
      maintenanceId: 'maintenance',
      customerId: 'customer',
      deviceInfo: 'iPhone',
      warrantyType: 'custom',
      warrantyDays: warrantyDays,
      startDate: start.millisecondsSinceEpoch,
      endDate: end.millisecondsSinceEpoch,
      isVoid: isVoid,
      createdAt: start.millisecondsSinceEpoch,
      updatedAt: start.millisecondsSinceEpoch,
    );
  }

  test('warranty countdown uses calendar days', () {
    final warranty = warrantyWith(days: 1, warrantyDays: 30);

    expect(warranty.calendarDaysRemaining, 1);
    expect(warranty.daysRemaining, 1);
    expect(warranty.status, 'expiring');
  });

  test('long warranty is more than 90 days', () {
    expect(warrantyWith(days: 120, warrantyDays: 91).isLongWarranty, isTrue);
    expect(warrantyWith(days: 90, warrantyDays: 90).isLongWarranty, isFalse);
  });
}
