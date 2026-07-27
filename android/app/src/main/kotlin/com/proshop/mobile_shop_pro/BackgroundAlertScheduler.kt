package com.proshop.mobile_shop_pro

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlin.math.roundToInt

internal data class StoredBackgroundAlert(
    val id: String,
    val type: String,
    val title: String,
    val message: String,
    val priority: String,
    val createdAt: Long,
    val snoozedUntil: Long?,
    val lastFiredAt: Long?,
)

/**
 * Android-owned alert engine.
 *
 * It deliberately uses the application's existing SQLite database instead of
 * maintaining a second source of truth. AlarmManager can start
 * [AlertAlarmReceiver] after the Flutter process has been removed, while all
 * snooze/read/stop decisions made in Flutter remain authoritative.
 */
object BackgroundAlertScheduler {
    private const val DATABASE_DIRECTORY = "Database"
    private const val DATABASE_NAME = "mobile_shop_pro.db"
    private const val LEGACY_CHANNEL_ID = "proshop_background_alerts_v1"
    private const val MAINTENANCE_CHANNEL_ID = "proshop_maintenance_alerts_v2"
    private const val WARRANTY_CHANNEL_ID = "proshop_warranty_alerts_v2"
    private const val SILENT_CHANNEL_ID = "proshop_other_alerts_v1"
    private const val NOTIFICATION_ID = 7301
    private const val ALARM_REQUEST_CODE = 7302
    private const val PREFS_NAME = "proshop_background_alert_state"
    private const val PREF_APP_VISIBLE = "app_visible"
    private const val DEFAULT_INTERVAL_MINUTES = 30L
    private const val MIN_INTERVAL_MINUTES = 1L
    private const val FOREGROUND_RECHECK_MS = 5L * 60L * 1000L
    private const val PERMISSION_RECHECK_MS = 15L * 60L * 1000L
    private const val MIN_ALARM_DELAY_MS = 3_000L
    private const val DAY_MS = 24L * 60L * 60L * 1000L

    fun initialize(context: Context) {
        ensureNotificationChannel(context)
        scheduleNext(context)
    }

