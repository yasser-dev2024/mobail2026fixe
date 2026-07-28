const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

String normalizeDeviceIdentityPart(String? value) {
  final western = (value ?? '').split('').map((character) {
    final arabicIndex = _arabicDigits.indexOf(character);
    if (arabicIndex >= 0) return arabicIndex.toString();
    final persianIndex = _persianDigits.indexOf(character);
    if (persianIndex >= 0) return persianIndex.toString();
    return character;
  }).join();
  return western.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_/\\.+]+'), '');
}

String deviceIdentityKey({
  required String customerId,
  required String brand,
  required String model,
  String? imei,
  String? serialNumber,
  String? color,
}) {
  final normalizedImei = normalizeDeviceIdentityPart(imei);
  if (normalizedImei.isNotEmpty) return 'imei:$normalizedImei';

  final normalizedSerial = normalizeDeviceIdentityPart(serialNumber);
  if (normalizedSerial.isNotEmpty) return 'serial:$normalizedSerial';

  return [
    'spec',
    normalizeDeviceIdentityPart(customerId),
    normalizeDeviceIdentityPart(brand),
    normalizeDeviceIdentityPart(model),
    normalizeDeviceIdentityPart(color),
  ].join(':');
}

bool isSamePhysicalDevice({
  required String firstCustomerId,
  required String firstBrand,
  required String firstModel,
  String? firstImei,
  String? firstSerialNumber,
  String? firstColor,
  required String secondCustomerId,
  required String secondBrand,
  required String secondModel,
  String? secondImei,
  String? secondSerialNumber,
  String? secondColor,
}) {
  final firstImeiKey = normalizeDeviceIdentityPart(firstImei);
  final secondImeiKey = normalizeDeviceIdentityPart(secondImei);
  if (firstImeiKey.isNotEmpty && secondImeiKey.isNotEmpty) {
    return firstImeiKey == secondImeiKey;
  }

  final firstSerialKey = normalizeDeviceIdentityPart(firstSerialNumber);
  final secondSerialKey = normalizeDeviceIdentityPart(secondSerialNumber);
  if (firstSerialKey.isNotEmpty && secondSerialKey.isNotEmpty) {
    return firstSerialKey == secondSerialKey;
  }

  final firstHasIdentifier =
      firstImeiKey.isNotEmpty || firstSerialKey.isNotEmpty;
  final secondHasIdentifier =
      secondImeiKey.isNotEmpty || secondSerialKey.isNotEmpty;
  if (firstHasIdentifier && secondHasIdentifier) return false;

  return deviceIdentityKey(
        customerId: firstCustomerId,
        brand: firstBrand,
        model: firstModel,
        color: firstColor,
      ) ==
      deviceIdentityKey(
        customerId: secondCustomerId,
        brand: secondBrand,
        model: secondModel,
        color: secondColor,
      );
}
