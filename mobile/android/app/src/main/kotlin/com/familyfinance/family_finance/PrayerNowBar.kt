package com.familyfinance.family_finance

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date

/**
 * "Prayer ending soon" reminder, shown as an Android 16 Live Update (the
 * Now Bar on Samsung, the status-bar chip elsewhere) with a countdown to the
 * end of the prayer's time, and a plain ongoing notification on older
 * Android. It re-alerts every few minutes until "I prayed" or the time ends.
 *
 * Dart computes the windows (see prayer_ending_soon.dart) and hands them
 * over; from then on it runs on alarms, so it works with the app closed and
 * is re-armed after a reboot from what is stored here.
 */
object PrayerNowBar {
    private const val PREFS = "prayer_nowbar"
    private const val CHANNEL = "ff_prayer_ending"
    // In the prayer block of AppNotifications' id ranges, unused there.
    private const val NOTIFICATION_ID = 300100
    const val ACTION_TICK = "com.familyfinance.prayer.TICK"
    const val ACTION_DONE = "com.familyfinance.prayer.DONE"
    const val ACTION_LATER = "com.familyfinance.prayer.LATER"

    private data class Window(
        val key: String, val name: String, val start: Long, val end: Long, val next: String,
    )

    /** Stores the windows and repeat interval from Dart, then re-arms. */
    fun schedule(ctx: Context, windows: List<Map<String, Any?>>, repeatMinutes: Int) {
        val arr = JSONArray()
        for (w in windows) arr.put(JSONObject(w))
        val keys = windows.map { it["key"].toString() }.toSet()
        val prefs = prefs(ctx)
        prefs.edit()
            .putString("windows", arr.toString())
            .putInt("repeat", repeatMinutes.coerceIn(1, 30))
            // Forget "prayed" marks for windows that are gone.
            .putStringSet("done", prefs.getStringSet("done", emptySet())!!.intersect(keys))
            .apply()
        arm(ctx, alertIfNew = true)
    }

    /** Alarm fired: re-alert during a window, then set the next alarm. */
    fun tick(ctx: Context) {
        val active = active(ctx)
        if (active != null) post(ctx, active, alert = true)
        arm(ctx, alertIfNew = false, skipPost = active != null)
    }

    fun done(ctx: Context, key: String) {
        val prefs = prefs(ctx)
        prefs.edit()
            .putStringSet("done", prefs.getStringSet("done", emptySet())!! + key)
            .apply()
        manager(ctx).cancel(NOTIFICATION_ID)
        arm(ctx, alertIfNew = false)
    }

    /** "Not yet": stay in the Now Bar quietly until the next re-alert. */
    fun later(ctx: Context) {
        active(ctx)?.let { post(ctx, it, alert = false) }
    }

    /**
     * Shows or clears the reminder for now and sets one alarm: the next
     * re-alert inside the current window, else the next window's start.
     */
    fun arm(ctx: Context, alertIfNew: Boolean, skipPost: Boolean = false) {
        val now = System.currentTimeMillis()
        val active = active(ctx)
        if (active == null) {
            manager(ctx).cancel(NOTIFICATION_ID)
        } else if (!skipPost) {
            val showing = manager(ctx).activeNotifications.any { it.id == NOTIFICATION_ID }
            post(ctx, active, alert = alertIfNew && !showing)
        }
        val repeatMs = prefs(ctx).getInt("repeat", 5) * 60_000L
        val nextAt = when {
            active != null && now + repeatMs < active.end -> now + repeatMs
            else -> pending(ctx).map { it.start }.filter { it > now }.minOrNull()
        }
        val pi = tickIntent(ctx)
        val alarms = ctx.getSystemService(AlarmManager::class.java)
        alarms.cancel(pi)
        if (nextAt == null) return
        val exact = Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextAt, pi)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextAt, pi)
        }
    }

    /** Whether Android lets this app post Live Updates (Android 16+). */
    fun canPromote(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 36 || manager(ctx).canPostPromotedNotifications()

    private fun post(ctx: Context, w: Window, alert: Boolean) {
        val nm = manager(ctx)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Prayer ending soon", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "Reminds you to pray before a prayer's time ends" },
            )
        }
        val time = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(w.end))
        val text = if (w.next.isNotEmpty()) {
            "Have you prayed ${w.name}? ${w.next} begins at $time."
        } else {
            "Have you prayed ${w.name}? Its time ends at $time."
        }
        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("${w.name} ends soon")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(!alert)
            // Counts down to the end of the prayer's time, here and in the chip.
            .setWhen(w.end)
            .setShowWhen(true)
            .setUsesChronometer(true)
            // Ask for Live Update promotion (Now Bar / status-bar chip) on
            // Android 16. Set as the extra the platform reads, since the
            // setter isn't in the SDK this app compiles against.
            .addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            .setTimeoutAfter((w.end - System.currentTimeMillis()).coerceAtLeast(1_000L))
            .setContentIntent(open)
            .addAction(0, "I prayed", action(ctx, ACTION_DONE, w.key, 1))
            .addAction(0, "Not yet", action(ctx, ACTION_LATER, w.key, 2))
        // Platform-only bits: count down rather than up, and the chip's label.
        val platform = Notification.Builder.recoverBuilder(ctx, builder.build())
            .setChronometerCountDown(true)
        if (Build.VERSION.SDK_INT >= 36) platform.setShortCriticalText(w.name)
        nm.notify(NOTIFICATION_ID, platform.build())
    }

    private fun windows(ctx: Context): List<Window> {
        val arr = JSONArray(prefs(ctx).getString("windows", "[]"))
        return (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            Window(
                o.getString("key"), o.getString("name"),
                o.getLong("start"), o.getLong("end"), o.optString("next"),
            )
        }
    }

    /** Windows not marked prayed. */
    private fun pending(ctx: Context): List<Window> {
        val done = prefs(ctx).getStringSet("done", emptySet())!!
        return windows(ctx).filter { it.key !in done }
    }

    private fun active(ctx: Context): Window? {
        val now = System.currentTimeMillis()
        return pending(ctx).firstOrNull { now >= it.start && now < it.end }
    }

    private fun tickIntent(ctx: Context) = PendingIntent.getBroadcast(
        ctx, 0,
        Intent(ctx, PrayerNowBarReceiver::class.java).setAction(ACTION_TICK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun action(ctx: Context, what: String, key: String, code: Int) =
        PendingIntent.getBroadcast(
            ctx, code,
            Intent(ctx, PrayerNowBarReceiver::class.java).setAction(what).putExtra("key", key),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun manager(ctx: Context) = ctx.getSystemService(NotificationManager::class.java)
}

/** Alarm ticks, the two buttons, and re-arming after a reboot or update. */
class PrayerNowBarReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            PrayerNowBar.ACTION_TICK -> PrayerNowBar.tick(ctx)
            PrayerNowBar.ACTION_DONE -> PrayerNowBar.done(ctx, intent.getStringExtra("key") ?: return)
            PrayerNowBar.ACTION_LATER -> PrayerNowBar.later(ctx)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                PrayerNowBar.arm(ctx, alertIfNew = true)
        }
    }
}
