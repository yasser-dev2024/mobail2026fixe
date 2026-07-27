package com.proshop.mobile_shop_pro

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlertBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                BackgroundAlertScheduler.setAppVisible(
                    context.applicationContext,
                    false,
                )
                BackgroundAlertScheduler.initialize(context.applicationContext)
            }
        }
    }
}