    fun setAppVisible(context: Context, visible: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_APP_VISIBLE, visible)
            .apply()
        if (!visible) {
            scheduleNext(context)
        }
    }

    fun isAppVisible(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(PREF_APP_VISIBLE, false)
    }

    fun handleAlarm(context: Context) {
        ensureNotificationChannel(context)
        if (isAppVisible(context)) {
            scheduleAt(context, System.currentTimeMillis() + FOREGROUND_RECHECK_MS)
            return
        }

        val database = openDatabase(context)
        if (database == null) {
            scheduleAt(context, System.currentTimeMillis() + PERMISSION_RECHECK_MS)
            return
        }

        try {
            val now = System.currentTimeMillis()
            generateSmartAlerts(database, now)

            if (!canPostNotifications(context)) {
                scheduleAt(context, now + PERMISSION_RECHECK_MS)
                return
            }

            val intervalMs = readIntervalMillis(database)
            val due = loadDueAlerts(database, now, intervalMs)
            if (due.isNotEmpty()) {
                showSystemNotification(context, due, now)
                markFired(database, due.map { it.id }, now)
            }
        } catch (_: Exception) {
            // A locked or migrating database is retried by the next alarm.
        } finally {
            database.close()
        }

        scheduleNext(context)
    }

    fun showVerificationNotification(context: Context) {
        ensureNotificationChannel(context)
        if (!canPostNotifications(context)) return
        val now = System.currentTimeMillis()
        showSystemNotification(
            context,
            listOf(
                StoredBackgroundAlert(
                    id = "background-verification",
                    type = "maintenance_overdue_verification",
                    title = "تنبيهات ProShop تعمل خارج التطبيق",
                    message =
                        "تم تشغيل هذا الإشعار من Android والتطبيق مغلق. " +
                            "ستظهر تنبيهات الصيانة والضمان بالطريقة نفسها.",
                    priority = "high",
                    createdAt = now,
                    snoozedUntil = null,
                    lastFiredAt = null,
                ),
            ),
            now,
        )
        scheduleNext(context)
    }

    fun scheduleNext(context: Context) {
        if (isAppVisible(context)) {
            scheduleAt(context, System.currentTimeMillis() + FOREGROUND_RECHECK_MS)
            return
        }

        val now = System.currentTimeMillis()
        val database = openDatabase(context)
        if (database == null) {
            scheduleAt(context, now + PERMISSION_RECHECK_MS)
            return
        }

        val triggerAt = try {
            val intervalMs = readIntervalMillis(database)
            var earliest = now + intervalMs
            val shopId = readCurrentShopId(database)
            database.rawQuery(
                """
                SELECT created_at, snoozed_until, last_fired_at
                FROM notifications
                WHERE shop_id = ?
                  AND is_read = 0
                  AND alert_stopped = 0
                """.trimIndent(),
                arrayOf(shopId),
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val createdAt = cursor.longOrNull("created_at") ?: now
                    val snoozedUntil = cursor.longOrNull("snoozed_until")
                    val lastFiredAt = cursor.longOrNull("last_fired_at")
                    var dueAt = lastFiredAt?.plus(intervalMs) ?: createdAt
                    if (snoozedUntil != null) {
                        dueAt = max(dueAt, snoozedUntil)
                    }
                    earliest = minOf(earliest, dueAt)
                }
            }
            max(now + MIN_ALARM_DELAY_MS, earliest)
        } catch (_: Exception) {
            now + PERMISSION_RECHECK_MS
        } finally {
            database.close()
        }

        scheduleAt(context, triggerAt)
    }

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val maintenanceSound = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.proshop_maintenance_alert}",
        )
        val warrantySound = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.proshop_warranty_alert}",
        )

        manager.createNotificationChannel(
            NotificationChannel(
                MAINTENANCE_CHANNEL_ID,
                "تنبيهات الصيانة المتأخرة",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "الصوت 1 لتنبيه بقاء الجوال والصيانة المتأخرة"
                setSound(maintenanceSound, audioAttributes)
                enableVibration(true)
                setShowBadge(true)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                WARRANTY_CHANNEL_ID,
                "تنبيهات الضمان",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "الصوت 2 للضمان المنتهي أو القريب من الانتهاء"
                setSound(warrantySound, audioAttributes)
                enableVibration(true)
                setShowBadge(true)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                SILENT_CHANNEL_ID,
                "تنبيهات أخرى",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "تنبيهات التطبيق الأخرى دون استخدام صوتي الصيانة والضمان"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(true)
            },
        )
    }

    private fun scheduleAt(context: Context, triggerAt: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlertAlarmReceiver::class.java).apply {
            action = AlertAlarmReceiver.ACTION_CHECK_BACKGROUND_ALERTS
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    alarmManager.canScheduleExactAlarms() -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
                else -> {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
            }
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }

    private fun openDatabase(context: Context): SQLiteDatabase? {
        val file = File(
            File(context.filesDir, DATABASE_DIRECTORY),
            DATABASE_NAME,
        )
        if (!file.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(
                file.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun readCurrentShopId(database: SQLiteDatabase): String {
        return database.rawQuery(
            "SELECT value FROM settings WHERE key = 'shop_id' LIMIT 1",
            null,
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(0)?.trim().takeUnless { it.isNullOrEmpty() }
                    ?: "default_shop"
            } else {
                "default_shop"
            }
        }
    }

    private fun readIntervalMillis(database: SQLiteDatabase): Long {
        val minutes = database.rawQuery(
            "SELECT value FROM settings WHERE key = 'alert_check_interval_minutes' LIMIT 1",
            null,
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(0)?.toLongOrNull() ?: DEFAULT_INTERVAL_MINUTES
            } else {
                DEFAULT_INTERVAL_MINUTES
            }
        }.coerceAtLeast(MIN_INTERVAL_MINUTES)
        return minutes * 60L * 1000L
    }

    private fun loadDueAlerts(
        database: SQLiteDatabase,
        now: Long,
        intervalMs: Long,
    ): List<StoredBackgroundAlert> {
        val shopId = readCurrentShopId(database)
        return database.rawQuery(
            """
            SELECT id, type, title, message, priority, created_at,
                   snoozed_until, last_fired_at
            FROM notifications
            WHERE shop_id = ?
              AND is_read = 0
              AND alert_stopped = 0
              AND (snoozed_until IS NULL OR snoozed_until <= ?)
              AND (last_fired_at IS NULL OR last_fired_at <= ?)
            ORDER BY created_at ASC
            """.trimIndent(),
            arrayOf(shopId, now.toString(), (now - intervalMs).toString()),
        ).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        StoredBackgroundAlert(
                            id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
                            type = cursor.getString(cursor.getColumnIndexOrThrow("type")),
                            title = cursor.getString(cursor.getColumnIndexOrThrow("title")),
                            message = cursor.getString(cursor.getColumnIndexOrThrow("message")),
                            priority =
                                cursor.getString(cursor.getColumnIndexOrThrow("priority")),
                            createdAt =
                                cursor.getLong(cursor.getColumnIndexOrThrow("created_at")),
                            snoozedUntil = cursor.longOrNull("snoozed_until"),
                            lastFiredAt = cursor.longOrNull("last_fired_at"),
                        ),
                    )
                }
            }
        }
    }

    private fun showSystemNotification(
        context: Context,
        alerts: List<StoredBackgroundAlert>,
        now: Long,
    ) {
        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
        launchIntent.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_notifications", true)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val critical = alerts.any { it.priority == "critical" }
        val title = if (alerts.size == 1) {
            alerts.first().title
        } else {
            "${alerts.size} تنبيهات تحتاج مراجعة"
        }
        val message = if (alerts.size == 1) {
            alerts.first().message
        } else {
            "افتح التطبيق لإدارة التنبيهات أو تأجيلها أو إيقافها."
        }
        val channelId = channelIdFor(alerts)
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_proshop)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(
                if (alerts.size == 1) {
                    NotificationCompat.BigTextStyle().bigText(message)
                } else {
                    NotificationCompat.InboxStyle().also { style ->
                        alerts.take(6).forEach { style.addLine(it.title) }
                        if (alerts.size > 6) {
                            style.addLine("و${alerts.size - 6} تنبيهات أخرى")
                        }
                        style.setSummaryText("ProShop")
                    }
                },
            )
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(
                if (critical) {
                    NotificationCompat.PRIORITY_MAX
                } else {
                    NotificationCompat.PRIORITY_HIGH
                },
            )
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setNumber(alerts.size)
            .setWhen(now)
            .setShowWhen(true)
            .setOnlyAlertOnce(false)

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
    }

    private fun channelIdFor(alerts: List<StoredBackgroundAlert>): String {
        if (
            alerts.any {
                it.type == "device_stay_two_days" ||
                    it.type.startsWith("maintenance_overdue")
            }
        ) {
            return MAINTENANCE_CHANNEL_ID
        }
        if (alerts.any { it.type.startsWith("warranty_") }) {
            return WARRANTY_CHANNEL_ID
        }
        return SILENT_CHANNEL_ID
    }

    private fun markFired(
        database: SQLiteDatabase,
        ids: List<String>,
        now: Long,
    ) {
        if (ids.isEmpty()) return
        database.beginTransaction()
        try {
            val values = ContentValues().apply {
                put("last_fired_at", now)
            }
            ids.forEach { id ->
                database.update(
                    "notifications",
                    values,
                    "id = ?",
                    arrayOf(id),
                )
            }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
    }

    /**
     * Mirrors the time-based smart checks used by the Flutter repository so
     * events that become due while the app stays closed are still written to
     * the normal notifications table and remain manageable when it reopens.
     */
    private fun generateSmartAlerts(database: SQLiteDatabase, now: Long) {
        val shopId = readCurrentShopId(database)
        database.beginTransaction()
        try {
            generateMaintenanceAlerts(database, shopId, now)
            generateWarrantyAlerts(database, shopId, now)
            generateStockAlerts(database, shopId, now)
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
    }

    private fun generateMaintenanceAlerts(
        database: SQLiteDatabase,
        shopId: String,
        now: Long,
    ) {
        val dailyKey = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date(now))
        database.rawQuery(
            """
            SELECT m.id, m.ticket_number, m.brand, m.model, m.received_at,
                   m.estimated_delivery, c.name AS customer_name
            FROM maintenance m
            LEFT JOIN customers c
              ON m.customer_id = c.id AND c.shop_id = m.shop_id
            WHERE m.shop_id = ?
              AND m.estimated_delivery IS NOT NULL
              AND m.estimated_delivery < ?
              AND m.status NOT IN ('delivered', 'cancelled', 'unrepairable', 'abandoned')
              AND m.deleted_at IS NULL
            """.trimIndent(),
            arrayOf(shopId, now.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.stringOrEmpty("id")
                val ticket = cursor.stringOrEmpty("ticket_number")
                val brand = cursor.stringOrEmpty("brand")
                val model = cursor.stringOrEmpty("model")
                val customer = cursor.stringOrEmpty("customer_name").ifBlank { "العميل" }
                val receivedAt = cursor.longOrNull("received_at") ?: now
                val expectedAt = cursor.longOrNull("estimated_delivery") ?: now
                val daysInShop = max(0, ((now - receivedAt) / DAY_MS).toInt())
                val overdueDays = max(1, ((now - expectedAt) / DAY_MS).toInt() + 1)
                addIfNew(
                    database = database,
                    shopId = shopId,
                    referenceId = id,
                    referenceType = "maintenance",
                    type = "maintenance_overdue_$dailyKey",
                    priority = "critical",
                    title = "تجاوز مدة الصيانة المتوقعة",
                    message =
                        "الجهاز $brand $model للعميل $customer تجاوز الموعد المتوقع " +
                            "منذ $overdueDays يوم (موجود بالمركز منذ $daysInShop يوم). " +
                            "رقم الصيانة: $ticket.",
                    now = now,
                )
            }
        }
    }

    private fun generateWarrantyAlerts(
        database: SQLiteDatabase,
        shopId: String,
        now: Long,
    ) {
        val today = startOfDay(now)
        val threshold = Calendar.getInstance().apply {
            timeInMillis = today
            add(Calendar.DAY_OF_YEAR, 3)
        }.timeInMillis
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        database.rawQuery(
            """
            SELECT w.id, w.device_info, w.end_date, c.name AS customer_name
            FROM warranties w
            LEFT JOIN customers c
              ON w.customer_id = c.id AND c.shop_id = w.shop_id
            WHERE w.shop_id = ?
              AND w.end_date < ?
              AND w.is_void = 0
              AND COALESCE(w.alert_disabled, 0) = 0
              AND COALESCE(w.expiry_approved, 0) = 0
            """.trimIndent(),
            arrayOf(shopId, threshold.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.stringOrEmpty("id")
                val device = cursor.stringOrEmpty("device_info").ifBlank { "الجهاز" }
                val customer = cursor.stringOrEmpty("customer_name").ifBlank { "العميل" }
                val endDate = cursor.longOrNull("end_date") ?: now
                val daysLeft = calendarDaysBetween(today, startOfDay(endDate))
                val type = when {
                    daysLeft == 2 -> "warranty_expiring_two_days"
                    daysLeft == 1 -> "warranty_expiring_tomorrow"
                    daysLeft == 0 -> "warranty_expiring_today"
                    daysLeft < -3 -> "warranty_overdue_action"
                    daysLeft < 0 -> "warranty_expired"
                    else -> "warranty_expiring"
                }
                val title = when (type) {
                    "warranty_expiring_two_days" -> "ضمان سينتهي بعد يومين"
                    "warranty_expiring_tomorrow" -> "ضمان سينتهي غدًا"
                    "warranty_expiring_today" -> "ضمان ينتهي اليوم"
                    "warranty_overdue_action" -> "ضمان متأخر في اتخاذ الإجراء"
                    "warranty_expired" -> "ضمان منتهٍ"
                    else -> "ضمان ينتهي قريبًا"
                }
                addIfNew(
                    database = database,
                    shopId = shopId,
                    referenceId = id,
                    referenceType = "warranty",
                    type = type,
                    priority = if (daysLeft < 0) "critical" else "high",
                    title = title,
                    message =
                        "ضمان $device للعميل $customer ينتهي بتاريخ " +
                            "${dateFormat.format(Date(endDate))}.",
                    now = now,
                )
            }
        }
    }

    private fun generateStockAlerts(
        database: SQLiteDatabase,
        shopId: String,
        now: Long,
    ) {
        database.rawQuery(
            """
            SELECT id, name, quantity, low_stock_threshold
            FROM products
            WHERE quantity > 0
              AND quantity <= low_stock_threshold
              AND is_service = 0
              AND is_active = 1
              AND deleted_at IS NULL
            """.trimIndent(),
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.stringOrEmpty("id")
                val name = cursor.stringOrEmpty("name").ifBlank { "منتج" }
                val quantity = cursor.getInt(cursor.getColumnIndexOrThrow("quantity"))
                val threshold =
                    cursor.getInt(cursor.getColumnIndexOrThrow("low_stock_threshold"))
                addIfNew(
                    database,
                    shopId,
                    id,
                    "product",
                    "low_stock",
                    "medium",
                    "مخزون منخفض",
                    "الكمية المتبقية من \"$name\" هي $quantity (الحد الأدنى: $threshold).",
                    now,
                )
            }
        }

        database.rawQuery(
            """
            SELECT id, name
            FROM products
            WHERE quantity <= 0
              AND is_service = 0
              AND is_active = 1
              AND deleted_at IS NULL
            """.trimIndent(),
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.stringOrEmpty("id")
                val name = cursor.stringOrEmpty("name").ifBlank { "منتج" }
                addIfNew(
                    database,
                    shopId,
                    id,
                    "product",
                    "out_of_stock",
                    "high",
                    "نفاد المخزون",
                    "المنتج \"$name\" نفد من المخزون.",
                    now,
                )
            }
        }
    }

    private fun addIfNew(
        database: SQLiteDatabase,
        shopId: String,
        referenceId: String,
        referenceType: String,
        type: String,
        priority: String,
        title: String,
        message: String,
        now: Long,
    ) {
        if (referenceId.isBlank()) return
        val exists = database.rawQuery(
            """
            SELECT 1 FROM notifications
            WHERE shop_id = ? AND reference_id = ? AND type = ?
            LIMIT 1
            """.trimIndent(),
            arrayOf(shopId, referenceId, type),
        ).use { it.moveToFirst() }
        if (exists) return

        val values = ContentValues().apply {
            put("id", UUID.randomUUID().toString())
            put("shop_id", shopId)
            put("title", title)
            put("message", message)
            put("type", type)
            put("priority", priority)
            put("reference_id", referenceId)
            put("reference_type", referenceType)
            put("is_read", 0)
            put("created_at", now)
            put("alert_stopped", 0)
        }
        database.insert("notifications", null, values)
    }

    private fun startOfDay(epochMs: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = epochMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun calendarDaysBetween(startDay: Long, targetDay: Long): Int {
        return ((targetDay - startDay).toDouble() / DAY_MS.toDouble()).roundToInt()
    }

    private fun Cursor.longOrNull(column: String): Long? {
        val index = getColumnIndexOrThrow(column)
        return if (isNull(index)) null else getLong(index)
    }

    private fun Cursor.stringOrEmpty(column: String): String {
        val index = getColumnIndexOrThrow(column)
        return if (isNull(index)) "" else getString(index).orEmpty()
    }
}
