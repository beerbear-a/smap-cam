import 'package:flutter/services.dart';

class CameraService {
  static const _channel = MethodChannel('zootocam/camera');

  static Future<Map<String, dynamic>> initializeCamera() async {
    final result = await _channel.invokeMethod<Map>('initializeCamera');
    return Map<String, dynamic>.from(result ?? {});
  }

  static Future<void> startCamera() async {
    await _channel.invokeMethod('startCamera');
  }

  static Future<void> stopCamera() async {
    await _channel.invokeMethod('stopCamera');
  }

  static Future<String?> takePicture(String savePath) async {
    final result = await _channel.invokeMethod<String>(
      'takePicture',
      {'savePath': savePath},
    );
    return result;
  }

  static Future<void> setFlash(bool enabled) async {
    await _channel.invokeMethod('setFlash', {'enabled': enabled});
  }

  static Future<void> setFocalLength(String focalLength) async {
    await _channel.invokeMethod('setFocalLength', {
      'focalLength': focalLength,
    });
  }

  /// タップフォーカス / タップ露出
  /// [x], [y] は 0.0〜1.0 の正規化座標（左上が 0,0）
  static Future<void> setFocusPoint(double x, double y) async {
    await _channel.invokeMethod('setFocusPoint', {'x': x, 'y': y});
  }
}
