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

/**
 * The prayer island: an Android 16 Live Update (Samsung's Now Bar, the
 * status-bar pill elsewhere; a plain ongoing notification on older Android).
 *
 * - All day (if on): the next prayer with a countdown, silently.
 * - N minutes before a prayer's time ends: a reminder ("Have you prayed
 *   Asr?") with Prayed / Not-yet buttons that re-alerts every few minutes
 *   until marked or the time ends.
 *
 * Dart computes everything (prayer_ending_soon.dart, islandPayload) and
 * hands it over; this runs it on alarms, so it works with the app closed
 * and is re-armed after a reboot from what is stored here.
 */
object PrayerNowBar {
    private const val PREFS = "prayer_nowbar"
    private const val CHANNEL_ASK = "ff_prayer_ending"
    private const val CHANNEL_ISLAND = "ff_prayer_island"
    // In the prayer block of AppNotifications' id ranges, unused there.
    private const val NOTIFICATION_ID = 300100
    const val ACTION_TICK = "com.familyfinance.prayer.TICK"
    const val ACTION_DONE = "com.familyfinance.prayer.DONE"
    const val ACTION_LATER = "com.familyfinance.prayer.LATER"

    private data class Window(
        val key: String, val name: String, val start: Long, val end: Long,
        val title: String, val text: String, val done: String, val later: String,
    )

    private data class Prayer(val name: String, val at: Long, val title: String)

    /** Stores what Dart computed, then re-arms. */
    fun schedule(ctx: Context, args: Map<String, Any?>) {
        @Suppress("UNCHECKED_CAST")
        val windows = (args["windows"] as? List<Map<String, Any?>>).orEmpty()
        @Suppress("UNCHECKED_CAST")
        val prayers = (args["prayers"] as? List<Map<String, Any?>>).orEmpty()
        val keys = windows.map { it["key"].toString() }.toSet()
        val prefs = prefs(ctx)
        prefs.edit()
            .putString("windows", JSONArray(windows.map { JSONObject(it) }).toString())
            .putString("prayers", JSONArray(prayers.map { JSONObject(it) }).toString())
            .putInt("repeat", ((args["repeatMinutes"] as? Int) ?: 5).coerceIn(1, 30))
            .putBoolean("chipName", (args["chipName"] as? Boolean) ?: true)
            .putLong("color", ((args["color"] as? Number) ?: 0).toLong())
            // Forget "prayed" marks for windows that are gone.
            .putStringSet("done", prefs.getStringSet("done", emptySet())!!.intersect(keys))
            .apply()
        arm(ctx, alertIfNew = true)
    }

    /** Alarm fired: re-alert during a window, then set the next alarm. */
    fun tick(ctx: Context) {
        val snoozed = System.currentTimeMillis() < prefs(ctx).getLong("snoozedUntil", 0L)
        if (!snoozed) prefs(ctx).edit().remove("snoozedUntil").apply()
        val active = if (snoozed) null else active(ctx)
        if (active != null) postAsk(ctx, active, alert = true)
        arm(ctx, alertIfNew = false, skipPost = active != null)
    }

    fun done(ctx: Context, key: String) {
        val prefs = prefs(ctx)
        prefs.edit()
            .putStringSet("done", prefs.getStringSet("done", emptySet())!! + key)
            .remove("snoozedUntil")
            .apply()
        arm(ctx, alertIfNew = false)
    }

    /** "Not yet": put the question away until the snooze gap has passed. */
    fun later(ctx: Context) {
        val repeatMs = prefs(ctx).getInt("repeat", 5) * 60_000L
        prefs(ctx).edit().putLong("snoozedUntil", System.currentTimeMillis() + repeatMs).apply()
        arm(ctx, alertIfNew = false)
    }

