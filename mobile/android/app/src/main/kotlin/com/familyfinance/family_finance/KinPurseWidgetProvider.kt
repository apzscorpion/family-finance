package com.familyfinance.family_finance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Android Home-Screen Widget for KinPurse.
 * Displays:
 * - Today's total spent.
 * - Next prayer name & time.
 * - 1-tap quick action to open KinPurse instant add / voice expense capture.
 */
class KinPurseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS = "kinpurse_widget_data"
        const val ACTION_REFRESH_WIDGET = "com.familyfinance.widget.REFRESH"

        fun updateData(
            context: Context,
            todaySpent: String,
            nextPrayerName: String,
            nextPrayerTime: String
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("today_spent", todaySpent)
                .putString("next_prayer_name", nextPrayerName)
                .putString("next_prayer_time", nextPrayerTime)
                .apply()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, KinPurseWidgetProvider::class.java)
            )
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val todaySpent = prefs.getString("today_spent", "₹0") ?: "₹0"
            val prayerName = prefs.getString("next_prayer_name", "Prayer") ?: "Prayer"
            val prayerTime = prefs.getString("next_prayer_time", "--:--") ?: "--:--"

            val views = RemoteViews(context.packageName, R.layout.kinpurse_widget_layout)
            views.setTextViewText(R.id.widget_spent_text, todaySpent)
            views.setTextViewText(R.id.widget_prayer_text, "$prayerName $prayerTime")

            // Intent to open KinPurse app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Intent to open Quick Add directly
            val addIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "quick_add")
            }
            val addPendingIntent = PendingIntent.getActivity(
                context,
                101,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_btn, addPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

