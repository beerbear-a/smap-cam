import 'package:flutter/services.dart';

class CameraService {
  static const _channel = MethodChannel('zootocam/camera');
  static VoidCallback? _hardwareShutterHandler;

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

  static Future<void> setUtsurunEnabled(bool enabled) async {
    await _channel.invokeMethod('setUtsurunEnabled', {'enabled': enabled});
  }

  static Future<List<String>> classifyImage(
    String imagePath, {
    int maxResults = 3,
  }) async {
    try {
      final result = await _channel.invokeMethod<List>(
        'classifyImage',
        {
          'imagePath': imagePath,
          'maxResults': maxResults,
        },
      );
      if (result == null) return [];
      return result.map((e) => e.toString()).toList();
    } on MissingPluginException {
      return [];
    }
  }

  /// タップフォーカス / タップ露出
  /// [x], [y] は 0.0〜1.0 の正規化座標（左上が 0,0）
  static Future<void> setFocusPoint(double x, double y) async {
    await _channel.invokeMethod('setFocusPoint', {'x': x, 'y': y});
  }

  static void setHardwareShutterHandler(VoidCallback? handler) {
    _hardwareShutterHandler = handler;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hardwareShutter') {
        _hardwareShutterHandler?.call();
      }
    });
  }
}
