import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/warranty/data/warranty_model.dart';
import 'package:mobile_shop_pro/features/warranty/presentation/widgets/warranty_return_dialog.dart';

WarrantyModel _warranty({
  required String id,
  required DateTime endDate,
  bool isVoid = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return WarrantyModel(
    id: id,
    maintenanceId: 'maintenance-$id',
    customerId: 'customer-$id',
    deviceInfo: 'iPhone 15',
    warrantyType: 'custom',
    warrantyDays: 30,
    startDate: now,
    endDate: endDate.millisecondsSinceEpoch,
    isVoid: isVoid,
    createdAt: now,
    updatedAt: now,
    customerName: 'عميل الاختبار',
  );
}

void main() {
  testWidgets('active warranty record shows the receive-under-warranty button',
      (tester) async {
    final warranty = _warranty(
      id: 'active',
      endDate: DateTime.now().add(const Duration(days: 30)),
    );
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarrantyReturnButton(
            warranty: warranty,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('استلام الجوال تحت الضمان'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('receive-under-warranty-active')),
      findsOneWidget,
    );

    await tester.tap(find.text('استلام الجوال تحت الضمان'));
    expect(tapped, isTrue);
  });

  testWidgets('expired warranty record hides the receive button',
      (tester) async {
    final warranty = _warranty(
      id: 'expired',
      endDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarrantyReturnButton(
            warranty: warranty,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('استلام الجوال تحت الضمان'), findsNothing);
  });
}
