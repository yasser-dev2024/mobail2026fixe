package com.proshop.mobile_shop_pro

import android.Manifest
import android.app.AlarmManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private var backgroundAlertsChannel: MethodChannel? = null

    override fun onStart() {
        super.onStart()
        AlertRingingService.stopAlert(applicationContext)
        BackgroundAlertScheduler.setAppVisible(applicationContext, true)
    }

    override fun onStop() {
        BackgroundAlertScheduler.setAppVisible(applicationContext, false)
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sharePdfToWhatsApp" -> {
                    val filePath = call.argument<String>("filePath").orEmpty()
                    val phone = call.argument<String>("phone").orEmpty()
                    val message = call.argument<String>("message").orEmpty()
                    result.success(sharePdfToWhatsApp(filePath, phone, message))
                }
                "savePdfToDownloads" -> {
                    val filePath = call.argument<String>("filePath").orEmpty()
                    val fileName = call.argument<String>("fileName").orEmpty()
                    result.success(savePdfToDownloads(filePath, fileName))
                }
                else -> result.notImplemented()
            }
        }
        backgroundAlertsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_ALERTS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    BackgroundAlertScheduler.initialize(applicationContext)
                    result.success(consumeOpenNotificationsIntent(intent))
                }
                "takeInitialAlertRoute" -> {
                    result.success(consumeOpenAlertRouteIntent(intent))
                }
                "reschedule" -> {
                    BackgroundAlertScheduler.scheduleNext(applicationContext)
                    result.success(null)
                }
                "permissionStatus" -> {
                    result.success(backgroundPermissionStatus())
                }
                "openExactAlarmSettings" -> {
                    result.success(openExactAlarmSettings())
                }
                "openAutoStartSettings" -> {
                    result.success(openAutoStartSettings())
                }
                "requestBatteryOptimizationExemption" -> {
                    result.success(requestBatteryOptimizationExemption())
                }
                else -> result.notImplemented()
            }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val alertRoute = consumeOpenAlertRouteIntent(intent)
        if (alertRoute != null) {
            backgroundAlertsChannel?.invokeMethod("openAlertRoute", alertRoute)
        } else if (consumeOpenNotificationsIntent(intent)) {
            backgroundAlertsChannel?.invokeMethod("openNotifications", null)
        }
    }

    private fun consumeOpenAlertRouteIntent(source: Intent?): String? {
        val route = source?.getStringExtra(EXTRA_OPEN_ALERT_ROUTE)?.trim()
        source?.removeExtra(EXTRA_OPEN_ALERT_ROUTE)
        return route?.takeIf(::isAllowedAlertRoute)
    }

    private fun isAllowedAlertRoute(route: String): Boolean {
        if (route == "/warranty") return true
        return ALERT_DETAIL_ROUTE.matches(route)
    }

    private fun consumeOpenNotificationsIntent(source: Intent?): Boolean {
        if (source?.getBooleanExtra("open_notifications", false) != true) {
            return false
        }
        source.removeExtra("open_notifications")
        return true
    }

    private fun backgroundPermissionStatus(): Map<String, Boolean> {
        val notificationsGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        val exactAlarmsGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        val batteryOptimizationIgnored =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                powerManager.isIgnoringBatteryOptimizations(packageName)
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val requiresAutoStart =
            manufacturer.contains("xiaomi") ||
                brand.contains("xiaomi") ||
                brand.contains("redmi") ||
                brand.contains("poco")
        return mapOf(
            "notificationsGranted" to notificationsGranted,
            "exactAlarmsGranted" to exactAlarmsGranted,
            "batteryOptimizationIgnored" to batteryOptimizationIgnored,
            "requiresAutoStart" to requiresAutoStart,
        )
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        if (alarmManager.canScheduleExactAlarms()) return true
        return launchSettingsIntent(
            Intent(
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            Intent("miui.intent.action.OP_AUTO_START"),
            Intent().setComponent(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            ),
            Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                setPackage("com.miui.securitycenter")
                putExtra("extra_pkgname", packageName)
            },
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
        return candidates.any { launchSettingsIntent(it) }
    }

    private fun requestBatteryOptimizationExemption(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) return true
        return launchSettingsIntent(
            Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun launchSettingsIntent(settingsIntent: Intent): Boolean {
        return try {
            if (settingsIntent.resolveActivity(packageManager) == null) {
                false
            } else {
                startActivity(settingsIntent)
                true
            }
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun sharePdfToWhatsApp(filePath: String, phone: String, message: String): Boolean {
        val file = File(filePath)
        if (!file.exists() || !file.isFile || file.length() == 0L) return false
        val hasPdfHeader = FileInputStream(file).use { input ->
            val header = ByteArray(5)
            input.read(header) == header.size &&
                header.contentEquals("%PDF-".toByteArray(Charsets.US_ASCII))
        }
        if (!hasPdfHeader) return false

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val baseIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, message)
            putExtra(Intent.EXTRA_TITLE, file.name)
            clipData = ClipData.newRawUri("invoice_pdf", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val whatsappPackage = listOf("com.whatsapp", "com.whatsapp.w4b")
            .firstOrNull { packageName -> isPackageInstalled(packageName) }

        if (whatsappPackage != null) {
            baseIntent.setPackage(whatsappPackage)
            val digits = phone.filter { it in '0'..'9' }
            if (digits.isNotEmpty()) {
                baseIntent.putExtra("jid", "$digits@s.whatsapp.net")
            }
            grantUriPermission(whatsappPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (whatsappPackage == null) {
            return try {
                startActivity(Intent.createChooser(baseIntent, "Share PDF"))
                true
            } catch (_: ActivityNotFoundException) {
                false
            } catch (_: SecurityException) {
                false
            }
        }

        val pdfShareHandler = packageManager.resolveActivity(
            baseIntent,
            PackageManager.MATCH_DEFAULT_ONLY,
        ) ?: return false
        if (pdfShareHandler.activityInfo.packageName != whatsappPackage) return false

        return try {
            // Do not force WhatsApp's text-only Conversation activity. Let
            // WhatsApp resolve ACTION_SEND application/pdf to its official
            // external-share picker so EXTRA_STREAM remains attached.
            startActivity(baseIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun savePdfToDownloads(filePath: String, requestedFileName: String): String? {
        val source = File(filePath)
        if (!source.exists() || !source.isFile) return null

        val fileName = normalizePdfName(
            requestedFileName.ifBlank { source.name.ifBlank { "ProShop-document.pdf" } }
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/ProShop"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values
            ) ?: return null

            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(source).use { input ->
                        input.copyTo(output)
                    }
                } ?: return null

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                "Downloads/ProShop/$fileName"
            } catch (_: Exception) {
                contentResolver.delete(uri, null, null)
                null
            }
        } else {
            try {
                val downloads = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                val targetDir = File(downloads, "ProShop")
                if (!targetDir.exists()) targetDir.mkdirs()
                val target = uniqueFile(targetDir, fileName)
                source.copyTo(target, overwrite = false)
                target.absolutePath
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun normalizePdfName(fileName: String): String {
        val clean = fileName
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim()
            .ifBlank { "ProShop-document.pdf" }
        return if (clean.lowercase().endsWith(".pdf")) clean else "$clean.pdf"
    }

    private fun uniqueFile(directory: File, fileName: String): File {
        var candidate = File(directory, fileName)
        if (!candidate.exists()) return candidate

        val base = fileName.substringBeforeLast('.', fileName)
        val extension = fileName.substringAfterLast('.', "")
        var index = 1
        while (candidate.exists()) {
            val nextName = if (extension.isEmpty()) {
                "${base}_$index"
            } else {
                "${base}_$index.$extension"
            }
            candidate = File(directory, nextName)
            index += 1
        }
        return candidate
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val EXTRA_OPEN_ALERT_ROUTE = "open_alert_route"
        private val ALERT_DETAIL_ROUTE = Regex("^/(devices|maintenance)/[A-Za-z0-9_-]+$")
        private const val CHANNEL = "com.proshop.mobile_shop_pro/document_share"
        private const val BACKGROUND_ALERTS_CHANNEL =
            "com.proshop.mobile_shop_pro/background_alerts"
    }
}
