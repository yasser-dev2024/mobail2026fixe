package com.proshop.mobile_shop_pro

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** A native alarm screen that remains available before Flutter starts. */
class StrongAlertActivity : Activity() {
    private lateinit var titleView: TextView
    private lateinit var messageView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.rgb(153, 27, 27)
        window.navigationBarColor = Color.rgb(69, 10, 10)
        setContentView(buildContent())
        applyIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        silenceAndFinish()
    }

    private fun buildContent(): View {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(42), dp(24), dp(28))
            setBackgroundColor(Color.rgb(255, 247, 237))
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }

        val icon = ImageView(this).apply {
            setImageDrawable(applicationInfo.loadIcon(packageManager))
            contentDescription = "شعار مساعد الصيانة"
        }
        root.addView(icon, LinearLayout.LayoutParams(dp(92), dp(92)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = dp(18)
        })

        root.addView(TextView(this).apply {
            text = "تنبيه عاجل من مساعد الصيانة"
            textSize = 17f
            setTextColor(Color.rgb(185, 28, 28))
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
        })

        titleView = TextView(this).apply {
            textSize = 28f
            setTextColor(Color.rgb(31, 41, 55))
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(18), 0, dp(14))
        }
        root.addView(
            titleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        messageView = TextView(this).apply {
            textSize = 18f
            setTextColor(Color.rgb(55, 65, 81))
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.28f)
            setPadding(dp(18), dp(18), dp(18), dp(18))
            background = roundedBackground(
                fill = Color.WHITE,
                stroke = Color.rgb(253, 186, 116),
                radius = dp(18).toFloat(),
            )
        }
        root.addView(
            messageView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ).apply {
                topMargin = dp(4)
                bottomMargin = dp(22)
            },
        )

        val openButton = Button(this).apply {
            text = "فتح وإدارة التنبيهات"
            textSize = 17f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            background = roundedBackground(
                fill = Color.rgb(109, 40, 217),
                radius = dp(14).toFloat(),
            )
            setOnClickListener { openNotifications() }
        }
        root.addView(
            openButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(58),
            ),
        )

        val silenceButton = Button(this).apply {
            text = "إسكات الصوت الآن"
            textSize = 16f
            setTextColor(Color.rgb(185, 28, 28))
            setTypeface(typeface, Typeface.BOLD)
            background = roundedBackground(
                fill = Color.WHITE,
                stroke = Color.rgb(248, 113, 113),
                radius = dp(14).toFloat(),
            )
            setOnClickListener { silenceAndFinish() }
        }
        root.addView(
            silenceButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(56),
            ).apply { topMargin = dp(12) },
        )

        return ScrollView(this).apply {
            isFillViewport = true
            addView(
                root,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    private fun applyIntent(source: Intent?) {
        titleView.text = source?.getStringExtra(AlertRingingService.EXTRA_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: "تنبيه يحتاج المراجعة"
        messageView.text = source?.getStringExtra(AlertRingingService.EXTRA_MESSAGE)
            ?.takeIf { it.isNotBlank() }
            ?: "افتح شاشة التنبيهات لمراجعة التفاصيل واتخاذ الإجراء."
    }

    private fun openNotifications() {
        AlertRingingService.stopAlert(applicationContext)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_notifications", true)
        }
        startActivity(launchIntent)
        finishAndRemoveTask()
    }

    private fun silenceAndFinish() {
        AlertRingingService.stopAlert(applicationContext)
        finishAndRemoveTask()
    }

    private fun roundedBackground(
        fill: Int,
        stroke: Int? = null,
        radius: Float,
    ): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(fill)
        cornerRadius = radius
        if (stroke != null) setStroke((2 * resources.displayMetrics.density).toInt(), stroke)
    }
}
