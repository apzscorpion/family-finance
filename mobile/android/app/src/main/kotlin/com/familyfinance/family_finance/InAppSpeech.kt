package com.familyfinance.family_finance

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel

/**
 * Speech recognition inside the app, without the system popup: Indian
 * English, a longer pause before it decides you've finished, live partial
 * text and loudness back to Dart, and (Android 13+) bias towards the words
 * the app expects (account, category and family names).
 *
 * Partial text and levels go to Dart as "partial" / "level" calls on
 * [channel]; the final text resolves the pending `listen` call.
 */
class InAppSpeech(private val context: Context, private val channel: MethodChannel) {
    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null
    private var lastLevelAt = 0L

    val available: Boolean get() = SpeechRecognizer.isRecognitionAvailable(context)

    /** [mixed]: Malayalam and English in one sentence; Android 14+ switches between them. */
    fun listen(lang: String, hints: List<String>, mixed: Boolean, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "Already listening", null)
            return
        }
        pending = result
        recognizer?.destroy()
        val r = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {
                val now = System.currentTimeMillis()
                if (now - lastLevelAt < 80) return
                lastLevelAt = now
                channel.invokeMethod("level", rmsdB.toDouble())
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!text.isNullOrBlank()) channel.invokeMethod("partial", text)
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                finish { it.success(text) }
            }
            override fun onError(error: Int) {
                // Silence or nothing understood is an empty answer, not a failure.
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> finish { it.success(null) }
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                        finish { it.error("NO_PERMISSION", "Microphone not allowed", null) }
                    else -> finish { it.error("SPEECH_$error", "Speech recognition failed ($error)", null) }
                }
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            // Wait longer before deciding the sentence is over.
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1500L)
            if (mixed && Build.VERSION.SDK_INT >= 34) {
                putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_DETECTION, true)
                putStringArrayListExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_DETECTION_ALLOWED_LANGUAGES,
                    arrayListOf("ml-IN", "en-IN")
                )
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH,
                    RecognizerIntent.LANGUAGE_SWITCH_BALANCED
                )
            }
            if (Build.VERSION.SDK_INT >= 33 && hints.isNotEmpty()) {
                putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(hints.take(100)))
            }
        }
        try {
            r.startListening(intent)
        } catch (e: Exception) {
            finish { it.error("VOICE_UNAVAILABLE", e.localizedMessage ?: "Speech not available", null) }
        }
    }

    fun stop() {
        recognizer?.stopListening()
    }

    fun cancel() {
        recognizer?.cancel()
        finish { it.success(null) }
    }

    fun destroy() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        val p = pending ?: return
        pending = null
        reply(p)
    }
}
