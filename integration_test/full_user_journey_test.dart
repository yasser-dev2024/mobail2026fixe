import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_shop_pro/core/constants/app_constants.dart';
import 'package:mobile_shop_pro/core/database/database_service.dart';
import 'package:mobile_shop_pro/core/services/backup_service.dart';
import 'package:mobile_shop_pro/core/services/settings_service.dart';
import 'package:mobile_shop_pro/features/auth/data/auth_repository.dart';
import 'package:mobile_shop_pro/features/invoices/data/invoice_repository.dart';
import 'package:mobile_shop_pro/features/repair_board/data/repair_board_repository.dart';
import 'package:mobile_shop_pro/features/warranty/data/warranty_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete isolated shop and repair journey', (tester) async {
    const documentChannel =
        MethodChannel('com.proshop.mobile_shop_pro/document_share');
    final shareCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(documentChannel, (call) async {
      shareCalls.add(call);
      if (call.method == 'sharePdfToWhatsApp') {
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        final pdf = File(arguments['filePath'] as String);
        expect(pdf.existsSync(), isTrue);
        expect(pdf.lengthSync(), greaterThan(100));
        expect(
          String.fromCharCodes(pdf.readAsBytesSync().take(5)),
          '%PDF-',
        );
        expect(arguments['message'], contains('PDF'));
        return true;
      }
      if (call.method == 'savePdfToDownloads') {
        return (call.arguments as Map)['filePath'];
      }
      return false;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(documentChannel, null);
    });

    final auth = AuthRepository();
    final user = await auth.login('admin', 'admin123');
    expect(user, isNotNull);
    expect(user!.role, AppConstants.roleOwner);

    final settings = SettingsService();
    await settings.load();
    await settings.save({
      'shop_name': 'مركز اختبار مساعد الصيانة',
      'shop_phone': '0500000000',
      'shop_address': 'الرياض',
      'warranty_terms': 'ضمان اختبار يشمل بيانات العميل والجهاز',
      'invoice_general_terms': 'الشروط العامة لاختبار الرحلة',
      'invoice_footer': 'فاتورة اختبار معزولة',
      'auto_whatsapp_send': 'false',
    });
    expect(settings.shopName, 'مركز اختبار مساعد الصيانة');

    final marker = DateTime.now().microsecondsSinceEpoch.toString();
    final repairBoard = RepairBoardRepository();
    final intake = RepairIntakeData(
      customerName: 'QA Customer $marker',
      customerPhone: '0501234567',
      customerPhone2: '',
      receiverName: 'موظف الاختبار',
      deviceType: 'جوال',
      company: 'Samsung',
      model: 'A55 QA $marker',
      color: 'Black',
      imei: '35$marker',
      serial: 'SER-$marker',
      lockCode: '1234',
      accessories: 'غطاء',
      problem: 'اختبار إصلاح الشاشة',
      deviceCondition: 'سليم خارجياً',
      damage: '',
      deviceWorks: true,
      deviceCharges: true,
      waterDamage: false,
      extraNotes: 'بيانات رحلة اختبار معزولة',
      imagePaths: const [],
      expectedRepairDays: 2,
    );
    final maintenanceId = await repairBoard.receiveNewDevice(intake);
    final initialBoard = await repairBoard.loadBoard(search: marker);
    expect(initialBoard.activeDevices, hasLength(1));
    final initialMaintenance = initialBoard.activeDevices.single.maintenance;
    expect(initialMaintenance.id, maintenanceId);
    expect(initialMaintenance.deviceId, isNotNull);

    await expectLater(
      repairBoard.receiveNewDevice(intake),
      throwsA(
        predicate(
          (error) => error.toString().contains('لا يزال داخل الصيانة'),
        ),
      ),
    );

    await repairBoard.markUnderRepair(
      maintenanceId,
      note: 'بدأ الإصلاح في رحلة الاختبار',
    );
    await repairBoard.markReady(
      maintenanceId: maintenanceId,
      repairDetails: 'تم استبدال الشاشة واختبار الجهاز',
      changedPart: 'شاشة اختبار',
      cost: 250,
      warrantyDays: 30,
      notes: 'تم الفحص النهائي',
    );
    await repairBoard.confirmDelivery(
      maintenanceId: maintenanceId,
      paidAmount: 250,
      warrantyDays: 30,
      deliveryCondition: 'يعمل بصورة سليمة',
      receiverName: 'QA Receiver',
      warrantyTerms: 'ضمان 30 يوماً لا يشمل الكسر أو الماء',
      notes: 'تم التسليم في رحلة الاختبار',
    );

    expect(
      shareCalls.where((call) => call.method == 'sharePdfToWhatsApp'),
      hasLength(1),
    );
    final invoice = await InvoiceRepository().getByMaintenance(maintenanceId);
    expect(invoice, isNotNull);
    expect(invoice!.sentStatus, 'opened');
    expect(invoice.status, AppConstants.invoiceApproved);
    expect(invoice.sentAt, isNull);
    expect(invoice.warrantyDays, 30);
    expect(invoice.warrantyTermsSnapshot, contains('لا يشمل الكسر'));
    expect(File(invoice.pdfPath!).existsSync(), isTrue);

    final warranty = await WarrantyRepository().getByMaintenance(maintenanceId);
    expect(warranty, isNotNull);
    expect(warranty!.isVoid, isFalse);
    expect(warranty.warrantyDays, 30);

    await expectLater(
      repairBoard.receiveNewDevice(intake),
      throwsA(
        predicate(
          (error) => error.toString().contains('ما زال تحت الضمان'),
        ),
      ),
    );

    await repairBoard.receiveUnderWarranty(
      warranty: warranty,
      problem: 'ظهرت المشكلة نفسها أثناء الضمان',
      customerDescription: 'الشاشة توقفت مؤقتاً',
      deviceCondition: 'دون كسر أو ماء',
      employeeNotes: 'عودة ضمان في رحلة الاختبار',
    );
    final warrantyClaims = await WarrantyRepository().getClaims(warranty.id);
    expect(warrantyClaims, hasLength(1));
    final boardAfterWarranty = await repairBoard.loadBoard(search: marker);
    expect(
      boardAfterWarranty.activeDevices.single.maintenance.status,
      AppConstants.statusWarrantyReturn,
    );

    final db = DatabaseService();
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first['user_version'], AppConstants.dbVersion);
    final activeMaintenance = await db.rawQuery(
      '''
SELECT COUNT(*) AS count
FROM maintenance
WHERE device_id = ?
  AND deleted_at IS NULL
  AND status NOT IN ('delivered', 'cancelled')
''',
      [initialMaintenance.deviceId],
    );
    expect(activeMaintenance.first['count'], 1);
    final activeWarranties = await db.rawQuery(
      '''
SELECT COUNT(*) AS count
FROM warranties w
JOIN maintenance m ON m.id = w.maintenance_id AND m.shop_id = w.shop_id
WHERE m.device_id = ? AND w.is_void = 0
''',
      [initialMaintenance.deviceId],
    );
    expect(activeWarranties.first['count'], 1);
    final notifications = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM notifications',
    );
    expect((notifications.first['count'] as int?) ?? 0, greaterThan(0));

    final appDir = await BackupService().getAppDataDir();
    final backupPath = '${appDir.path}${Platform.pathSeparator}Backups'
        '${Platform.pathSeparator}qa_full_journey_$marker.proshop';
    expect(
      await BackupService().createBackup(
        backupPath,
        type: 'qa',
        notes: 'اختبار رحلة المستخدم الكاملة',
      ),
      isTrue,
    );
    expect(File(backupPath).lengthSync(), greaterThan(100));
  });
}
