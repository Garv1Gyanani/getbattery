import 'dart:async';
import 'dart:io' show Platform; // For platform-specific checks if needed

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// --- NEW: Enum for Battery State ---
/// Represents the charging state of the device's battery.
enum BatteryState {
  /// The device is charging.
  charging,

  /// The device is discharging (unplugged).
  discharging,

  /// The device is fully charged.
  full,

  /// The battery state is unknown.
  unknown,
}

// --- NEW: Class to hold combined battery info ---
/// Represents the combined battery level and state.
class BatteryInfo {
  final int level;
  final BatteryState state;

  BatteryInfo(this.level, this.state);

  @override
  String toString() => 'BatteryInfo(level: $level, state: $state)';
}

class FlutterBatteryLevel {
  // Define the communication channels
  static const MethodChannel _methodChannel = MethodChannel(
      'samples.flutter.dev/battery_method'); // Renamed for clarity
  // --- NEW: Event Channel for stream ---
  static const EventChannel _eventChannel = EventChannel(
      'samples.flutter.dev/battery_event'); // New channel for events

  // --- Keep existing getBatteryLevel ---
  /// Returns the current battery level as an integer percentage.
  ///
  /// Returns -1 if the battery level cannot be determined.
  /// Throws a [PlatformException] if the platform call fails.
  static Future<int> getBatteryLevel() async {
    try {
      final int? result =
          await _methodChannel.invokeMethod<int>('getBatteryLevel');
      return result ?? -1;
    } on PlatformException catch (e) {
      debugPrint("Failed to get battery level: '${e.message}'.");
      return -1;
    }
  }

  // --- NEW: Get Battery State ---
  /// Returns the current charging state of the battery.
  static Future<BatteryState> getBatteryState() async {
    try {
      final String? state =
          await _methodChannel.invokeMethod<String>('getBatteryState');
      switch (state) {
        case 'charging':
          return BatteryState.charging;
        case 'discharging':
          return BatteryState.discharging;
        case 'full':
          return BatteryState.full;
        default:
          return BatteryState.unknown;
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get battery state: '${e.message}'.");
      return BatteryState.unknown;
    }
  }

  // --- NEW: Check Low Power Mode ---
  /// Returns true if the device is currently in low power mode (battery saver).
  static Future<bool> isInLowPowerMode() async {
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('isInLowPowerMode');
      return result ?? false; // Default to false if null or error
    } on PlatformException catch (e) {
      debugPrint("Failed to check low power mode: '${e.message}'.");
      return false; // Assume not in low power mode on error
    }
  }

  // --- NEW: Stream for Battery Changes ---
  static Stream<BatteryInfo>? _batteryInfoStream;

  /// Provides a stream of [BatteryInfo] updates.
  ///
  /// Emits a new [BatteryInfo] object whenever the battery level or
  /// charging state changes.
  /// Errors are reported through the stream's error channel.
  static Stream<BatteryInfo> get onBatteryStateChanged {
    _batteryInfoStream ??=
        _eventChannel.receiveBroadcastStream().map((dynamic event) {
      // Raw event is likely a Map
      if (event is Map) {
        final level = event['level'] as int? ?? -1;
        final statusString = event['status'] as String?;
        BatteryState state;
        switch (statusString) {
          case 'charging':
            state = BatteryState.charging;
            break;
          case 'discharging':
            state = BatteryState.discharging;
            break;
          case 'full':
            state = BatteryState.full;
            break;
          default:
            state = BatteryState.unknown;
        }
        return BatteryInfo(level, state);
      } else {
        // Handle unexpected event format
        return BatteryInfo(-1, BatteryState.unknown);
      }
    });
    return _batteryInfoStream!;
  }
}
