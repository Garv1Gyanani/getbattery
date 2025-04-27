package com.example.flutter_battery_level // Adjust if your package is different

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.PowerManager // Import PowerManager

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel // Import EventChannel
import io.flutter.plugin.common.BinaryMessenger // Import BinaryMessenger
import android.content.BroadcastReceiver // Import BroadcastReceiver
import io.flutter.Log // Use Flutter's Log for better debugging

/** FlutterBatteryLevelPlugin */
// --- NEW: Implement EventChannel.StreamHandler ---
class FlutterBatteryLevelPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel // NEW: Event Channel instance
    private lateinit var context: Context
    private var NATIVE_TAG = "FlutterBatteryPlugin" // For logging

    // --- NEW: Variables for Event Stream ---
    private var chargingStateReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        val messenger = flutterPluginBinding.binaryMessenger

        // Setup MethodChannel
        methodChannel = MethodChannel(messenger, "samples.flutter.dev/battery_method")
        methodChannel.setMethodCallHandler(this)

        // --- NEW: Setup EventChannel ---
        eventChannel = EventChannel(messenger, "samples.flutter.dev/battery_event")
        eventChannel.setStreamHandler(this) // 'this' plugin handles stream setup/teardown

        Log.d(NATIVE_TAG, "Plugin attached to engine.")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null) // Clean up event channel handler
        // --- NEW: Ensure receiver is unregistered ---
        unregisterChargingStateReceiver()
        context = binding.applicationContext // Reset context just in case, though likely not needed
        Log.d(NATIVE_TAG, "Plugin detached from engine.")
    }

    // --- MethodCallHandler ---
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getBatteryLevel" -> {
                val batteryLevel = getBatteryLevel()
                if (batteryLevel != -1) {
                    result.success(batteryLevel)
                } else {
                    result.error("UNAVAILABLE", "Battery level not available.", null)
                }
            }
            // --- NEW: Handle getBatteryState ---
            "getBatteryState" -> {
                val batteryState = getBatteryState()
                result.success(batteryState) // Always returns a string state
            }
            // --- NEW: Handle isInLowPowerMode ---
            "isInLowPowerMode" -> {
                val lowPowerMode = isInLowPowerMode()
                result.success(lowPowerMode)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // --- EventChannel.StreamHandler Implementation ---
    // Called when the first listener subscribes to the stream
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(NATIVE_TAG, "EventChannel onListen called.")
        eventSink = events // Store the sink to send events
        registerChargingStateReceiver() // Start listening to OS broadcasts
        // --- NEW: Send initial state immediately ---
        sendBatteryUpdate()
    }

    // Called when the last listener cancels their subscription
    override fun onCancel(arguments: Any?) {
        Log.d(NATIVE_TAG, "EventChannel onCancel called.")
        unregisterChargingStateReceiver() // Stop listening to OS broadcasts
        eventSink = null // Clear the sink
    }

    // --- Helper Methods ---

    private fun getBatteryLevel(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    // --- NEW: Get Battery State Helper ---
    private fun getBatteryState(): String {
        val intent = ContextWrapper(context.applicationContext).registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        if (intent == null) {
            Log.w(NATIVE_TAG, "Battery intent was null, cannot get state.")
            return "unknown" // Return "unknown" if intent is null
        }
        val status: Int = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)

        return when (status) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            // BATTERY_STATUS_DISCHARGING and BATTERY_STATUS_NOT_CHARGING map to "discharging"
            BatteryManager.BATTERY_STATUS_DISCHARGING, BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "discharging"
            else -> "unknown" // Includes BATTERY_STATUS_UNKNOWN
        }
    }

     // --- NEW: Check Low Power Mode Helper ---
     private fun isInLowPowerMode(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager?
        // isPowerSaveMode requires API 21 (Lollipop)
        return powerManager?.isPowerSaveMode ?: false // Return false if powerManager is null or API < 21
    }


    // --- NEW: Broadcast Receiver Logic ---
    private fun createChargingStateReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                 Log.v(NATIVE_TAG, "BroadcastReceiver onReceive - Action: ${intent.action}")
                 // --- NEW: Send combined level and state ---
                 sendBatteryUpdate()
            }
        }
    }

     // --- NEW: Send Battery Update Helper ---
     private fun sendBatteryUpdate() {
        if (eventSink == null) {
            Log.w(NATIVE_TAG, "Attempted to send update but eventSink is null.")
            return
        }
         try {
            val level = getBatteryLevel()
            val state = getBatteryState()
            val infoMap = mapOf(
                "level" to level,
                "status" to state
            )
            Log.v(NATIVE_TAG, "Sending battery update: $infoMap")
            eventSink?.success(infoMap)
        } catch (e: Exception) {
            Log.e(NATIVE_TAG, "Error sending battery update", e)
            eventSink?.error("UPDATE_ERROR", "Failed to get battery info: ${e.message}", null)
        }
    }


    private fun registerChargingStateReceiver() {
        if (chargingStateReceiver == null) {
            val intentFilter = IntentFilter()
            // Listen for both level and state changes
            intentFilter.addAction(Intent.ACTION_BATTERY_CHANGED)
            // Note: ACTION_POWER_SAVE_MODE_CHANGED exists (API 21+) but ACTION_BATTERY_CHANGED
            // usually fires frequently enough when plugging/unplugging anyway.
            // We get the low power mode state on demand via the method channel.
            chargingStateReceiver = createChargingStateReceiver(eventSink)
            Log.d(NATIVE_TAG, "Registering BroadcastReceiver.")
            // Register the receiver
             if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU) {
                 // For Android 13 (API 33) and above, specify receiver export behavior
                 context.registerReceiver(
                     chargingStateReceiver,
                     intentFilter,
                     Context.RECEIVER_NOT_EXPORTED // Receiver is for internal app use only
                 )
             } else {
                 // For older versions
                 context.registerReceiver(chargingStateReceiver, intentFilter)
             }
        } else {
             Log.w(NATIVE_TAG, "Attempted to register receiver but it already exists.")
        }
    }

    private fun unregisterChargingStateReceiver() {
        if (chargingStateReceiver != null) {
            Log.d(NATIVE_TAG, "Unregistering BroadcastReceiver.")
            try {
                 context.unregisterReceiver(chargingStateReceiver)
            } catch (e: IllegalArgumentException) {
                // Can happen if receiver was somehow already unregistered
                Log.w(NATIVE_TAG, "Receiver already unregistered?", e)
            }
            chargingStateReceiver = null
        } else {
            Log.w(NATIVE_TAG, "Attempted to unregister receiver but it was null.")
        }
    }
}