    /**
     * Shows what belongs on screen now (reminder, else island, else
     * nothing) and sets one alarm for the next change: a re-alert inside the
     * current window, the next window's start, or the next prayer time.
     */
    fun arm(ctx: Context, alertIfNew: Boolean, skipPost: Boolean = false) {
        val now = System.currentTimeMillis()
        val active = active(ctx)
        val next = prayers(ctx).firstOrNull { it.at > now }
        val snoozedUntil = prefs(ctx).getLong("snoozedUntil", 0L)
        val snoozed = active != null && now < snoozedUntil
        when {
            skipPost -> {}
            snoozed && next != null -> postIsland(ctx, next)
            snoozed -> manager(ctx).cancel(NOTIFICATION_ID)
            active != null -> {
                val showing = manager(ctx).activeNotifications
                    .any { it.id == NOTIFICATION_ID && it.notification.channelId == CHANNEL_ASK }
                postAsk(ctx, active, alert = alertIfNew && !showing)
            }
            next != null -> postIsland(ctx, next)
            else -> manager(ctx).cancel(NOTIFICATION_ID)
        }
        val repeatMs = prefs(ctx).getInt("repeat", 5) * 60_000L
        val candidates = listOfNotNull(
            if (snoozed) snoozedUntil else null,
            if (active != null && !snoozed && now + repeatMs < active.end) now + repeatMs else null,
            active?.end,
            pending(ctx).map { it.start }.filter { it > now }.minOrNull(),
            next?.at,
        )
        val pi = tickIntent(ctx)
        val alarms = ctx.getSystemService(AlarmManager::class.java)
        alarms.cancel(pi)
        val nextAt = candidates.filter { it > now }.minOrNull() ?: return
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

    private fun postAsk(ctx: Context, w: Window, alert: Boolean) {
        channel(ctx, CHANNEL_ASK, "Prayer ending soon", NotificationManager.IMPORTANCE_HIGH)
        val builder = base(ctx, CHANNEL_ASK, w.title, w.text, w.end)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOnlyAlertOnce(!alert)
            .addAction(0, w.done, action(ctx, ACTION_DONE, w.key, 1))
            .addAction(0, w.later, action(ctx, ACTION_LATER, w.key, 2))
        notify(ctx, builder, w.name)
    }

    private fun postIsland(ctx: Context, p: Prayer) {
        // Low importance: it never makes a sound; the chip and card update
        // silently as the day goes on.
        channel(ctx, CHANNEL_ISLAND, "Prayer island", NotificationManager.IMPORTANCE_LOW)
        val builder = base(ctx, CHANNEL_ISLAND, p.title, "Next prayer", p.at)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOnlyAlertOnce(true)
        notify(ctx, builder, p.name)
    }

    private fun base(ctx: Context, channel: String, title: String, text: String, until: Long) =
        NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.drawable.ic_notification)
            // The chip's background (and the accent in the shade). Not
            // setColorized: that would stop Android promoting it.
            .setColor(prefs(ctx).getLong("color", 0L).toInt())
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            // Counts down to [until], here and in the status-bar chip.
            .setWhen(until)
            .setShowWhen(true)
            .setUsesChronometer(true)
            // Ask for Live Update promotion (Now Bar / status-bar chip) on
            // Android 16. Set as the extra the platform reads, since the
            // setter isn't in the SDK this app compiles against.
            .addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            .setTimeoutAfter((until - System.currentTimeMillis() + 60_000L).coerceAtLeast(1_000L))
            .setContentIntent(
                PendingIntent.getActivity(
                    ctx, 0,
                    Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )

    private fun notify(ctx: Context, builder: NotificationCompat.Builder, chipName: String) {
        // Platform-only bits: count down rather than up, and the chip's label
        // (left out to make the chip show the countdown instead).
        val platform = Notification.Builder.recoverBuilder(ctx, builder.build())
            .setChronometerCountDown(true)
        if (Build.VERSION.SDK_INT >= 36 && prefs(ctx).getBoolean("chipName", true)) {
            platform.setShortCriticalText(chipName)
        }
        manager(ctx).notify(NOTIFICATION_ID, platform.build())
    }

    private fun channel(ctx: Context, id: String, name: String, importance: Int) {
        // Always (re)create: it is a no-op for an existing channel, and a
        // "found but deleted" check misses channels wiped with the app data.
        if (Build.VERSION.SDK_INT >= 26) {
            manager(ctx).createNotificationChannel(NotificationChannel(id, name, importance))
        }
    }

    private fun windows(ctx: Context): List<Window> {
        val arr = JSONArray(prefs(ctx).getString("windows", "[]"))
        return (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            Window(
                o.getString("key"), o.getString("name"), o.getLong("start"), o.getLong("end"),
                o.optString("title"), o.optString("text"),
                o.optString("done", "Prayed"), o.optString("later", "Later"),
            )
        }
    }

    private fun prayers(ctx: Context): List<Prayer> {
        val arr = JSONArray(prefs(ctx).getString("prayers", "[]"))
        return (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            Prayer(o.getString("name"), o.getLong("at"), o.optString("title"))
        }.sortedBy { it.at }
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
