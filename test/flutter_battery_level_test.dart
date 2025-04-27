import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_battery_level/flutter_battery_level.dart';
import 'package:flutter_battery_level/flutter_battery_level_platform_interface.dart';
import 'package:flutter_battery_level/flutter_battery_level_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBatteryLevelPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBatteryLevelPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterBatteryLevelPlatform initialPlatform = FlutterBatteryLevelPlatform.instance;

  test('$MethodChannelFlutterBatteryLevel is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBatteryLevel>());
  });

  test('getPlatformVersion', () async {
    FlutterBatteryLevel flutterBatteryLevelPlugin = FlutterBatteryLevel();
    MockFlutterBatteryLevelPlatform fakePlatform = MockFlutterBatteryLevelPlatform();
    FlutterBatteryLevelPlatform.instance = fakePlatform;

    expect(await flutterBatteryLevelPlugin.getPlatformVersion(), '42');
  });
}
