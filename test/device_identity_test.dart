import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/devices/data/device_identity.dart';

void main() {
  group('device identity', () {
    test('normalizes Arabic digits and separators', () {
      expect(
        normalizeDeviceIdentityPart(' ٣٥-١٢ / AB.C '),
        '3512abc',
      );
    });

    test('matches the same IMEI regardless of formatting or customer', () {
      expect(
        isSamePhysicalDevice(
          firstCustomerId: 'customer-1',
          firstBrand: 'Apple',
          firstModel: 'iPhone 15',
          firstImei: '٣٥-١٢ 99',
          secondCustomerId: 'customer-2',
          secondBrand: 'آبل',
          secondModel: 'آيفون',
          secondImei: '351299',
        ),
        isTrue,
      );
    });

    test('reuses an older unnumbered device when its identifier is added', () {
      expect(
        isSamePhysicalDevice(
          firstCustomerId: 'customer-1',
          firstBrand: ' Samsung ',
          firstModel: 'A 55',
          firstImei: '123456789',
          firstColor: 'Black',
          secondCustomerId: 'customer-1',
          secondBrand: 'samsung',
          secondModel: 'A55',
          secondColor: ' black ',
        ),
        isTrue,
      );
    });

    test('does not merge two numbered phones with different identifiers', () {
      expect(
        isSamePhysicalDevice(
          firstCustomerId: 'customer-1',
          firstBrand: 'Samsung',
          firstModel: 'A55',
          firstImei: '111',
          firstColor: 'Black',
          secondCustomerId: 'customer-1',
          secondBrand: 'Samsung',
          secondModel: 'A55',
          secondImei: '222',
          secondColor: 'Black',
        ),
        isFalse,
      );
    });

    test('does not merge unnumbered phones belonging to different customers',
        () {
      expect(
        isSamePhysicalDevice(
          firstCustomerId: 'customer-1',
          firstBrand: 'Samsung',
          firstModel: 'A55',
          secondCustomerId: 'customer-2',
          secondBrand: 'Samsung',
          secondModel: 'A55',
        ),
        isFalse,
      );
    });
  });
}
