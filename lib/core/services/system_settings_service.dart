import 'package:flutter/services.dart';

class SystemSettingsService {
  static const MethodChannel _channel =
      MethodChannel('atobits/system_settings');

  static Future<bool> openAppNotificationSettings() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('openAppNotificationSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openTtsSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openTtsSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
