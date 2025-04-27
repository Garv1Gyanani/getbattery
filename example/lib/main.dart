import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
// Import the plugin's main file
import 'package:flutter_battery_level/flutter_battery_level.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Plugin Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // State variables
  int _batteryLevel = -1;
  BatteryState _batteryState = BatteryState.unknown;
  bool _isInLowPowerMode = false;
  String _lastError = '';

  // --- NEW: Stream Subscription ---
  StreamSubscription<BatteryInfo>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    // Get initial values
    _getInitialBatteryInfo();
    // --- NEW: Listen to stream ---
    _listenToBatteryChanges();
  }

  @override
  void dispose() {
    // --- NEW: Cancel subscription ---
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  // --- NEW: Listen to the stream ---
  void _listenToBatteryChanges() {
    // Clear previous subscription if any
    _batteryStateSubscription?.cancel();

    _batteryStateSubscription = FlutterBatteryLevel.onBatteryStateChanged
        .listen((BatteryInfo batteryInfo) {
      // Update state from stream events
      if (mounted) {
        setState(() {
          _batteryLevel = batteryInfo.level;
          _batteryState = batteryInfo.state;
          _lastError = ''; // Clear error on successful update
        });
      }
    }, onError: (error) {
      // Handle stream errors
      if (mounted) {
        setState(() {
          _lastError = 'Stream Error: ${error.toString()}';
          // Optionally reset state or leave as is
          // _batteryLevel = -1;
          // _batteryState = BatteryState.unknown;
        });
      }
      debugPrint("Battery Stream Error: $error");
      // Consider restarting the listener after a delay if needed
      // Future.delayed(const Duration(seconds: 5), _listenToBatteryChanges);
    }, cancelOnError: false); // Keep listening after errors if possible
  }

  // Get all initial values on startup
  Future<void> _getInitialBatteryInfo() async {
    _getBatteryLevel();
    _getBatteryState();
    _checkLowPowerMode();
  }

  // Method to get battery level
  Future<void> _getBatteryLevel() async {
    int batteryLevel;
    try {
      batteryLevel = await FlutterBatteryLevel.getBatteryLevel();
    } on PlatformException catch (e) {
      batteryLevel = -1;
      debugPrint("Failed to get battery level: '${e.message}'.");
      if (mounted) setState(() => _lastError = "Failed level: ${e.message}");
    }
    if (mounted) {
      setState(() => _batteryLevel = batteryLevel);
    }
  }

  // --- NEW: Method to get battery state ---
  Future<void> _getBatteryState() async {
    BatteryState batteryState;
    try {
      batteryState = await FlutterBatteryLevel.getBatteryState();
    } on PlatformException catch (e) {
      batteryState = BatteryState.unknown;
      debugPrint("Failed to get battery state: '${e.message}'.");
      if (mounted) setState(() => _lastError = "Failed state: ${e.message}");
    }
    if (mounted) {
      setState(() => _batteryState = batteryState);
    }
  }

  // --- NEW: Method to check low power mode ---
  Future<void> _checkLowPowerMode() async {
    bool isInLowPowerMode;
    try {
      isInLowPowerMode = await FlutterBatteryLevel.isInLowPowerMode();
    } on PlatformException catch (e) {
      isInLowPowerMode = false; // Assume false on error
      debugPrint("Failed to check low power mode: '${e.message}'.");
      if (mounted)
        setState(() => _lastError = "Failed low power: ${e.message}");
    }
    if (mounted) {
      setState(() => _isInLowPowerMode = isInLowPowerMode);
    }
  }

  // Helper to format battery state enum for display
  String _formatBatteryState(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Plugin Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('Listening to Battery Stream:',
                  style: textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(
                  _batteryLevel == -1 ? 'Level: N/A' : 'Level: $_batteryLevel%',
                  style: textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text('State: ${_formatBatteryState(_batteryState)}',
                  style: textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text('Low Power Mode: ${_isInLowPowerMode ? "ON" : "OFF"}',
                  style: textTheme.headlineSmall),
              const SizedBox(height: 20),
              if (_lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text('Last Error: $_lastError',
                      style: const TextStyle(color: Colors.red)),
                ),
              Text('Manual Refresh:', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                // Use Wrap for better layout on small screens
                spacing: 8.0, // gap between adjacent chips
                runSpacing: 4.0, // gap between lines
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _getBatteryLevel,
                    child: const Text('Get Level'),
                  ),
                  ElevatedButton(
                    onPressed: _getBatteryState,
                    child: const Text('Get State'),
                  ),
                  ElevatedButton(
                    onPressed: _checkLowPowerMode,
                    child: const Text('Check Low Power'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _listenToBatteryChanges, // Re-subscribe if needed
                child: const Text('Restart Stream Listener'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
