package com.familyfinance.family_finance

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.provider.OpenableColumns
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.util.zip.Inflater

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.familyfinance/file_import"
    private val NOTIF_CHANNEL = "com.familyfinance/notifications"
    private val NOWBAR_CHANNEL = "com.familyfinance/prayer_nowbar"
    private val WIDGET_CHANNEL = "com.familyfinance/widget"
    private val VOICE_CHANNEL = "com.familyfinance/voice"
    private val BIOMETRIC_CHANNEL = "com.familyfinance/biometrics"
    private val PICK_FILE_REQ = 4091
    private val VOICE_REQ = 4092
    private var pendingResult: MethodChannel.Result? = null
    private var pendingVoiceResult: MethodChannel.Result? = null
    private var sharedTextFromIntent: String? = null
    private var sharedImagePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleIncomingShareIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOWBAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        @Suppress("UNCHECKED_CAST")
                        PrayerNowBar.schedule(this, (call.arguments as? Map<String, Any?>).orEmpty())
                        result.success(null)
                    }
                    "canPromote" -> result.success(PrayerNowBar.canPromote(this))
                    // What Android / the phone currently blocks, for the
                    // "Phone check" card in prayer settings.
                    "status" -> {
                        val nm = getSystemService(android.app.NotificationManager::class.java)
                        val power = getSystemService(android.os.PowerManager::class.java)
                        val alarms = getSystemService(android.app.AlarmManager::class.java)
                        result.success(
                            mapOf(
                                "sdk" to Build.VERSION.SDK_INT,
                                "release" to Build.VERSION.RELEASE,
                                "maker" to Build.MANUFACTURER,
                                "promote" to PrayerNowBar.canPromote(this),
                                "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
                                "exact" to (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()),
                                "unrestricted" to power.isIgnoringBatteryOptimizations(packageName),
                            ),
                        )
                    }
                    "openAppSettings" -> {
                        startActivity(
                            Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "openPromoteSettings" -> {
                        // Settings.ACTION_MANAGE_APP_PROMOTED_NOTIFICATIONS
                        // (Android 16), else the app's notification settings.
                        val pkg = android.provider.Settings.EXTRA_APP_PACKAGE
                        try {
                            startActivity(
                                Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS")
                                    .putExtra(pkg, packageName),
                            )
                        } catch (_: Exception) {
                            startActivity(
                                Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(pkg, packageName),
                            )
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                // DetectionSupport is supplied by the build flavour: the real
                // listener in `detect`, a stub reporting "unavailable" in
                // `standard`. See app/build.gradle.kts for why.
                when (call.method) {
                    "isDetectionAvailable" -> result.success(DetectionSupport.AVAILABLE)
                    "isNotificationAccessGranted" ->
                        result.success(DetectionSupport.isGranted(this))
                    "openNotificationSettings" ->
                        result.success(DetectionSupport.openSettings(this))
                    "drainQueue" -> result.success(DetectionSupport.drainQueue(this))
                    "leaveLockScreen" -> {
                        setOverLockScreen(false)
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "peekQueueSize" -> result.success(DetectionSupport.queueSize(this))
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
                        val sheetTypes = arrayOf(
                            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                            "application/vnd.ms-excel"
                        )
                        val mimeTypes = when (typeFilter) {
                            "csv" -> arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/csv", "*/*")
                            "pdf" -> arrayOf("application/pdf")
                            "md" -> arrayOf("text/markdown", "text/plain", "*/*")
                            "sheet" -> sheetTypes + arrayOf("text/csv", "application/csv", "*/*")
                            else -> arrayOf("application/pdf", "text/csv", "text/markdown", "text/plain") + sheetTypes + arrayOf("*/*")
                        }
                        putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
                    }
                    startActivityForResult(intent, PICK_FILE_REQ)
                }
                "consumeSharedImage" -> {
                    val path = sharedImagePath
                    sharedImagePath = null
                    result.success(path)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val spent = call.argument<String>("todaySpent") ?: "₹0"
                        val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                        val prayerTime = call.argument<String>("prayerTime") ?: "--:--"
                        KinPurseWidgetProvider.updateData(this, spent, prayerName, prayerTime)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listen" -> {
                        if (pendingVoiceResult != null) {
                            result.error("BUSY", "Voice recognition already listening", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                putExtra(
                                    android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                    android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                                )
                                putExtra(
                                    android.speech.RecognizerIntent.EXTRA_PROMPT,
                                    "Speak expense (e.g. '450 petrol HDFC')"
                                )
                                putExtra(android.speech.RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                            }
                            pendingVoiceResult = result
                            startActivityForResult(intent, VOICE_REQ)
                        } catch (e: Exception) {
                            pendingVoiceResult = null
                            result.error("VOICE_UNAVAILABLE", e.localizedMessage ?: "Voice recognition not available", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canAuthenticate" -> {
                        val biometricManager = androidx.biometric.BiometricManager.from(this)
                        val can = biometricManager.canAuthenticate(
                            androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        )
                        result.success(can == androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS)
                    }
                    "authenticate" -> {
                        val title = call.argument<String>("title") ?: "Unlock KinPurse"
                        val subtitle = call.argument<String>("subtitle") ?: "Confirm your biometric or screen lock"
                        val executor = androidx.core.content.ContextCompat.getMainExecutor(this)
                        val promptInfo = androidx.biometric.BiometricPrompt.PromptInfo.Builder()
                            .setTitle(title)
                            .setSubtitle(subtitle)
                            .setAllowedAuthenticators(
                                androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                            )
                            .build()

                        val prompt = androidx.biometric.BiometricPrompt(
                            this,
                            executor,
                            object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authResult: androidx.biometric.BiometricPrompt.AuthenticationResult) {
                                    super.onAuthenticationSucceeded(authResult)
                                    result.success(true)
                                }
                                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                    super.onAuthenticationError(errorCode, errString)
                                    result.success(false)
                                }
                                override fun onAuthenticationFailed() {
                                    super.onAuthenticationFailed()
                                }
                            }
                        )
                        prompt.authenticate(promptInfo)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isPrayerAlert(intent)) setOverLockScreen(true)
        prefetchTextReader()
    }

    // Play Services only fetches the OCR model at install for Play Store
    // installs; a sideloaded APK gets it on first use, so that first shared
    // receipt would fail. Ask for it up front instead. No-op once installed.
    private fun prefetchTextReader() {
        try {
            val reader = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            ModuleInstall.getClient(this)
                .installModules(ModuleInstallRequest.newBuilder().addApi(reader).build())
                .addOnCompleteListener { reader.close() }
        } catch (_: Exception) {
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingShareIntent(intent)
        if (isPrayerAlert(intent)) setOverLockScreen(true)
    }

    // Only the prayer alert may show over the lock screen; closing it turns
    // this off again so the finance screens always need an unlock.
    private fun isPrayerAlert(i: Intent?) =
        i?.getStringExtra("payload")?.startsWith("prayer:") == true

    private fun setOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun handleIncomingShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            sharedTextFromIntent = intent.getStringExtra(Intent.EXTRA_TEXT)
        } else if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("image/") == true) {
            // The read grant on a shared uri ends with this activity, so copy
            // it now; Dart OCRs the copy and deletes it.
            val uri = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            } ?: return
            sharedImagePath = try {
                val out = java.io.File(cacheDir, "shared_bill_${System.currentTimeMillis()}")
                contentResolver.openInputStream(uri)?.use { input ->
                    out.outputStream().use { input.copyTo(it) }
                }
                out.path
            } catch (_: Exception) {
                null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VOICE_REQ) {
            val vRes = pendingVoiceResult
            pendingVoiceResult = null
            if (vRes == null) return
            if (resultCode != Activity.RESULT_OK || data == null) {
                vRes.success(null)
                return
            }
            val matches = data.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)
            val recognized = matches?.firstOrNull() ?: ""
            vRes.success(recognized)
            return
        }

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
            } else if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
                // A workbook is a zip container, so it goes over as bytes and
                // is decoded in Dart rather than read as text here.
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: ByteArray(0)
                res.success(
                    mapOf(
                        "kind" to "xlsx",
                        "fileName" to fileName,
                        "text" to "",
                        "bytes" to bytes,
                        "pageCount" to 1
                    )
                )
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
