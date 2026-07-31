package com.proshop.mobile_shop_pro

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
import java.io.File

/** A native alarm screen that remains available before Flutter starts. */
class StrongAlertActivity : Activity() {
    private lateinit var titleView: TextView
    private lateinit var detailsContainer: LinearLayout

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

        detailsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            minimumHeight = dp(300)
            setPadding(dp(14), dp(14), dp(14), dp(14))
            background = roundedBackground(
                fill = Color.WHITE,
                stroke = Color.rgb(253, 186, 116),
                radius = dp(18).toFloat(),
            )
        }
        root.addView(
            detailsContainer,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
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
        val fallbackMessage = source?.getStringExtra(AlertRingingService.EXTRA_MESSAGE)
            ?.takeIf { it.isNotBlank() }
            ?: "افتح شاشة التنبيهات لمراجعة التفاصيل واتخاذ الإجراء."
        val devices = AlertRingingService.decodeDevices(
            source?.getStringExtra(AlertRingingService.EXTRA_DEVICES),
        )
        detailsContainer.removeAllViews()
        if (devices.isEmpty()) {
            detailsContainer.addView(
                TextView(this).apply {
                    text = fallbackMessage
                    textSize = 18f
                    setTextColor(Color.rgb(55, 65, 81))
                    gravity = Gravity.CENTER
                    setLineSpacing(0f, 1.28f)
                    setPadding(dp(4), dp(18), dp(4), dp(18))
                },
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )
            return
        }

        devices.forEachIndexed { index, device ->
            if (index > 0) {
                detailsContainer.addView(
                    View(this).apply { setBackgroundColor(Color.rgb(229, 231, 235)) },
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        dp(1),
                    ).apply {
                        topMargin = dp(12)
                        bottomMargin = dp(12)
                    },
                )
            }
            detailsContainer.addView(
                buildDevicePreview(device),
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
    }

    private fun buildDevicePreview(device: StrongAlertDevicePreview): View {
        val item = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }

        loadPreviewBitmap(device.imagePath)?.let { bitmap ->
            row.addView(
                ImageView(this).apply {
                    setImageBitmap(bitmap)
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    contentDescription = "صورة ${device.displayName()}"
                    background = roundedBackground(
                        fill = Color.rgb(243, 244, 246),
                        radius = dp(10).toFloat(),
                    )
                    clipToOutline = true
                },
                LinearLayout.LayoutParams(dp(92), dp(110)).apply {
                    leftMargin = dp(12)
                },
            )
        }

        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        textColumn.addView(TextView(this).apply {
            text = device.displayName()
            textSize = 18f
            setTextColor(Color.rgb(31, 41, 55))
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.START
        })

        val specifications = buildList {
            device.customerName?.let { add("العميل: $it") }
            device.color?.let { add("اللون: $it") }
            device.storage?.let { add("السعة: $it") }
            device.imei?.let { add("IMEI: $it") }
            device.ticketNumber?.let { add("رقم الصيانة: $it") }
        }
        if (specifications.isNotEmpty()) {
            textColumn.addView(TextView(this).apply {
                text = specifications.joinToString("\n")
                textSize = 14.5f
                setTextColor(Color.rgb(75, 85, 99))
                gravity = Gravity.START
                setLineSpacing(0f, 1.18f)
                setPadding(0, dp(5), 0, 0)
            })
        }
        row.addView(
            textColumn,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        item.addView(
            row,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        item.addView(
            Button(this).apply {
                text = device.targetLabel
                textSize = 15f
                isAllCaps = false
                setTextColor(Color.WHITE)
                setTypeface(typeface, Typeface.BOLD)
                background = roundedBackground(
                    fill = Color.rgb(109, 40, 217),
                    radius = dp(11).toFloat(),
                )
                setOnClickListener { openTarget(device.targetRoute) }
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(46),
            ).apply { topMargin = dp(10) },
        )
        return item
    }

    private fun StrongAlertDevicePreview.displayName(): String {
        return listOf(brand, model)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .joinToString(" ")
            .ifBlank { "جوال مرتبط بالتنبيه" }
    }

    private fun loadPreviewBitmap(path: String?): Bitmap? {
        val imagePath = path?.takeIf { it.isNotBlank() } ?: return null
        val file = File(imagePath)
        if (!file.isFile) return null
        return runCatching {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(imagePath, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
            val maxDimension = dp(320)
            var sampleSize = 1
            while (
                bounds.outWidth / sampleSize > maxDimension * 2 ||
                    bounds.outHeight / sampleSize > maxDimension * 2
            ) {
                sampleSize *= 2
            }
            BitmapFactory.decodeFile(
                imagePath,
                BitmapFactory.Options().apply { inSampleSize = sampleSize },
            )
        }.getOrNull()
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

    private fun openTarget(route: String) {
        AlertRingingService.stopAlert(applicationContext)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_OPEN_ALERT_ROUTE, route)
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

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
