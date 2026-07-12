import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/constants/app_constants.dart';
import 'package:mobile_shop_pro/features/invoices/data/invoice_model.dart';

void main() {
  test('invoice warranty status is active before end date', () {
    final end =
        DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;

    expect(
      InvoiceModel.calculateWarrantyStatus(
        warrantyType: AppConstants.warrantyCustom,
        warrantyEnd: end,
      ),
      'active',
    );
  });

  test('invoice without warranty reports none', () {
    expect(
      InvoiceModel.calculateWarrantyStatus(
        warrantyType: AppConstants.warrantyNone,
        warrantyEnd: null,
      ),
      'none',
    );
  });
}
