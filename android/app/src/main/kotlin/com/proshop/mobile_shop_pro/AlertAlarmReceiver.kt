package com.proshop.mobile_shop_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlertAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_CHECK_BACKGROUND_ALERTS ->
                BackgroundAlertScheduler.handleAlarm(context.applicationContext)
            ACTION_VERIFY_BACKGROUND_ALERTS ->
                BackgroundAlertScheduler.showVerificationNotification(
                    context.applicationContext,
                )
            ACTION_SILENCE_STRONG_ALERT ->
                AlertRingingService.stopAlert(context.applicationContext)
        }
    }

    companion object {
        const val ACTION_CHECK_BACKGROUND_ALERTS =
            "com.proshop.mobile_shop_pro.CHECK_BACKGROUND_ALERTS"
        const val ACTION_VERIFY_BACKGROUND_ALERTS =
            "com.proshop.mobile_shop_pro.VERIFY_BACKGROUND_ALERTS"
        const val ACTION_SILENCE_STRONG_ALERT =
            "com.proshop.mobile_shop_pro.SILENCE_STRONG_ALERT"
    }
}
