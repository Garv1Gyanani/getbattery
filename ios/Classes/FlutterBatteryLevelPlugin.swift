import Flutter
import UIKit

public class SwiftFlutterBatteryLevelPlugin: NSObject, FlutterPlugin, FlutterStreamHandler { // NEW: Conform to FlutterStreamHandler

    // --- NEW: Variables for Event Stream ---
    private var eventSink: FlutterEventSink?
    // Keep track if monitoring is enabled by us
    private var isMonitoringEnabledByPlugin = false

    // Registration for both Method and Event Channels
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method Channel Setup
        let methodChannel = FlutterMethodChannel(name: "samples.flutter.dev/battery_method", binaryMessenger: registrar.messenger())

        // Event Channel Setup
        let eventChannel = FlutterEventChannel(name: "samples.flutter.dev/battery_event", binaryMessenger: registrar.messenger())

        let instance = SwiftFlutterBatteryLevelPlugin()

        // Set delegate/handler for both channels
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance) // 'instance' handles stream setup/teardown

        // Optional: Application lifecycle observer if needed (e.g., to resume monitoring)
        // registrar.addApplicationDelegate(instance)
         print("SwiftFlutterBatteryLevelPlugin registered")
    }

    // --- MethodCall Handler ---
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
         print("Swift handle called for method: \(call.method)")
        switch call.method {
        case "getBatteryLevel":
            receiveBatteryLevel(result: result)
        // --- NEW: Handle getBatteryState ---
        case "getBatteryState":
            receiveBatteryState(result: result)
        // --- NEW: Handle isInLowPowerMode ---
        case "isInLowPowerMode":
             receiveLowPowerModeStatus(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // --- FlutterStreamHandler Implementation ---

    // Called when the first listener subscribes
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("Swift onListen called")
        self.eventSink = events
        enableBatteryMonitoring() // Ensure monitoring is on

        // Add observers for battery changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onBatteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onBatteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil)

        // --- NEW: Send initial state immediately ---
        sendBatteryUpdate()

        return nil // No error
    }

    // Called when the last listener cancels
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("Swift onCancel called")
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
        self.eventSink = nil
        disableBatteryMonitoringIfNeeded() // Optionally disable if we were the only user
        return nil // No error
    }


    // --- Notification Handlers ---
    @objc private func onBatteryLevelDidChange(notification: NSNotification) {
         print("Swift onBatteryLevelDidChange notification")
         sendBatteryUpdate()
    }

    @objc private func onBatteryStateDidChange(notification: NSNotification) {
         print("Swift onBatteryStateDidChange notification")
         sendBatteryUpdate()
    }

    // --- Helper Methods ---

    private func enableBatteryMonitoring() {
        // Only enable if it's not already enabled
        if !UIDevice.current.isBatteryMonitoringEnabled {
            print("Swift enabling battery monitoring.")
            UIDevice.current.isBatteryMonitoringEnabled = true
            isMonitoringEnabledByPlugin = true // Track that we enabled it
        } else {
             print("Swift battery monitoring was already enabled.")
             isMonitoringEnabledByPlugin = false // Assume someone else enabled it
        }
    }

    private func disableBatteryMonitoringIfNeeded() {
        // Only disable if we were the one who enabled it and no one is listening
        if isMonitoringEnabledByPlugin && eventSink == nil {
             print("Swift disabling battery monitoring (plugin initiated).")
             UIDevice.current.isBatteryMonitoringEnabled = false
             isMonitoringEnabledByPlugin = false
        } else {
             print("Swift keeping battery monitoring enabled (either wasn't plugin initiated or still listening).")
        }
    }

    // Get Battery Level (existing modified slightly for consistency)
    private func receiveBatteryLevel(result: FlutterResult) {
         enableBatteryMonitoring() // Ensure monitoring is on
        let device = UIDevice.current
        if device.batteryState == .unknown {
            result(FlutterError(code: "UNAVAILABLE",
                                message: "Battery level not available (state is unknown).",
                                details: nil))
        } else {
            let level = Int(device.batteryLevel * 100)
            result(level < 0 ? -1 : level) // Return -1 if batteryLevel is negative (e.g., -1.0)
        }
         // Don't disable monitoring here if called directly
    }

    // --- NEW: Get Battery State ---
    private func receiveBatteryState(result: FlutterResult) {
        enableBatteryMonitoring() // Ensure monitoring is on
        let device = UIDevice.current
        result(mapBatteryState(device.batteryState)) // Use helper to map enum to string
         // Don't disable monitoring here
    }

     // --- NEW: Get Low Power Mode ---
     private func receiveLowPowerModeStatus(result: FlutterResult) {
         // No need to enable battery monitoring for this
         let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
         result(lowPowerMode)
     }

    // --- NEW: Helper to map iOS state to String ---
    private func mapBatteryState(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging:
            return "charging"
        case .full:
            return "full"
        case .unplugged: // Discharging
            return "discharging"
        case .unknown:
            fallthrough // Treat unknown the same
        @unknown default:
            return "unknown"
        }
    }

     // --- NEW: Send Battery Update Helper ---
     private func sendBatteryUpdate() {
        guard let sink = eventSink else {
             print("Swift sendBatteryUpdate - eventSink is nil, cannot send.")
            return
        }
         enableBatteryMonitoring() // Make sure it's still enabled
         let device = UIDevice.current

         // Check if state is valid before proceeding
         guard device.batteryState != .unknown else {
             print("Swift sendBatteryUpdate - state is unknown, sending error/default.")
             let infoMap: [String: Any] = [
                 "level": -1, // Indicate error/unknown level
                 "status": mapBatteryState(device.batteryState) // Should be "unknown"
             ]
             sink(infoMap)
             // Optionally send an error instead:
             // sink(FlutterError(code: "UNAVAILABLE", message: "Battery state is unknown.", details: nil))
             return
         }

         let level = Int(device.batteryLevel * 100)
         let mappedState = mapBatteryState(device.batteryState)

         let infoMap: [String: Any] = [
             "level": level < 0 ? -1 : level, // Handle potential -1 level
             "status": mappedState
         ]
         print("Swift sending battery update: \(infoMap)")
         sink(infoMap) // Send the map
    }
}