import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_battery_level_platform_interface.dart';

/// An implementation of [FlutterBatteryLevelPlatform] that uses method channels.
class MethodChannelFlutterBatteryLevel extends FlutterBatteryLevelPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_battery_level');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
