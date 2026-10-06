package com.familyfinance.family_finance

import android.app.Activity
import android.content.Context

/**
 * Stub for the `standard` flavour, which ships no notification listener.
 *
 * This build declares no notification permission and contains no listener
 * class, which is what lets it install from a browser or file manager. Every
 * entry point reports the feature as unavailable so the UI can say so plainly
 * rather than offering a switch that could never turn on.
 */
object DetectionSupport {

    const val AVAILABLE = false

    fun isGranted(context: Context): Boolean = false

    fun openSettings(activity: Activity): Boolean = false

    fun drainQueue(context: Context): String = "[]"

    fun queueSize(context: Context): Int = 0
}
