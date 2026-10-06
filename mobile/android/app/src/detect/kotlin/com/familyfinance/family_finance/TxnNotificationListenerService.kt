package com.familyfinance.family_finance

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Captures payment notifications posted by banking and UPI apps.
 *
 * Deliberately minimal: this service does no parsing and makes no network
 * calls. It appends the notification's title and text to a local queue which
 * the Flutter side drains when the app is next opened. Parsing lives in Dart
 * so the rules can be changed without touching native code.
 *
 * The service can run when no Flutter engine is alive, which is why the queue
 * is persisted rather than pushed over a channel.
 *
 * Nothing here reads SMS. Android's SMS permissions are Restricted Permissions
 * that Google Play only grants to apps whose core purpose is messaging, so a
 * finance app that requests them is rejected. Notifications carry the same
 * payment information without that problem.
 */
class TxnNotificationListenerService : NotificationListenerService() {

    companion object {
        const val PREFS = "ff_notif_queue"
        const val KEY = "pending"

        /** Cap the queue so an unopened app cannot grow it without bound. */
        private const val MAX_QUEUED = 200

        /**
         * Only packages that actually post payment alerts. Anything else is
         * ignored outright — the service never sees a reason to look at chat,
         * email or social notifications.
         */
        private val WATCHED = setOf(
            // UPI
            "com.google.android.apps.nbu.paisa.user",   // Google Pay
            "net.one97.paytm",                          // Paytm
            "in.org.npci.upiapp",                       // BHIM
            "com.phonepe.app",                          // PhonePe
            "com.amazon.mShop.android.shopping",        // Amazon Pay
            "com.whatsapp",                             // WhatsApp Pay
            // Banks
            "com.snapwork.hdfc",                        // HDFC
            "com.csam.icici.bank.imobile",              // ICICI
            "com.sbi.lotusintouch",                     // YONO SBI
            "com.sbi.SBIFreedomPlus",
            "com.axis.mobile",                          // Axis
            "com.kotak.mobile",                         // Kotak
            "com.fss.pnbpsp",                           // PNB
            "com.bankofbaroda.mconnect",                // BoB
            "com.infrasofttech.indianBank",
            "com.canarabank.mobility",
            "com.msf.kbank.mobile",
            "com.idbibank.gomobile",
            "com.yesbank"
        )

        /**
         * A payment alert almost always names a currency amount. Requiring one
         * keeps promotional and login notifications out of the queue.
         */
        private val AMOUNT_HINT = Regex(
            """(?:₹|rs\.?|inr)\s*[\d,]+(?:\.\d{1,2})?""",
            RegexOption.IGNORE_CASE
        )

        /** Words that mark a message as marketing rather than a transaction. */
        private val PROMO_HINT = Regex(
            """\b(offer|cashback up to|win |sale|discount|coupon|reward points|emi offer|pre-approved|apply now)\b""",
            RegexOption.IGNORE_CASE
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val pkg = sbn.packageName ?: return
            if (pkg !in WATCHED) return

            val extras = sbn.notification?.extras ?: return
            val title = extras.getCharSequence("android.title")?.toString().orEmpty()
            val text = extras.getCharSequence("android.text")?.toString()
                ?: extras.getCharSequence("android.bigText")?.toString()
                ?: ""

            val body = "$title $text"
            if (!AMOUNT_HINT.containsMatchIn(body)) return
            if (PROMO_HINT.containsMatchIn(body)) return

            enqueue(
                JSONObject()
                    .put("package", pkg)
                    .put("title", title)
                    .put("text", text)
                    .put("postedAt", sbn.postTime)
            )
        } catch (_: Exception) {
            // A malformed notification must never crash the listener; dropping
            // one capture is better than losing the service.
        }
    }

    private fun enqueue(item: JSONObject) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY, "[]") ?: "[]"
        val arr = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

        // Same app, same text, within a minute: a re-post of the same alert.
        for (i in 0 until arr.length()) {
            val existing = arr.optJSONObject(i) ?: continue
            if (existing.optString("package") == item.optString("package") &&
                existing.optString("text") == item.optString("text") &&
                kotlin.math.abs(
                    existing.optLong("postedAt") - item.optLong("postedAt")
                ) < 60_000
            ) return
        }

        arr.put(item)

        val trimmed = if (arr.length() > MAX_QUEUED) {
            JSONArray().apply {
                for (i in arr.length() - MAX_QUEUED until arr.length()) put(arr.get(i))
            }
        } else arr

        prefs.edit().putString(KEY, trimmed.toString()).apply()
    }
}
