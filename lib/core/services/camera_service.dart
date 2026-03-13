import 'package:flutter/services.dart';

class CameraService {
  static const _channel = MethodChannel('smap.cam/camera');

  static Future<void> startCamera(int textureId) async {
    await _channel.invokeMethod('startCamera', {'textureId': textureId});
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

  static Future<Map<String, dynamic>> initializeCamera() async {
    final result = await _channel.invokeMethod<Map>('initializeCamera');
    return Map<String, dynamic>.from(result ?? {});
  }
}
