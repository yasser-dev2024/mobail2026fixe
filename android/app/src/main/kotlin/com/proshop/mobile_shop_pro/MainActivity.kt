package com.proshop.mobile_shop_pro

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
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
    }

    private fun sharePdfToWhatsApp(filePath: String, phone: String, message: String): Boolean {
        val file = File(filePath)
        if (!file.exists() || !file.isFile) return false

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, message)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val whatsappPackage = listOf("com.whatsapp", "com.whatsapp.w4b")
            .firstOrNull { packageName -> isPackageInstalled(packageName) }

        if (whatsappPackage != null) {
            intent.setPackage(whatsappPackage)
            val digits = phone.filter { it.isDigit() }
            if (digits.isNotEmpty()) {
                intent.putExtra("jid", "$digits@s.whatsapp.net")
            }
            grantUriPermission(whatsappPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        return try {
            if (whatsappPackage == null) {
                startActivity(Intent.createChooser(intent, "Share PDF"))
            } else {
                startActivity(intent)
            }
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
        private const val CHANNEL = "com.proshop.mobile_shop_pro/document_share"
    }
}
