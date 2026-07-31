package com.proshop.mobile_shop_pro

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

internal data class StrongAlertDevicePreview(
    val brand: String,
    val model: String,
    val color: String?,
    val storage: String?,
    val imei: String?,
    val ticketNumber: String?,
    val customerName: String?,
    val imagePath: String?,
    val targetRoute: String,
    val targetLabel: String,
)

internal data class StrongAlertPayload(
    val title: String,
    val message: String,
    val channelId: String,
    val soundKind: String,
    val alertCount: Int,
    val critical: Boolean,
    val createdAt: Long,
    val soundsEnabled: Boolean,
    val volume: Float,
    val vibrationEnabled: Boolean,
    val repeatCount: Int,
    val devices: List<StrongAlertDevicePreview> = emptyList(),
)

/**
 * Keeps a real alarm-style sound and vibration alive while Flutter is closed.
 *
 * Notification-channel audio alone is intentionally not used here: vendors
 * can reduce it to a short badge/banner. A media-playback foreground service
 * using USAGE_ALARM gives the user the configured bundled sound, repeat count,
 * volume and vibration until it finishes or is explicitly silenced.
 */
class AlertRingingService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var legacyAudioFocusGranted = false
    private var completedPlays = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = intent?.toPayload() ?: run {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val notification = buildStrongNotification(this, payload)
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            } else {
                0
            },
        )
        startPlayback(payload)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopPlayback()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        super.onDestroy()
    }

    private fun startPlayback(payload: StrongAlertPayload) {
        stopPlayback()
        completedPlays = 0
        acquireWakeLock()

        if (payload.vibrationEnabled) {
            startVibration(
                repeat = payload.soundsEnabled && payload.volume > 0f,
            )
        }
        if (!payload.soundsEnabled || payload.volume <= 0f) {
            releaseWakeLock()
            return
        }

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        requestAudioFocus(attributes)

        try {
            player = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setVolume(payload.volume, payload.volume)
                if (payload.soundKind == SOUND_MAINTENANCE) {
                    resources.openRawResourceFd(R.raw.proshop_maintenance_alert).use { afd ->
                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    }
                } else if (payload.soundKind == SOUND_WARRANTY) {
                    resources.openRawResourceFd(R.raw.proshop_warranty_alert).use { afd ->
                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    }
                } else {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    setDataSource(this@AlertRingingService, uri)
                }
                isLooping = payload.repeatCount <= 0
                setOnPreparedListener { prepared -> prepared.start() }
                setOnCompletionListener { completed ->
                    completedPlays++
                    if (payload.repeatCount > 0 && completedPlays < payload.repeatCount) {
                        completed.seekTo(0)
                        completed.start()
                    } else {
                        finishAudiblePlayback()
                    }
                }
                setOnErrorListener { _, _, _ ->
                    finishAudiblePlayback()
                    true
                }
                prepareAsync()
            }
        } catch (_: Exception) {
            finishAudiblePlayback()
        }
    }

    private fun requestAudioFocus(attributes: AudioAttributes) {
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager = manager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest = AudioFocusRequest.Builder(
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
                    .setAudioAttributes(attributes)
                    .setOnAudioFocusChangeListener { }
                    .build()
                    .also { manager.requestAudioFocus(it) }
            } else {
                @Suppress("DEPRECATION")
                legacyAudioFocusGranted = manager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
        } catch (_: Exception) {
            // Alarm playback remains best-effort if a vendor rejects focus.
        }
    }

    private fun startVibration(repeat: Boolean) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0L, 850L, 300L, 850L, 550L)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(
                    VibrationEffect.createWaveform(pattern, if (repeat) 0 else -1),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, if (repeat) 0 else -1)
            }
        } catch (_: Exception) {
            // Some devices disable vibration globally; sound must still work.
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:strong-alert",
            ).apply {
                setReferenceCounted(false)
                acquire(MAX_WAKE_LOCK_MS)
            }
        } catch (_: Exception) {
            wakeLock = null
        }
    }

    private fun finishAudiblePlayback() {
        try {
            player?.release()
        } catch (_: Exception) {
        } finally {
            player = null
        }
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
        abandonAudioFocus()
        releaseWakeLock()
    }

    private fun stopPlayback() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        finishAudiblePlayback()
    }

    private fun abandonAudioFocus() {
        val manager = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { manager.abandonAudioFocusRequest(it) }
            } else if (legacyAudioFocusGranted) {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(null)
            }
        } catch (_: Exception) {
        }
        audioFocusRequest = null
        legacyAudioFocusGranted = false
        audioManager = null
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    companion object {
        const val SOUND_MAINTENANCE = "maintenance"
        const val SOUND_WARRANTY = "warranty"
        const val SOUND_GENERAL = "general"

        const val EXTRA_TITLE = "strong_alert_title"
        const val EXTRA_MESSAGE = "strong_alert_message"
        const val EXTRA_DEVICES = "strong_alert_devices"
        private const val EXTRA_CHANNEL_ID = "strong_alert_channel_id"
        private const val EXTRA_SOUND_KIND = "strong_alert_sound_kind"
        private const val EXTRA_ALERT_COUNT = "strong_alert_count"
        private const val EXTRA_CRITICAL = "strong_alert_critical"
        private const val EXTRA_CREATED_AT = "strong_alert_created_at"
        private const val EXTRA_SOUNDS_ENABLED = "strong_alert_sounds_enabled"
        private const val EXTRA_VOLUME = "strong_alert_volume"
        private const val EXTRA_VIBRATION_ENABLED = "strong_alert_vibration_enabled"
        private const val EXTRA_REPEAT_COUNT = "strong_alert_repeat_count"

        const val NOTIFICATION_ID = 7301
        private const val CONTENT_REQUEST_CODE = 7301
        private const val FULL_SCREEN_REQUEST_CODE = 7303
        private const val SILENCE_REQUEST_CODE = 7304
        private const val MAX_WAKE_LOCK_MS = 10L * 60L * 1000L

        internal fun startAlert(context: Context, payload: StrongAlertPayload) {
            val serviceIntent = Intent(context, AlertRingingService::class.java)
                .putPayload(payload)
            try {
                ContextCompat.startForegroundService(context, serviceIntent)
            } catch (_: Exception) {
                // Keep a maximum-priority full-screen notification even if a
                // vendor temporarily refuses the foreground-service start.
                NotificationManagerCompat.from(context).notify(
                    NOTIFICATION_ID,
                    buildStrongNotification(context, payload),
                )
            }
        }

        fun stopAlert(context: Context) {
            try {
                context.stopService(Intent(context, AlertRingingService::class.java))
            } catch (_: Exception) {
            }
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }

        internal fun buildStrongNotification(
            context: Context,
            payload: StrongAlertPayload,
        ): Notification {
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
            launchIntent.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("open_notifications", true)
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                CONTENT_REQUEST_CODE,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val fullScreenIntent = PendingIntent.getActivity(
                context,
                FULL_SCREEN_REQUEST_CODE,
                Intent(context, StrongAlertActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_TITLE, payload.title)
                    putExtra(EXTRA_MESSAGE, payload.message)
                    putExtra(EXTRA_DEVICES, encodeDevices(payload.devices))
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val silenceIntent = PendingIntent.getBroadcast(
                context,
                SILENCE_REQUEST_CODE,
                Intent(context, AlertAlarmReceiver::class.java).apply {
                    action = AlertAlarmReceiver.ACTION_SILENCE_STRONG_ALERT
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            return NotificationCompat.Builder(context, payload.channelId)
                .setSmallIcon(R.drawable.ic_stat_proshop)
                .setContentTitle(payload.title)
                .setContentText(payload.message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(payload.message))
                .setContentIntent(contentIntent)
                .setFullScreenIntent(fullScreenIntent, true)
                .addAction(
                    R.drawable.ic_stat_proshop,
                    "إسكات الآن",
                    silenceIntent,
                )
                .addAction(
                    R.drawable.ic_stat_proshop,
                    "فتح التنبيهات",
                    contentIntent,
                )
                .setAutoCancel(false)
                .setOngoing(true)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setNumber(payload.alertCount)
                .setWhen(payload.createdAt)
                .setShowWhen(true)
                .setOnlyAlertOnce(false)
                .setColor(if (payload.critical) 0xFFD32F2F.toInt() else 0xFFFF8F00.toInt())
                .setColorized(true)
                .setForegroundServiceBehavior(
                    NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE,
                )
                .build()
        }

        private fun Intent.putPayload(payload: StrongAlertPayload): Intent = apply {
            putExtra(EXTRA_TITLE, payload.title)
            putExtra(EXTRA_MESSAGE, payload.message)
            putExtra(EXTRA_CHANNEL_ID, payload.channelId)
            putExtra(EXTRA_SOUND_KIND, payload.soundKind)
            putExtra(EXTRA_ALERT_COUNT, payload.alertCount)
            putExtra(EXTRA_CRITICAL, payload.critical)
            putExtra(EXTRA_CREATED_AT, payload.createdAt)
            putExtra(EXTRA_SOUNDS_ENABLED, payload.soundsEnabled)
            putExtra(EXTRA_VOLUME, payload.volume)
            putExtra(EXTRA_VIBRATION_ENABLED, payload.vibrationEnabled)
            putExtra(EXTRA_REPEAT_COUNT, payload.repeatCount)
            putExtra(EXTRA_DEVICES, encodeDevices(payload.devices))
        }

        private fun Intent.toPayload(): StrongAlertPayload? {
            val title = getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() } ?: return null
            val channelId =
                getStringExtra(EXTRA_CHANNEL_ID)?.takeIf { it.isNotBlank() } ?: return null
            return StrongAlertPayload(
                title = title,
                message = getStringExtra(EXTRA_MESSAGE).orEmpty(),
                channelId = channelId,
                soundKind = getStringExtra(EXTRA_SOUND_KIND) ?: SOUND_GENERAL,
                alertCount = getIntExtra(EXTRA_ALERT_COUNT, 1).coerceAtLeast(1),
                critical = getBooleanExtra(EXTRA_CRITICAL, false),
                createdAt = getLongExtra(EXTRA_CREATED_AT, System.currentTimeMillis()),
                soundsEnabled = getBooleanExtra(EXTRA_SOUNDS_ENABLED, true),
                volume = getFloatExtra(EXTRA_VOLUME, 1f).coerceIn(0f, 1f),
                vibrationEnabled = getBooleanExtra(EXTRA_VIBRATION_ENABLED, true),
                repeatCount = getIntExtra(EXTRA_REPEAT_COUNT, 1),
                devices = decodeDevices(getStringExtra(EXTRA_DEVICES)),
            )
        }

        internal fun encodeDevices(devices: List<StrongAlertDevicePreview>): String {
            val values = JSONArray()
            devices.forEach { device ->
                values.put(
                    JSONObject().apply {
                        put("brand", device.brand)
                        put("model", device.model)
                        putNullable("color", device.color)
                        putNullable("storage", device.storage)
                        putNullable("imei", device.imei)
                        putNullable("ticketNumber", device.ticketNumber)
                        putNullable("customerName", device.customerName)
                        putNullable("imagePath", device.imagePath)
                        put("targetRoute", device.targetRoute)
                        put("targetLabel", device.targetLabel)
                    },
                )
            }
            return values.toString()
        }

        internal fun decodeDevices(encoded: String?): List<StrongAlertDevicePreview> {
            if (encoded.isNullOrBlank()) return emptyList()
            return runCatching {
                val values = JSONArray(encoded)
                buildList {
                    for (index in 0 until values.length()) {
                        val value = values.optJSONObject(index) ?: continue
                        val route = value.optString("targetRoute").trim()
                        if (route.isEmpty()) continue
                        add(
                            StrongAlertDevicePreview(
                                brand = value.optString("brand").trim(),
                                model = value.optString("model").trim(),
                                color = value.stringOrNull("color"),
                                storage = value.stringOrNull("storage"),
                                imei = value.stringOrNull("imei"),
                                ticketNumber = value.stringOrNull("ticketNumber"),
                                customerName = value.stringOrNull("customerName"),
                                imagePath = value.stringOrNull("imagePath"),
                                targetRoute = route,
                                targetLabel = value.optString("targetLabel")
                                    .trim()
                                    .ifBlank { "فتح الجوال" },
                            ),
                        )
                    }
                }
            }.getOrDefault(emptyList())
        }

        private fun JSONObject.putNullable(key: String, value: String?) {
            if (value.isNullOrBlank()) put(key, JSONObject.NULL) else put(key, value)
        }

        private fun JSONObject.stringOrNull(key: String): String? {
            if (isNull(key)) return null
            return optString(key).trim().takeIf { it.isNotEmpty() }
        }
    }
}
