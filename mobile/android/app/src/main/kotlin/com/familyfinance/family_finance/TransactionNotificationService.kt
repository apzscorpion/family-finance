package com.familyfinance.family_finance

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.util.Log

class TransactionNotificationService : NotificationListenerService() {

    companion object {
        private const val TAG = "TxnNotifService"
        val BANK_PACKAGES = setOf(
            "com.csam.icici.bank.imobile",
            "com.hdfcbank.hdfcquickbank",
            "com.sbi.lotusintouch",
            "com.bankofbaroda.mconnect",
            "com.axis.mobile",
            "com.kotak.mobile.banking",
            "com.msf.kbank.mobile",
            "com.idbibank.abhay_card",
            "com.canaaboretum.caboretum",
            "com.ucobank",
            "com.android.messaging",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
        )

        val BANK_SENDER_PATTERNS = listOf(
            "hdfc", "icici", "sbi", "axis", "kotak", "bob", "canara",
            "pnb", "idbi", "uco", "union", "indian", "indus",
            "federal", "rbl", "yes bank", "paytm", "phonepe",
            "gpay", "cred",
        )

        val DEBIT_PATTERNS = listOf(
            Regex("(?i)(?:debited|spent|paid|deducted|withdrawn|purchase).*?(?:rs\\.?|inr|₹)\\s*([\\d,]+\\.?\\d*)", RegexOption.DOT_MATCHES_ALL),
            Regex("(?i)(?:rs\\.?|inr|₹)\\s*([\\d,]+\\.?\\d*).*?(?:debited|spent|paid|deducted|withdrawn)", RegexOption.DOT_MATCHES_ALL),
        )

        val CREDIT_PATTERNS = listOf(
            Regex("(?i)(?:credited|received|deposited|refund).*?(?:rs\\.?|inr|₹)\\s*([\\d,]+\\.?\\d*)", RegexOption.DOT_MATCHES_ALL),
            Regex("(?i)(?:rs\\.?|inr|₹)\\s*([\\d,]+\\.?\\d*).*?(?:credited|received|deposited|refund)", RegexOption.DOT_MATCHES_ALL),
        )

        val ACCOUNT_PATTERN = Regex("(?i)(?:a/c|acct|account).*?(?:xx|x{2,}|\\*{2,})(\\d{4})")
        val UPI_PATTERN = Regex("(?i)upi[:/]([\\w.@]+)")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val packageName = sbn.packageName ?: return
        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

        val content = if (bigText.isNotEmpty()) bigText else text
        if (content.isEmpty()) return

        val fullText = "$title $content".lowercase()

        val isBankApp = BANK_PACKAGES.any { packageName.contains(it, ignoreCase = true) }
        val hasBankKeyword = BANK_SENDER_PATTERNS.any { fullText.contains(it) }

        if (!isBankApp && !hasBankKeyword) return

        var amount: Double? = null
        var txnType = "expense"

        for (pattern in CREDIT_PATTERNS) {
            val match = pattern.find(content)
            if (match != null) {
                amount = match.groupValues[1].replace(",", "").toDoubleOrNull()
                txnType = "income"
                break
            }
        }

        if (amount == null) {
            for (pattern in DEBIT_PATTERNS) {
                val match = pattern.find(content)
                if (match != null) {
                    amount = match.groupValues[1].replace(",", "").toDoubleOrNull()
                    txnType = "expense"
                    break
                }
            }
        }

        if (amount == null || amount <= 0) return

        val accountMatch = ACCOUNT_PATTERN.find(content)
        val accountLast4 = accountMatch?.groupValues?.getOrNull(1) ?: ""

        val upiMatch = UPI_PATTERN.find(content)
        val upiRef = upiMatch?.groupValues?.getOrNull(1) ?: ""

        val bankName = when {
            fullText.contains("hdfc") -> "HDFC Bank"
            fullText.contains("icici") -> "ICICI Bank"
            fullText.contains("sbi") || fullText.contains("state bank") -> "SBI"
            fullText.contains("axis") -> "Axis Bank"
            fullText.contains("kotak") -> "Kotak Bank"
            fullText.contains("bob") || fullText.contains("baroda") -> "Bank of Baroda"
            fullText.contains("canara") -> "Canara Bank"
            fullText.contains("pnb") || fullText.contains("punjab") -> "PNB"
            fullText.contains("idbi") -> "IDBI Bank"
            fullText.contains("paytm") -> "Paytm"
            fullText.contains("phonepe") -> "PhonePe"
            fullText.contains("gpay") || fullText.contains("google pay") -> "Google Pay"
            else -> "Bank"
        }

        val snippet = if (content.length > 120) content.substring(0, 120) + "…" else content

        Log.d(TAG, "Detected $txnType: ₹$amount from $bankName (A/c: $accountLast4)")

        val intent = Intent("com.familyfinance.TRANSACTION_DETECTED")
        intent.putExtra("amount", amount)
        intent.putExtra("type", txnType)
        intent.putExtra("bank", bankName)
        intent.putExtra("account", accountLast4)
        intent.putExtra("upi_ref", upiRef)
        intent.putExtra("snippet", snippet)
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
    }
}
