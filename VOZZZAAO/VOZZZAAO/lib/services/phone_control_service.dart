import 'dart:io';

import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({required this.name, required this.packageName});

  final String name;
  final String packageName;
}

class PhoneControlService {
  static const MethodChannel _channel = MethodChannel(
    'voz_comando/phone_control',
  );

  Future<bool> isAccessibilityEnabled() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  Future<bool> pressBack({int times = 1}) async {
    if (!Platform.isAndroid) return false;
    final safeTimes = times.clamp(1, 10).toInt();
    return await _channel.invokeMethod<bool>('pressBack', <String, int>{
          'times': safeTimes,
        }) ??
        false;
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return const <InstalledApp>[];
    final rawApps =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ??
        const <dynamic>[];
    return rawApps
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (rawApp) => InstalledApp(
            name: rawApp['name']?.toString() ?? '',
            packageName: rawApp['package']?.toString() ?? '',
          ),
        )
        .where((app) => app.name.isNotEmpty && app.packageName.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> openApp(String packageName) async {
    if (!Platform.isAndroid || packageName.trim().isEmpty) return false;
    return await _channel.invokeMethod<bool>('openApp', <String, String>{
          'package': packageName.trim(),
        }) ??
        false;
  }

  Future<bool> pressHome({int times = 2}) async {
    if (!Platform.isAndroid) return false;
    final safeTimes = times.clamp(1, 5).toInt();
    return await _channel.invokeMethod<bool>('pressHome', <String, int>{
          'times': safeTimes,
        }) ??
        false;
  }
}
