import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_battery_level_method_channel.dart';

abstract class FlutterBatteryLevelPlatform extends PlatformInterface {
  /// Constructs a FlutterBatteryLevelPlatform.
  FlutterBatteryLevelPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBatteryLevelPlatform _instance = MethodChannelFlutterBatteryLevel();

  /// The default instance of [FlutterBatteryLevelPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBatteryLevel].
  static FlutterBatteryLevelPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBatteryLevelPlatform] when
  /// they register themselves.
  static set instance(FlutterBatteryLevelPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
