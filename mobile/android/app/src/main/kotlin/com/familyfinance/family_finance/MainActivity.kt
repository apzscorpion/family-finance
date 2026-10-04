package com.familyfinance.family_finance

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.familyfinance/notifications"
    private val EVENT_CHANNEL = "com.familyfinance/transaction_stream"
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    val enabled = Settings.Secure.getString(
                        contentResolver,
                        "enabled_notification_listeners"
                    )
                    val isGranted = enabled?.contains(packageName) == true
                    result.success(isGranted)
                }
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            intent ?: return
                            val data = mapOf(
                                "amount" to intent.getDoubleExtra("amount", 0.0),
                                "type" to (intent.getStringExtra("type") ?: "expense"),
                                "bank" to (intent.getStringExtra("bank") ?: "Bank"),
                                "account" to (intent.getStringExtra("account") ?: ""),
                                "upi_ref" to (intent.getStringExtra("upi_ref") ?: ""),
                                "snippet" to (intent.getStringExtra("snippet") ?: ""),
                                "timestamp" to intent.getLongExtra("timestamp", System.currentTimeMillis()),
                            )
                            eventSink?.success(data)
                        }
                    }
                    val filter = IntentFilter("com.familyfinance.TRANSACTION_DETECTED")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                    eventSink = null
                }
            }
        )
    }
}
