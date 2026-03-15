import 'dart:io';

import 'package:flutter/services.dart';

class PhotoLibraryService {
  static const MethodChannel _channel =
      MethodChannel('zootocam/photo_library');

  static Future<int> saveImage(String path) async {
    if (!File(path).existsSync()) {
      throw const FileSystemException('画像ファイルが見つかりません');
    }

    final count = await _channel.invokeMethod<int>(
      'saveImage',
      {'path': path},
    );
    return count ?? 0;
  }

  static Future<int> saveImages(List<String> paths) async {
    final validPaths = paths.where((path) => File(path).existsSync()).toList();
    if (validPaths.isEmpty) {
      throw const FileSystemException('保存できる画像がありません');
    }

    final count = await _channel.invokeMethod<int>(
      'saveImages',
      {'paths': validPaths},
    );
    return count ?? 0;
  }
}
