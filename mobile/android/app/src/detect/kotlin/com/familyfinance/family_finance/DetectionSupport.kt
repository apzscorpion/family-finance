package com.familyfinance.family_finance

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Notification-based payment detection, as built into the `detect` flavour.
 *
 * The `standard` flavour ships a stub with the same shape that reports the
 * feature as unavailable, so MainActivity has no knowledge of which build it
 * is in and the listener class is absent from the standard APK entirely.
 */
object DetectionSupport {

    /** Whether this build contains the listener at all. */
    const val AVAILABLE = true

    /**
     * Notification access is granted in system settings rather than through a
     * runtime prompt, so it is read back from the enabled-listeners list.
     */
    fun isGranted(context: Context): Boolean {
        return try {
            val flat = Settings.Secure.getString(
                context.contentResolver, "enabled_notification_listeners"
            ) ?: return false
            val me = ComponentName(context, TxnNotificationListenerService::class.java)
            flat.split(":").any {
                val c = ComponentName.unflattenFromString(it)
                c != null && c.packageName == me.packageName && c.className == me.className
            }
        } catch (_: Exception) {
            false
        }
    }

    fun openSettings(activity: Activity): Boolean {
        return try {
            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Hands over everything captured since the last drain and clears the
     * queue, so a notification is surfaced once.
     */
    fun drainQueue(context: Context): String {
        return try {
            val prefs = context.getSharedPreferences(
                TxnNotificationListenerService.PREFS, Context.MODE_PRIVATE
            )
            val raw = prefs.getString(TxnNotificationListenerService.KEY, "[]") ?: "[]"
            prefs.edit().putString(TxnNotificationListenerService.KEY, "[]").apply()
            raw
        } catch (_: Exception) {
            "[]"
        }
    }

    fun queueSize(context: Context): Int {
        return try {
            val prefs = context.getSharedPreferences(
                TxnNotificationListenerService.PREFS, Context.MODE_PRIVATE
            )
            val raw = prefs.getString(TxnNotificationListenerService.KEY, "[]") ?: "[]"
            org.json.JSONArray(raw).length()
        } catch (_: Exception) {
            0
        }
    }
}
