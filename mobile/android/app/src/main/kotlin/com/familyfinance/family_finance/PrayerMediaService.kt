package com.familyfinance.family_finance

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder

/**
 * The prayer island as a "now playing" media card, for phones that keep
 * other apps' Live Updates out of the Now Bar (Samsung One UI without the
 * developer option) but show every app's media card there.
 *
 * A short-lived foreground service holds the MediaSession, so the card
 * isn't dropped when the process is trimmed. No audio is ever played.
 * PrayerNowBar decides when it runs; the buttons go to the same
 * "prayed" / "not yet" handling as the normal notification.
 */
class PrayerMediaService : Service() {
    private var session: MediaSession? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent.getStringExtra("title").orEmpty()
        val text = intent.getStringExtra("text").orEmpty()
        val key = intent.getStringExtra("key")
        val start = intent.getLongExtra("start", 0L)
        val end = intent.getLongExtra("end", 0L)
        val channel = intent.getStringExtra("channel").orEmpty()
        val alert = intent.getBooleanExtra("alert", false)

        val s = session ?: MediaSession(this, "KinPursePrayer").also {
            it.setCallback(callback)
            session = it
        }
        s.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, text)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, "KinPurse")
                // The progress bar fills as the prayer time runs out.
                .putLong(MediaMetadata.METADATA_KEY_DURATION, (end - start).coerceAtLeast(1L))
                .putBitmap(
                    MediaMetadata.METADATA_KEY_ALBUM_ART,
                    BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher),
                )
                .build(),
        )
        val state = PlaybackState.Builder()
            .setState(
                PlaybackState.STATE_PLAYING,
                (System.currentTimeMillis() - start).coerceAtLeast(0L),
                1f,
            )
            // Pause is offered so a headphone press means "Not yet".
            .setActions(PlaybackState.ACTION_PAUSE)
        if (key != null) {
            state.addCustomAction(ACTION_DONE, intent.getStringExtra("done") ?: "Prayed", R.drawable.ic_prayed)
            state.addCustomAction(ACTION_LATER, intent.getStringExtra("later") ?: "Later", R.drawable.ic_not_yet)
        }
        s.setPlaybackState(state.build())
        s.isActive = true

        val builder = Notification.Builder(this, channel)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 0,
                    Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        val style = Notification.MediaStyle().setMediaSession(s.sessionToken)
        if (key != null) {
            builder.addAction(
                Notification.Action.Builder(
                    android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_prayed),
                    intent.getStringExtra("done") ?: "Prayed",
                    PrayerNowBar.actionIntent(this, PrayerNowBar.ACTION_DONE, key, 11),
                ).build(),
            )
            builder.addAction(
                Notification.Action.Builder(
                    android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_not_yet),
                    intent.getStringExtra("later") ?: "Later",
                    PrayerNowBar.actionIntent(this, PrayerNowBar.ACTION_LATER, key, 12),
                ).build(),
            )
            style.setShowActionsInCompactView(0, 1)
        }
        builder.setStyle(style)
        val notification = builder.build()
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    PrayerNowBar.MEDIA_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(PrayerNowBar.MEDIA_ID, notification)
            }
        } catch (_: Exception) {
            stopSelf()
        }
        currentKey = key
        return START_NOT_STICKY
    }

    private var currentKey: String? = null

    private val callback = object : MediaSession.Callback() {
        override fun onPause() {
            PrayerNowBar.later(this@PrayerMediaService)
        }

        override fun onCustomAction(action: String, extras: android.os.Bundle?) {
            when (action) {
                ACTION_DONE -> currentKey?.let { PrayerNowBar.done(this@PrayerMediaService, it) }
                ACTION_LATER -> PrayerNowBar.later(this@PrayerMediaService)
            }
        }
    }

    override fun onDestroy() {
        session?.isActive = false
        session?.release()
        session = null
        super.onDestroy()
    }

    companion object {
        private const val ACTION_DONE = "prayed"
        private const val ACTION_LATER = "not_yet"

        /** Shows or updates the media card. False if Android refused. */
        fun show(ctx: Context, extras: Intent.() -> Unit): Boolean = try {
            val intent = Intent(ctx, PrayerMediaService::class.java).apply(extras)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent) else ctx.startService(intent)
            true
        } catch (_: Exception) {
            // e.g. started from the background without an exemption.
            false
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, PrayerMediaService::class.java))
        }
    }
}
