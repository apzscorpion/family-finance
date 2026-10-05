package com.familyfinance.family_finance

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.util.zip.Inflater

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.familyfinance/file_import"
    private val NOTIF_CHANNEL = "com.familyfinance/notifications"
    private val PICK_FILE_REQ = 4091
    private var pendingResult: MethodChannel.Result? = null
    private var sharedTextFromIntent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleIncomingShareIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessGranted" -> result.success(isNotificationAccessGranted())
                    "openNotificationSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(true)
                    }
                    // Hands over everything captured since the last drain and
                    // clears the queue, so a notification is surfaced once.
                    "drainQueue" -> {
                        val prefs = getSharedPreferences(
                            TxnNotificationListenerService.PREFS, Context.MODE_PRIVATE)
                        val raw = prefs.getString(TxnNotificationListenerService.KEY, "[]")
                        prefs.edit().putString(TxnNotificationListenerService.KEY, "[]").apply()
                        result.success(raw)
                    }
                    "peekQueueSize" -> {
                        val prefs = getSharedPreferences(
                            TxnNotificationListenerService.PREFS, Context.MODE_PRIVATE)
                        val raw = prefs.getString(TxnNotificationListenerService.KEY, "[]") ?: "[]"
                        result.success(
                            try { org.json.JSONArray(raw).length() } catch (_: Exception) { 0 })
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocument" -> {
                    if (pendingResult != null) {
                        result.error("BUSY", "File picker already open", null)
                        return@setMethodCallHandler
                    }
                    val typeFilter = call.argument<String>("type") ?: "any"
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        val mimeTypes = when (typeFilter) {
                            "csv" -> arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/csv", "*/*")
                            "pdf" -> arrayOf("application/pdf")
                            "md" -> arrayOf("text/markdown", "text/plain", "*/*")
                            else -> arrayOf("application/pdf", "text/csv", "text/markdown", "text/plain", "*/*")
                        }
                        putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
                    }
                    startActivityForResult(intent, PICK_FILE_REQ)
                }
                "consumeSharedText" -> {
                    val text = sharedTextFromIntent
                    sharedTextFromIntent = null
                    result.success(text)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: "Share Family Invite / Note"
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(sendIntent, title))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Notification access is granted in system settings rather than through a
     * runtime prompt, so it is read back from the enabled-listeners list.
     */
    private fun isNotificationAccessGranted(): Boolean {
        return try {
            val flat = Settings.Secure.getString(
                contentResolver, "enabled_notification_listeners") ?: return false
            val me = ComponentName(this, TxnNotificationListenerService::class.java)
            flat.split(":").any {
                val c = ComponentName.unflattenFromString(it)
                c != null && c.packageName == me.packageName &&
                    c.className == me.className
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingShareIntent(intent)
    }

    private fun handleIncomingShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            sharedTextFromIntent = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FILE_REQ) return

        val res = pendingResult
        pendingResult = null
        if (res == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            res.success(null)
            return
        }

        val uri = data.data!!
        try {
            val fileName = getFileName(uri)
            val lower = fileName.lowercase()
            if (lower.endsWith(".pdf") || contentResolver.getType(uri) == "application/pdf") {
                val pdfMap = readPdfDocument(uri, fileName)
                res.success(pdfMap)
            } else {
                val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: ""
                val ext = when {
                    lower.endsWith(".csv") -> "csv"
                    lower.endsWith(".md") || lower.endsWith(".markdown") -> "md"
                    else -> "txt"
                }
                res.success(
                    mapOf(
                        "kind" to ext,
                        "fileName" to fileName,
                        "text" to text,
                        "pageCount" to 1
                    )
                )
            }
        } catch (e: Exception) {
            res.error("READ_ERR", e.localizedMessage ?: "Could not read file", null)
        }
    }

    private fun getFileName(uri: Uri): String {
        var name = "document"
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) {
                name = cursor.getString(idx) ?: "document"
            }
        }
        return name
    }

    private fun readPdfDocument(uri: Uri, fileName: String): Map<String, Any> {
        val pagesPng = mutableListOf<ByteArray>()
        var pageCount = 0

        contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                pageCount = renderer.pageCount
                val maxRender = pageCount.coerceAtMost(12)
                for (i in 0 until maxRender) {
                    renderer.openPage(i).use { page ->
                        val scale = 2.0f
                        val w = (page.width * scale).toInt().coerceAtLeast(1)
                        val h = (page.height * scale).toInt().coerceAtLeast(1)
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bmp)
                        canvas.drawColor(Color.WHITE)
                        page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val baos = ByteArrayOutputStream()
                        bmp.compress(Bitmap.CompressFormat.PNG, 90, baos)
                        pagesPng.add(baos.toByteArray())
                        bmp.recycle()
                    }
                }
            }
        }

        val rawBytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
        val extractedText = extractTextFromPdfBytes(rawBytes)

        return mapOf(
            "kind" to "pdf",
            "fileName" to fileName,
            "text" to extractedText,
            "pageCount" to pageCount,
            "pagesPng" to pagesPng
        )
    }

    private fun extractTextFromPdfBytes(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        val sb = StringBuilder()
        val latin1 = String(bytes, Charset.forName("ISO-8859-1"))

        // 1. Decompress FlateDecode streams and extract text blocks
        val streamRegex = Regex("stream\\r?\\n([\\s\\S]*?)\\r?\\nendstream")
        for (match in streamRegex.findAll(latin1)) {
            val streamContent = match.groupValues[1]
            val streamBytes = streamContent.toByteArray(Charset.forName("ISO-8859-1"))
            val decoded = tryInflate(streamBytes) ?: streamContent
            extractPdfTextOperators(decoded, sb)
        }

        // 2. Fallback: also scan top-level uncompressed text operators
        if (sb.length < 20) {
            extractPdfTextOperators(latin1, sb)
        }

        val cleaned = sb.toString()
            .replace(Regex("[ \\t]+"), " ")
            .replace(Regex("\\n{3,}"), "\n\n")
            .trim()

        return cleaned
    }

    private fun tryInflate(data: ByteArray): String? {
        return try {
            val inflater = Inflater()
            inflater.setInput(data)
            val out = ByteArrayOutputStream()
            val buf = ByteArray(4096)
            while (!inflater.finished() && !inflater.needsInput()) {
                val count = inflater.inflate(buf)
                if (count <= 0) break
                out.write(buf, 0, count)
            }
            inflater.end()
            if (out.size() > 0) String(out.toByteArray(), Charset.forName("UTF-8")) else null
        } catch (_: Exception) {
            null
        }
    }

    private fun extractPdfTextOperators(source: String, out: StringBuilder) {
        val btEtRegex = Regex("BT([\\s\\S]*?)ET")
        val parenRegex = Regex("\\(([^()\\\\]*(?:\\\\.[^()\\\\]*)*)\\)")
        for (block in btEtRegex.findAll(source)) {
            val body = block.groupValues[1]
            var lineAdded = false
            for (p in parenRegex.findAll(body)) {
                val raw = p.groupValues[1]
                    .replace("\\n", "\n")
                    .replace("\\r", "")
                    .replace("\\t", " ")
                    .replace("\\(", "(")
                    .replace("\\)", ")")
                    .replace("\\\\", "\\")
                if (raw.any { it.isLetterOrDigit() }) {
                    out.append(raw).append(" ")
                    lineAdded = true
                }
            }
            if (lineAdded) out.append("\n")
        }
    }
}
