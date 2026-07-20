import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../utils/platform_utils.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final appDir = await getDataDirectory();
    final dbFolder = Directory(p.join(appDir.path, 'Database'));
    if (!dbFolder.existsSync()) dbFolder.createSync(recursive: true);
    final dbPath = p.join(dbFolder.path, AppConstants.dbName);

    if (AppPlatform.isDesktop) {
      ffi.sqfliteFfiInit();
      return await ffi.databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppConstants.dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: _onConfigure,
        ),
      );
    }

    return await openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = 10000');
    await db.execute('PRAGMA temp_store = MEMORY');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createUsersTable(batch);
    _createCustomersTable(batch);
    _createDevicesTable(batch);
    _createMaintenanceTable(batch);
    _createMaintenanceStatusHistoryTable(batch);
    _createMaintenanceChecklistsTable(batch);
    _createMaintenanceApprovalsTable(batch);
    _createMaintenancePartsTable(batch);
    _createMaintenanceImagesTable(batch);
    _createWarrantyTable(batch);
    _createWarrantyClaimsTable(batch);
    _createWarrantyActionsTable(batch);
    _createProductsTable(batch);
    _createSuppliersTable(batch);
    _createPurchasesTable(batch);
    _createPurchaseItemsTable(batch);
    _createSalesTable(batch);
    _createSaleItemsTable(batch);
    _createTransactionsTable(batch);
    _createNotificationsTable(batch);
    _createWhatsappTemplatesTable(batch);
    _createWhatsappLogsTable(batch);
    _createWhatsappMessagesTable(batch);
    _createInvoiceSequenceTable(batch);
    _createInvoicesTable(batch);
    _createDevicePhotosTable(batch);
    _createDeviceReportsTable(batch);
    _createDocumentSendLogsTable(batch);
    _createAuditLogTable(batch);
    _createSettingsTable(batch);
    _createTechnicianCustodyTable(batch);
    _createMediaFilesTable(batch);
    _createBackupLogsTable(batch);
    await batch.commit(noResult: true);
    await _insertDefaultData(db);
    await _ensureWhatsappMessageTemplateSeeds(db);
    await _ensureLocalShopIdentity(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _backupBeforeUpgrade(db, oldVersion, newVersion);

    if (oldVersion < 2) {
      // Add purchase_cost to maintenance_parts for accurate profit tracking
      try {
        await db.execute(
          'ALTER TABLE maintenance_parts ADD COLUMN purchase_cost REAL NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column may already exist on some dev builds — safe to ignore.
      }
    }
    if (oldVersion < 3) {
      final batch = db.batch();
      _createMaintenanceStatusHistoryTable(batch);
      _createMaintenanceChecklistsTable(batch);
      _createMaintenanceApprovalsTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 4) {
      final batch = db.batch();
      _createWhatsappMessagesTable(batch);
      batch.insert(
          'settings',
          {
            'key': 'auto_whatsapp_send',
            'value': 'false',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 5) {
      final batch = db.batch();
      _createInvoiceSequenceTable(batch);
      _createInvoicesTable(batch);
      _createDevicePhotosTable(batch);
      _createDeviceReportsTable(batch);
      _createDocumentSendLogsTable(batch);
      _insertInvoiceAndPhotoDefaultSettings(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE backup_logs ADD COLUMN shop_id TEXT NOT NULL DEFAULT 'default_shop'",
        );
      } catch (_) {
        // Column may already exist on development databases.
      }
      await _ensureLocalShopIdentity(db);
    }
    if (oldVersion < 7) {
      final batch = db.batch();
      _insertShopSetupDefaultSettings(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 8) {
      await _ensureShopScopedCoreTables(db);
    }
    if (oldVersion < 9) {
      await _ensureNotificationShopScope(db);
    }
    if (oldVersion < 10) {
      await _ensureWarrantyManagementSchema(db);
    }
    if (oldVersion < 11) {
      await _ensureAlertRecurrenceSchema(db);
      await _ensureWhatsappMessageTemplateSeeds(db);
    }
  }

  void _createUsersTable(Batch batch) {
    batch.execute('''CREATE TABLE users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'cashier',
      email TEXT,
      phone TEXT,
      avatar_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      failed_attempts INTEGER NOT NULL DEFAULT 0,
      locked_until INTEGER,
      last_login INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute('CREATE INDEX idx_users_username ON users(username)');
    batch.execute('CREATE INDEX idx_users_role ON users(role)');
  }

  void _createCustomersTable(Batch batch) {
    batch.execute('''CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      phone2 TEXT,
      email TEXT,
      address TEXT,
      notes TEXT,
      customer_type TEXT DEFAULT 'regular',
      total_spent REAL NOT NULL DEFAULT 0,
      visit_count INTEGER NOT NULL DEFAULT 0,
      last_visit INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute('CREATE INDEX idx_customers_shop ON customers(shop_id)');
    batch.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    batch.execute('CREATE INDEX idx_customers_name ON customers(name)');
  }

  void _createDevicesTable(Batch batch) {
    batch.execute('''CREATE TABLE devices (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      customer_id TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT NOT NULL,
      imei TEXT,
      serial_number TEXT,
      color TEXT,
      storage TEXT,
      image_path TEXT,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    )''');
    batch.execute('CREATE INDEX idx_devices_shop ON devices(shop_id)');
    batch.execute('CREATE INDEX idx_devices_customer ON devices(customer_id)');
    batch.execute('CREATE INDEX idx_devices_imei ON devices(imei)');
  }

  void _createMaintenanceTable(Batch batch) {
    batch.execute('''CREATE TABLE maintenance (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      ticket_number TEXT UNIQUE NOT NULL,
      customer_id TEXT NOT NULL,
      device_id TEXT,
      brand TEXT NOT NULL,
      model TEXT NOT NULL,
      imei TEXT,
      color TEXT,
      fault_description TEXT NOT NULL,
      technician_id TEXT,
      status TEXT NOT NULL DEFAULT 'new',
      labor_cost REAL NOT NULL DEFAULT 0,
      parts_cost REAL NOT NULL DEFAULT 0,
      total_cost REAL NOT NULL DEFAULT 0,
      advance_paid REAL NOT NULL DEFAULT 0,
      warranty_type TEXT DEFAULT 'none',
      warranty_days INTEGER DEFAULT 0,
      warranty_start INTEGER,
      warranty_end INTEGER,
      received_at INTEGER NOT NULL,
      estimated_delivery INTEGER,
      delivered_at INTEGER,
      notes TEXT,
      internal_notes TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    )''');
    batch.execute('CREATE INDEX idx_maintenance_shop ON maintenance(shop_id)');
    batch.execute(
        'CREATE INDEX idx_maintenance_customer ON maintenance(customer_id)');
    batch.execute('CREATE INDEX idx_maintenance_status ON maintenance(status)');
    batch.execute(
        'CREATE INDEX idx_maintenance_ticket ON maintenance(ticket_number)');
    batch.execute(
        'CREATE INDEX idx_maintenance_technician ON maintenance(technician_id)');
  }

  void _createMaintenanceStatusHistoryTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS maintenance_status_history (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      old_status TEXT,
      new_status TEXT NOT NULL,
      user_id TEXT,
      username TEXT,
      reason TEXT,
      notes TEXT,
      changed_at INTEGER NOT NULL,
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mstatus_maintenance ON maintenance_status_history(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mstatus_changed ON maintenance_status_history(changed_at)');
  }

  void _createMaintenanceChecklistsTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS maintenance_checklists (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      checklist_type TEXT NOT NULL,
      items_json TEXT NOT NULL,
      overall_status TEXT NOT NULL DEFAULT 'pending',
      performed_by TEXT,
      approved_by TEXT,
      notes TEXT,
      checked_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(maintenance_id, checklist_type),
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mcheck_maintenance ON maintenance_checklists(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mcheck_type ON maintenance_checklists(checklist_type)');
  }

  void _createMaintenanceApprovalsTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS maintenance_approvals (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      approval_status TEXT NOT NULL DEFAULT 'pending',
      offered_amount REAL NOT NULL DEFAULT 0,
      approved_amount REAL NOT NULL DEFAULT 0,
      approval_method TEXT NOT NULL,
      employee_name TEXT,
      customer_message TEXT,
      terms TEXT,
      approved_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(maintenance_id),
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mapproval_maintenance ON maintenance_approvals(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_mapproval_status ON maintenance_approvals(approval_status)');
  }

  void _createMaintenancePartsTable(Batch batch) {
    batch.execute('''CREATE TABLE maintenance_parts (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      product_id TEXT,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price REAL NOT NULL DEFAULT 0,
      purchase_cost REAL NOT NULL DEFAULT 0,
      total_price REAL NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX idx_mparts_maintenance ON maintenance_parts(maintenance_id)');
  }

  void _createMaintenanceImagesTable(Batch batch) {
    batch.execute('''CREATE TABLE maintenance_images (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      image_path TEXT NOT NULL,
      image_type TEXT NOT NULL DEFAULT 'before',
      caption TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX idx_mimages_maintenance ON maintenance_images(maintenance_id)');
  }

  void _createWarrantyTable(Batch batch) {
    batch.execute('''CREATE TABLE warranties (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      maintenance_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      device_info TEXT NOT NULL,
      warranty_type TEXT NOT NULL,
      warranty_days INTEGER NOT NULL DEFAULT 0,
      start_date INTEGER NOT NULL,
      end_date INTEGER NOT NULL,
      notes TEXT,
      is_void INTEGER NOT NULL DEFAULT 0,
      alert_disabled INTEGER NOT NULL DEFAULT 0,
      alert_disabled_reason TEXT,
      alert_disabled_at INTEGER,
      alert_disabled_by TEXT,
      expiry_approved INTEGER NOT NULL DEFAULT 0,
      expiry_approved_at INTEGER,
      expiry_approved_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute('CREATE INDEX idx_warranty_shop ON warranties(shop_id)');
    batch.execute(
        'CREATE INDEX idx_warranty_maintenance ON warranties(maintenance_id)');
    batch.execute('CREATE INDEX idx_warranty_end ON warranties(end_date)');
  }

  void _createWarrantyClaimsTable(Batch batch) {
    batch.execute('''CREATE TABLE warranty_claims (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      warranty_id TEXT NOT NULL,
      maintenance_id TEXT,
      description TEXT NOT NULL,
      resolution TEXT,
      status TEXT NOT NULL DEFAULT 'open',
      created_at INTEGER NOT NULL,
      resolved_at INTEGER,
      FOREIGN KEY (warranty_id) REFERENCES warranties(id)
    )''');
  }

  void _createWarrantyActionsTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS warranty_actions (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      warranty_id TEXT NOT NULL,
      maintenance_id TEXT,
      action TEXT NOT NULL,
      old_value TEXT,
      new_value TEXT,
      user_id TEXT,
      username TEXT,
      notes TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (warranty_id) REFERENCES warranties(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wactions_warranty ON warranty_actions(warranty_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wactions_shop ON warranty_actions(shop_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wactions_created ON warranty_actions(created_at)');
  }

  void _createProductsTable(Batch batch) {
    batch.execute('''CREATE TABLE products (
      id TEXT PRIMARY KEY,
      category_key TEXT,
      name TEXT NOT NULL,
      barcode TEXT,
      description TEXT,
      image_path TEXT,
      quantity INTEGER NOT NULL DEFAULT 0,
      low_stock_threshold INTEGER NOT NULL DEFAULT 5,
      purchase_price REAL NOT NULL DEFAULT 0,
      sale_price REAL NOT NULL DEFAULT 0,
      supplier_id TEXT,
      warranty_days INTEGER DEFAULT 0,
      is_service INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute(
        'CREATE INDEX idx_products_category ON products(category_key)');
    batch.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    batch.execute('CREATE INDEX idx_products_quantity ON products(quantity)');
  }

  void _createSuppliersTable(Batch batch) {
    batch.execute('''CREATE TABLE suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT,
      phone2 TEXT,
      email TEXT,
      address TEXT,
      notes TEXT,
      balance REAL NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
  }

  void _createPurchasesTable(Batch batch) {
    batch.execute('''CREATE TABLE purchases (
      id TEXT PRIMARY KEY,
      invoice_number TEXT UNIQUE NOT NULL,
      supplier_id TEXT,
      supplier_name TEXT,
      subtotal REAL NOT NULL DEFAULT 0,
      tax REAL NOT NULL DEFAULT 0,
      shipping REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL DEFAULT 0,
      amount_paid REAL NOT NULL DEFAULT 0,
      payment_method TEXT DEFAULT 'cash',
      notes TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute(
        'CREATE INDEX idx_purchases_supplier ON purchases(supplier_id)');
    batch
        .execute('CREATE INDEX idx_purchases_created ON purchases(created_at)');
  }

  void _createPurchaseItemsTable(Batch batch) {
    batch.execute('''CREATE TABLE purchase_items (
      id TEXT PRIMARY KEY,
      purchase_id TEXT NOT NULL,
      product_id TEXT,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price REAL NOT NULL DEFAULT 0,
      total_price REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (purchase_id) REFERENCES purchases(id)
    )''');
    batch.execute(
        'CREATE INDEX idx_pitems_purchase ON purchase_items(purchase_id)');
  }

  void _createSalesTable(Batch batch) {
    batch.execute('''CREATE TABLE sales (
      id TEXT PRIMARY KEY,
      invoice_number TEXT UNIQUE NOT NULL,
      customer_id TEXT,
      customer_name TEXT,
      maintenance_id TEXT,
      subtotal REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      tax REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL DEFAULT 0,
      amount_paid REAL NOT NULL DEFAULT 0,
      change_amount REAL NOT NULL DEFAULT 0,
      payment_method TEXT DEFAULT 'cash',
      is_credit INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute('CREATE INDEX idx_sales_customer ON sales(customer_id)');
    batch.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
    batch.execute('CREATE INDEX idx_sales_invoice ON sales(invoice_number)');
  }

  void _createSaleItemsTable(Batch batch) {
    batch.execute('''CREATE TABLE sale_items (
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL,
      product_id TEXT,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      total_price REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (sale_id) REFERENCES sales(id)
    )''');
    batch.execute('CREATE INDEX idx_sitems_sale ON sale_items(sale_id)');
  }

  void _createTransactionsTable(Batch batch) {
    batch.execute('''CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      category TEXT,
      description TEXT NOT NULL,
      amount REAL NOT NULL DEFAULT 0,
      reference_id TEXT,
      reference_type TEXT,
      payment_method TEXT DEFAULT 'cash',
      transaction_date INTEGER NOT NULL,
      notes TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      deleted_at INTEGER
    )''');
    batch.execute('CREATE INDEX idx_tx_type ON transactions(type)');
    batch.execute('CREATE INDEX idx_tx_date ON transactions(transaction_date)');
    batch.execute('CREATE INDEX idx_tx_category ON transactions(category)');
  }

  void _createNotificationsTable(Batch batch) {
    batch.execute('''CREATE TABLE notifications (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      type TEXT NOT NULL,
      priority TEXT NOT NULL DEFAULT 'medium',
      reference_id TEXT,
      reference_type TEXT,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      snoozed_until INTEGER,
      alert_stopped INTEGER NOT NULL DEFAULT 0,
      alert_stopped_at INTEGER,
      alert_stopped_by TEXT,
      last_fired_at INTEGER
    )''');
    batch.execute('CREATE INDEX idx_notif_shop ON notifications(shop_id)');
    batch.execute('CREATE INDEX idx_notif_read ON notifications(is_read)');
    batch
        .execute('CREATE INDEX idx_notif_created ON notifications(created_at)');
    batch.execute(
        'CREATE INDEX idx_notif_stopped ON notifications(alert_stopped)');
    batch.execute(
        'CREATE INDEX idx_notif_snoozed ON notifications(snoozed_until)');
  }

  void _createWhatsappTemplatesTable(Batch batch) {
    batch.execute('''CREATE TABLE whatsapp_templates (
      id TEXT PRIMARY KEY,
      key TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      template TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
  }

  void _createWhatsappLogsTable(Batch batch) {
    batch.execute('''CREATE TABLE whatsapp_logs (
      id TEXT PRIMARY KEY,
      customer_id TEXT,
      phone TEXT NOT NULL,
      message TEXT NOT NULL,
      template_key TEXT,
      reference_id TEXT,
      sent_at INTEGER NOT NULL
    )''');
  }

  void _createWhatsappMessagesTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS whatsapp_messages (
      id TEXT PRIMARY KEY,
      maintenance_id TEXT NOT NULL,
      customer_id TEXT,
      customer_name TEXT,
      phone TEXT NOT NULL,
      normalized_phone TEXT,
      message_type TEXT NOT NULL,
      message TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'prepared',
      provider TEXT NOT NULL DEFAULT 'desktop',
      prepared_at INTEGER NOT NULL,
      sent_at INTEGER,
      sent_by TEXT,
      failure_reason TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      edited_at INTEGER,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wmsgs_maintenance ON whatsapp_messages(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wmsgs_type ON whatsapp_messages(message_type)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wmsgs_status ON whatsapp_messages(status)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_wmsgs_prepared ON whatsapp_messages(prepared_at)');
  }

  void _createInvoiceSequenceTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS invoice_sequence (
      shop_id TEXT NOT NULL,
      year INTEGER NOT NULL,
      prefix TEXT NOT NULL,
      next_number INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (shop_id, year, prefix)
    )''');
  }

  void _createInvoicesTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      invoice_number TEXT UNIQUE NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      customer_id TEXT NOT NULL,
      device_id TEXT,
      maintenance_id TEXT NOT NULL,
      customer_name TEXT NOT NULL,
      customer_phone TEXT NOT NULL,
      device_name TEXT NOT NULL,
      imei TEXT,
      serial_number TEXT,
      subtotal REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      tax REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL DEFAULT 0,
      amount_paid REAL NOT NULL DEFAULT 0,
      amount_due REAL NOT NULL DEFAULT 0,
      payment_method TEXT,
      warranty_type TEXT,
      warranty_days INTEGER NOT NULL DEFAULT 0,
      warranty_start INTEGER,
      warranty_end INTEGER,
      warranty_status TEXT NOT NULL DEFAULT 'none',
      warranty_terms_snapshot TEXT,
      center_settings_snapshot TEXT,
      pdf_path TEXT,
      file_name TEXT,
      sent_status TEXT NOT NULL DEFAULT 'not_sent',
      sent_at INTEGER,
      sent_method TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      approved_at INTEGER,
      cancelled_at INTEGER,
      cancel_reason TEXT,
      revision INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id),
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_device ON invoices(device_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_maintenance ON invoices(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_created ON invoices(created_at)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_warranty_end ON invoices(warranty_end)');
  }

  void _createDevicePhotosTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS device_photos (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      customer_id TEXT NOT NULL,
      device_id TEXT,
      maintenance_id TEXT,
      invoice_id TEXT,
      report_id TEXT,
      original_path TEXT NOT NULL,
      thumbnail_path TEXT,
      file_name TEXT NOT NULL,
      file_size INTEGER NOT NULL DEFAULT 0,
      mime_type TEXT,
      stage TEXT NOT NULL DEFAULT 'intake',
      photo_type TEXT NOT NULL DEFAULT 'ملاحظة إضافية',
      caption TEXT,
      captured_by TEXT,
      captured_at INTEGER NOT NULL,
      is_original_retained INTEGER NOT NULL DEFAULT 1,
      is_required INTEGER NOT NULL DEFAULT 0,
      is_approved INTEGER NOT NULL DEFAULT 0,
      deleted_at INTEGER,
      delete_reason TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id),
      FOREIGN KEY (device_id) REFERENCES devices(id),
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dphotos_customer ON device_photos(customer_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dphotos_device ON device_photos(device_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dphotos_maintenance ON device_photos(maintenance_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dphotos_stage ON device_photos(stage)');
  }

  void _createDeviceReportsTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS device_reports (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      report_number TEXT UNIQUE NOT NULL,
      report_type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      customer_id TEXT NOT NULL,
      device_id TEXT,
      maintenance_id TEXT,
      invoice_id TEXT,
      title TEXT NOT NULL,
      pdf_path TEXT,
      file_name TEXT,
      included_photo_ids TEXT,
      center_settings_snapshot TEXT,
      terms_snapshot TEXT,
      sent_status TEXT NOT NULL DEFAULT 'not_sent',
      sent_at INTEGER,
      sent_method TEXT,
      created_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      approved_at INTEGER,
      revision INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id),
      FOREIGN KEY (device_id) REFERENCES devices(id),
      FOREIGN KEY (maintenance_id) REFERENCES maintenance(id)
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dreports_customer ON device_reports(customer_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dreports_device ON device_reports(device_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dreports_maintenance ON device_reports(maintenance_id)');
  }

  void _createDocumentSendLogsTable(Batch batch) {
    batch.execute('''CREATE TABLE IF NOT EXISTS document_send_logs (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      document_type TEXT NOT NULL,
      customer_id TEXT,
      phone TEXT,
      method TEXT NOT NULL,
      file_path TEXT,
      status TEXT NOT NULL,
      error_message TEXT,
      sent_by TEXT,
      sent_at INTEGER NOT NULL
    )''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dsend_document ON document_send_logs(document_id, document_type)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_dsend_customer ON document_send_logs(customer_id)');
  }

  void _createAuditLogTable(Batch batch) {
    batch.execute('''CREATE TABLE audit_log (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      username TEXT,
      action TEXT NOT NULL,
      table_name TEXT,
      record_id TEXT,
      old_value TEXT,
      new_value TEXT,
      created_at INTEGER NOT NULL
    )''');
    batch.execute('CREATE INDEX idx_audit_user ON audit_log(user_id)');
    batch.execute('CREATE INDEX idx_audit_created ON audit_log(created_at)');
  }

  void _createSettingsTable(Batch batch) {
    batch.execute('''CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at INTEGER NOT NULL
    )''');
  }

  void _createTechnicianCustodyTable(Batch batch) {
    batch.execute('''CREATE TABLE technician_custody (
      id TEXT PRIMARY KEY,
      technician_id TEXT NOT NULL,
      product_id TEXT,
      product_name TEXT NOT NULL,
      quantity_received INTEGER NOT NULL DEFAULT 0,
      quantity_used INTEGER NOT NULL DEFAULT 0,
      quantity_returned INTEGER NOT NULL DEFAULT 0,
      maintenance_id TEXT,
      notes TEXT,
      received_at INTEGER NOT NULL,
      returned_at INTEGER,
      created_at INTEGER NOT NULL
    )''');
    batch.execute(
        'CREATE INDEX idx_custody_tech ON technician_custody(technician_id)');
  }

  void _createMediaFilesTable(Batch batch) {
    batch.execute('''CREATE TABLE media_files (
      id TEXT PRIMARY KEY,
      reference_id TEXT NOT NULL,
      reference_type TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_name TEXT NOT NULL,
      file_type TEXT NOT NULL,
      file_size INTEGER,
      caption TEXT,
      created_at INTEGER NOT NULL
    )''');
    batch.execute(
        'CREATE INDEX idx_media_ref ON media_files(reference_id, reference_type)');
  }

  void _createBackupLogsTable(Batch batch) {
    batch.execute('''CREATE TABLE backup_logs (
      id TEXT PRIMARY KEY,
      shop_id TEXT NOT NULL DEFAULT 'default_shop',
      file_path TEXT NOT NULL,
      file_size INTEGER,
      type TEXT NOT NULL DEFAULT 'manual',
      status TEXT NOT NULL DEFAULT 'success',
      notes TEXT,
      created_at INTEGER NOT NULL
    )''');
  }

  void _insertInvoiceAndPhotoDefaultSettings(Batch batch) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = <String, String>{
      'shop_id': 'default_shop',
      'shop_setup_completed': 'false',
      'shop_setup_completed_at': '',
      'trade_name': '',
      'license_number': '',
      'shop_whatsapp': '',
      'map_url': '',
      'tracking_base_url': 'proshop:///track',
      'privacy_policy_url': '',
      'privacy_policy_accepted_version': '',
      'privacy_policy_accepted_at': '',
      'stamp_path': '',
      'signature_path': '',
      'manager_name': '',
      'manager_title': '',
      'invoice_intro_text': 'مرحباً بكم، يسعدنا خدمتكم.',
      'invoice_general_terms': '',
      'invoice_return_policy': '',
      'invoice_legal_notes': '',
      'invoice_copyright':
          'جميع الحقوق محفوظة للمركز، ويعد هذا المستند نسخة رسمية.',
      'invoice_message_template':
          'مرحباً {اسم العميل}،\nتم إصدار فاتورة الصيانة الخاصة بجهازك {نوع الجهاز}.\nرقم الفاتورة: {رقم الفاتورة}\nمدة الضمان: {مدة الضمان}\nتاريخ انتهاء الضمان: {تاريخ انتهاء الضمان}\nنشكركم لثقتكم بـ {اسم المركز}.',
      'invoice_prefix': 'INV',
      'invoice_reset_yearly': 'true',
      'invoice_include_intake_photos': 'true',
      'invoice_show_signature': 'true',
      'photo_required_count': '0',
      'photo_required_types': '',
      'photo_optional_types': AppConstants.defaultDevicePhotoTypes.join('\n'),
      'photo_max_size_mb': '10',
      'photo_quality': '85',
      'photo_compress': 'true',
      'photo_keep_original': 'true',
      'photo_watermark_reports': 'false',
      'photo_report_default_type': 'intake',
      'photo_report_images_per_page': '4',
      'photo_show_employee': 'true',
      'photo_show_datetime': 'true',
      'alert_sounds_enabled': 'true',
      'device_stay_alert_sound_path': '',
      'warranty_alert_sound_path': '',
      'alert_check_interval_minutes': '30',
      'alert_volume': '1.0',
      'alert_vibration_enabled': 'true',
      'alert_repeat_count': '1',
      'whatsapp_message_types_master_enabled': 'true',
    };
    for (final entry in defaults.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  void _insertShopSetupDefaultSettings(Batch batch) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in {
      'shop_setup_completed': 'false',
      'shop_setup_completed_at': '',
    }.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    batch.insert('users', {
      'id': 'user_admin',
      'name': 'مالك النظام',
      'username': 'admin',
      'password_hash': hashPassword('admin123'),
      'role': AppConstants.roleOwner,
      'is_active': 1,
      'failed_attempts': 0,
      'created_at': now,
      'updated_at': now,
    });

    final templates = [
      {
        'id': 'tpl_1',
        'key': AppConstants.waTplReceived,
        'name': 'تم استلام الجهاز',
        'template':
            'السلام عليكم {customer_name}،\nرابط تتبع حالة الجهاز مباشرة بدون إدخال:\n{tracking_url}\nرقم الصيانة: {ticket_number}\nتم استلام جهازك {device} بنجاح.\nسنتواصل معك فور الانتهاء.\nشكراً لثقتك بنا.'
      },
      {
        'id': 'tpl_2',
        'key': AppConstants.waTplInspecting,
        'name': 'جاري الفحص',
        'template':
            'السلام عليكم {customer_name}،\nجهازك {device} قيد الفحص حالياً.\nرقم الصيانة: {ticket_number}\nسنبلغك بالنتيجة قريباً.'
      },
      {
        'id': 'tpl_3',
        'key': AppConstants.waTplWaiting,
        'name': 'بانتظار قطعة',
        'template':
            'السلام عليكم {customer_name}،\nجهازك {device} بانتظار قطعة الغيار.\nرقم الصيانة: {ticket_number}\nسنبلغك فور وصولها.'
      },
      {
        'id': 'tpl_4',
        'key': AppConstants.waTplRepaired,
        'name': 'تم الإصلاح',
        'template':
            'السلام عليكم {customer_name}،\nتم إصلاح جهازك {device} بنجاح.\nرقم الصيانة: {ticket_number}\nيرجى التواصل لتحديد موعد الاستلام.'
      },
      {
        'id': 'tpl_5',
        'key': AppConstants.waTplReady,
        'name': 'جاهز للاستلام',
        'template':
            'السلام عليكم {customer_name}،\nجهازك {device} جاهز للاستلام.\nرقم الصيانة: {ticket_number}\nموعد التسليم: {delivery_date}'
      },
      {
        'id': 'tpl_6',
        'key': AppConstants.waTplWarrantyExpiring,
        'name': 'انتهاء الضمان قريباً',
        'template':
            'السلام عليكم {customer_name}،\nضمان جهازك {device} سينتهي بتاريخ {warranty_end}.\nيرجى التواصل قبل انتهاء الضمان.'
      },
    ];

    for (final t in templates) {
      batch.insert('whatsapp_templates',
          {...t, 'is_active': 1, 'created_at': now, 'updated_at': now});
    }

    final defaultSettings = <String, String>{
      'shop_name': 'محل جوالات ProShop',
      'shop_phone': '',
      'shop_phone2': '',
      'shop_address': '',
      'shop_email': '',
      'commercial_register': '',
      'tax_number': '',
      'tax_rate': '0',
      'currency': 'ر.س',
      'warranty_terms': 'الضمان لا يشمل الكسر والماء والتلف الخارجي',
      'device_receiver_name': '',
      'device_receiver_names': '',
      'invoice_footer': 'شكراً لزيارتكم - نتمنى لكم تجربة ممتازة',
      'logo_path': '',
      'auto_backup': 'true',
      'auto_backup_interval': '3',
      'auto_whatsapp_send': 'false',
      'language': 'ar',
      'theme': 'light',
    };

    for (final entry in defaultSettings.entries) {
      batch.insert('settings',
          {'key': entry.key, 'value': entry.value, 'updated_at': now});
    }
    _insertInvoiceAndPhotoDefaultSettings(batch);

    await batch.commit(noResult: true);
  }

  Future<void> _ensureLocalShopIdentity(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    String? shopId;
    try {
      final rows = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['shop_id'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        shopId = rows.first['value']?.toString().trim();
      }
    } catch (_) {
      return;
    }

    if (shopId != null && shopId.isNotEmpty && shopId != 'default_shop') {
      return;
    }

    final generated =
        'shop_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}';
    await db.insert(
      'settings',
      {'key': 'shop_id', 'value': generated, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final table in [
      'invoice_sequence',
      'invoices',
      'device_photos',
      'device_reports',
      'backup_logs',
      'notifications',
      'warranty_actions',
    ]) {
      try {
        await db.update(
          table,
          {'shop_id': generated},
          where: "shop_id IS NULL OR shop_id = '' OR shop_id = ?",
          whereArgs: ['default_shop'],
        );
      } catch (_) {
        // Some older databases may not have every shop-scoped table yet.
      }
    }
    try {
      await db.rawUpdate(
        "UPDATE device_photos "
        "SET original_path = REPLACE(REPLACE(original_path, 'DevicePhotos/default_shop', ?), 'DevicePhotos\\default_shop', ?), "
        "thumbnail_path = CASE WHEN thumbnail_path IS NULL THEN NULL ELSE REPLACE(REPLACE(thumbnail_path, 'DevicePhotos/default_shop', ?), 'DevicePhotos\\default_shop', ?) END",
        [
          'DevicePhotos/$generated',
          'DevicePhotos\\$generated',
          'DevicePhotos/$generated',
          'DevicePhotos\\$generated',
        ],
      );
    } catch (_) {}
    await _migrateDefaultShopDirectories(db, generated);
  }

  Future<void> _ensureShopScopedCoreTables(Database db) async {
    for (final table in [
      'customers',
      'devices',
      'maintenance',
      'warranties',
      'warranty_claims',
    ]) {
      try {
        await db.execute(
          "ALTER TABLE $table ADD COLUMN shop_id TEXT NOT NULL DEFAULT 'default_shop'",
        );
      } catch (_) {
        // Column may already exist on development databases.
      }
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_${table}_shop ON $table(shop_id)',
        );
      } catch (_) {}
    }

    await _ensureLocalShopIdentity(db);
    final shopId = await _readSettingFromDb(db, 'shop_id') ?? 'default_shop';
    final setupAt = int.tryParse(
            await _readSettingFromDb(db, 'shop_setup_completed_at') ?? '') ??
        0;
    const legacyShopId = 'legacy_shop';

    for (final table in ['customers', 'devices', 'maintenance', 'warranties']) {
      try {
        if (setupAt > 0) {
          await db.rawUpdate(
            "UPDATE $table SET shop_id = ? "
            "WHERE (shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop') "
            "AND created_at >= ?",
            [shopId, setupAt],
          );
        }
        await db.rawUpdate(
          "UPDATE $table SET shop_id = ? "
          "WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
          [setupAt > 0 ? legacyShopId : shopId],
        );
      } catch (_) {}
    }

    try {
      await db.rawUpdate(
        "UPDATE warranty_claims SET shop_id = ("
        "SELECT shop_id FROM warranties WHERE warranties.id = warranty_claims.warranty_id"
        ") WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
      );
      await db.rawUpdate(
        "UPDATE warranty_claims SET shop_id = ? "
        "WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
        [setupAt > 0 ? legacyShopId : shopId],
      );
    } catch (_) {}
  }

  Future<void> _ensureWarrantyManagementSchema(Database db) async {
    for (final column in const [
      "alert_disabled INTEGER NOT NULL DEFAULT 0",
      "alert_disabled_reason TEXT",
      "alert_disabled_at INTEGER",
      "alert_disabled_by TEXT",
      "expiry_approved INTEGER NOT NULL DEFAULT 0",
      "expiry_approved_at INTEGER",
      "expiry_approved_by TEXT",
    ]) {
      try {
        await db.execute('ALTER TABLE warranties ADD COLUMN $column');
      } catch (_) {
        // Column may already exist on development databases.
      }
    }

    final batch = db.batch();
    _createWarrantyActionsTable(batch);
    await batch.commit(noResult: true);

    await _ensureLocalShopIdentity(db);
    final shopId = await _readSettingFromDb(db, 'shop_id') ?? 'default_shop';
    try {
      await db.rawUpdate(
        "UPDATE warranty_actions SET shop_id = ("
        "SELECT shop_id FROM warranties WHERE warranties.id = warranty_actions.warranty_id"
        ") WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
      );
      await db.rawUpdate(
        "UPDATE warranty_actions SET shop_id = ? "
        "WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
        [shopId],
      );
    } catch (_) {}
  }

  static const _wamsgTemplateKeyPrefix = 'wamsg_';

  Future<void> _ensureAlertRecurrenceSchema(Database db) async {
    for (final column in const [
      'snoozed_until INTEGER',
      'alert_stopped INTEGER NOT NULL DEFAULT 0',
      'alert_stopped_at INTEGER',
      'alert_stopped_by TEXT',
      'last_fired_at INTEGER',
    ]) {
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN $column');
      } catch (_) {
        // Column may already exist on development databases.
      }
    }
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notif_stopped ON notifications(alert_stopped)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notif_snoozed ON notifications(snoozed_until)',
      );
    } catch (_) {}

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final entry in <String, String>{
      'alert_check_interval_minutes': '30',
      'alert_volume': '1.0',
      'alert_vibration_enabled': 'true',
      'alert_repeat_count': '1',
      'whatsapp_message_types_master_enabled': 'true',
    }.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Seeds one inactive-by-default-text `whatsapp_templates` row per
  /// automatic maintenance-workflow message type (`wamsg_*` keys, distinct
  /// from the manual-composer's `waTpl*` keys which reuse some of the same
  /// raw strings, e.g. both have a 'ready' type). `template` is left empty
  /// on purpose: `WhatsappRepository._buildMessage` only overrides its
  /// existing hardcoded wording when a row's `template` is non-empty, so
  /// seeding empty rows changes nothing until a shop owner writes their own
  /// text in the new WhatsApp message settings page. `is_active` defaults to
  /// 1 (message type enabled), matching today's behavior of every automatic
  /// message being sent.
  Future<void> _ensureWhatsappMessageTemplateSeeds(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final type in AppConstants.whatsappMessageTypeLabels.keys) {
      batch.insert(
        'whatsapp_templates',
        {
          'id': 'tpl_$_wamsgTemplateKeyPrefix$type',
          'key': '$_wamsgTemplateKeyPrefix$type',
          'name': AppConstants.whatsappMessageTypeLabels[type]!,
          'template': '',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureNotificationShopScope(Database db) async {
    try {
      await db.execute(
        "ALTER TABLE notifications ADD COLUMN shop_id TEXT NOT NULL DEFAULT 'default_shop'",
      );
    } catch (_) {
      // Column may already exist on development databases.
    }
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notif_shop ON notifications(shop_id)',
      );
    } catch (_) {}

    await _ensureLocalShopIdentity(db);
    final shopId = await _readSettingFromDb(db, 'shop_id') ?? 'default_shop';
    final setupAt = int.tryParse(
            await _readSettingFromDb(db, 'shop_setup_completed_at') ?? '') ??
        0;
    const legacyShopId = 'legacy_shop';

    for (final entry in const [
      ['maintenance', 'maintenance'],
      ['warranty', 'warranties'],
      ['customer', 'customers'],
      ['device', 'devices'],
    ]) {
      final referenceType = entry[0];
      final table = entry[1];
      try {
        await db.rawUpdate(
          "UPDATE notifications SET shop_id = ("
          "SELECT shop_id FROM $table WHERE $table.id = notifications.reference_id"
          ") WHERE (shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop') "
          "AND reference_type = ? "
          "AND EXISTS (SELECT 1 FROM $table WHERE $table.id = notifications.reference_id)",
          [referenceType],
        );
      } catch (_) {}
    }

    try {
      if (setupAt > 0) {
        await db.rawUpdate(
          "UPDATE notifications SET shop_id = ? "
          "WHERE (shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop') "
          "AND created_at >= ?",
          [shopId, setupAt],
        );
      }
      await db.rawUpdate(
        "UPDATE notifications SET shop_id = ? "
        "WHERE shop_id IS NULL OR shop_id = '' OR shop_id = 'default_shop'",
        [setupAt > 0 ? legacyShopId : shopId],
      );
    } catch (_) {}
  }

  Future<String?> _readSettingFromDb(Database db, String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> _migrateDefaultShopDirectories(
    Database db,
    String shopId,
  ) async {
    try {
      if (db.path.isEmpty) return;
      final appDir = Directory(p.dirname(p.dirname(db.path)));
      for (final parts in [
        ['Images', 'DevicePhotos'],
        ['Invoices'],
        ['Reports'],
        ['Backups'],
      ]) {
        final root = p.joinAll([appDir.path, ...parts]);
        final source = Directory(p.join(root, 'default_shop'));
        if (!source.existsSync()) continue;
        final target = Directory(p.join(root, shopId));
        _mergeDirectorySync(source, target);
        try {
          source.deleteSync(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _mergeDirectorySync(Directory source, Directory target) {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    for (final entity in source.listSync()) {
      final destination = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        _mergeDirectorySync(entity, Directory(destination));
        try {
          entity.deleteSync(recursive: true);
        } catch (_) {}
      } else if (entity is File) {
        final safeDestination = _uniqueFilePath(destination);
        try {
          entity.renameSync(safeDestination);
        } catch (_) {
          entity.copySync(safeDestination);
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  String _uniqueFilePath(String filePath) {
    if (!File(filePath).existsSync()) return filePath;
    final dir = p.dirname(filePath);
    final name = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath);
    var i = 1;
    while (true) {
      final candidate = p.join(dir, '${name}_$i$ext');
      if (!File(candidate).existsSync()) return candidate;
      i++;
    }
  }

  Future<void> _backupBeforeUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    try {
      final path = db.path;
      if (path.isEmpty) return;
      final source = File(path);
      if (!source.existsSync()) return;
      final appDir = Directory(p.dirname(p.dirname(path)));
      final backupDir = Directory(p.join(appDir.path, 'Backups'));
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final baseName = p.basename(path);
      final backupBase = p.join(backupDir.path,
          '${baseName}_v${oldVersion}_to_v${newVersion}_$stamp');
      await source.copy('$backupBase.bak');
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$path$suffix');
        if (sidecar.existsSync()) {
          await sidecar.copy('$backupBase$suffix.bak');
        }
      }
    } catch (_) {
      // Schema upgrades should not fail only because a defensive backup failed.
    }
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode('${password}mobile_shop_salt_2024');
    return sha256.convert(bytes).toString();
  }

  Future<String?> insert(String table, Map<String, dynamic> data) async {
    final database = await db;
    await database.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return data['id'] as String?;
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final database = await db;
    return await database.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> softDelete(String table, String id) async {
    final database = await db;
    return await database.update(
      table,
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    List<String>? columns,
  }) async {
    final database = await db;
    return await database.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? args]) async {
    final database = await db;
    return await database.rawQuery(sql, args);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async {
    final database = await db;
    return await database.rawUpdate(sql, args);
  }

  Future<int> rawDelete(String sql, [List<dynamic>? args]) async {
    final database = await db;
    return await database.rawDelete(sql, args);
  }

  Future<Map<String, dynamic>?> queryOne(String table, String id) async {
    final database = await db;
    final results = await database.query(
      table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<String?> getSetting(String key) async {
    final database = await db;
    final result = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<String> getCurrentShopId() async {
    final database = await db;
    await _ensureLocalShopIdentity(database);
    final result = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['shop_id'],
      limit: 1,
    );
    final value = result.isNotEmpty ? result.first['value']?.toString() : null;
    return (value == null || value.trim().isEmpty) ? 'default_shop' : value;
  }

  Future<Directory> getShopDirectory(String name) async {
    final appDir = await getDataDirectory();
    final shopId = await getCurrentShopId();
    final directory = Directory(p.join(appDir.path, name, shopId));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final database = await db;
    final results = await database.query('settings');
    return {
      for (var r in results) r['key'] as String: (r['value'] ?? '') as String
    };
  }

  Future<Directory> getDataDirectory() async {
    final Directory appDir;
    if (AppPlatform.isDesktop) {
      appDir = Directory(p.dirname(Platform.resolvedExecutable));
    } else {
      appDir = await getApplicationSupportDirectory();
    }

    for (final name in [
      'Database',
      'Images',
      'Invoices',
      'Reports',
      'Backups',
      'Logs',
      'Settings',
      'Media',
    ]) {
      final directory = Directory(p.join(appDir.path, name));
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
    }

    return appDir;
  }

  Future<String> getDatabasePath() async {
    final appDir = await getDataDirectory();
    return p.join(appDir.path, 'Database', AppConstants.dbName);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
