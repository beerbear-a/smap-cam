import 'dart:io';

import 'package:flutter/foundation.dart';

class RuntimeCompatibility {
  RuntimeCompatibility._();

  static const bool _forceEnableMapbox = bool.fromEnvironment(
    'ZOOTOCAM_FORCE_ENABLE_MAPBOX',
  );
  static const bool _forceDisableMapbox = bool.fromEnvironment(
    'ZOOTOCAM_DISABLE_MAPBOX',
  );
  static const bool _forceEnableFragmentShaders = bool.fromEnvironment(
    'ZOOTOCAM_FORCE_ENABLE_FRAGMENT_SHADERS',
  );
  static const bool _forceDisableFragmentShaders = bool.fromEnvironment(
    'ZOOTOCAM_DISABLE_FRAGMENT_SHADERS',
  );

  static final int _iosMajorVersion = _readIosMajorVersion();

  static bool get isIOS26OrLater =>
      !kIsWeb && Platform.isIOS && _iosMajorVersion >= 26;

  static bool get disableMapbox {
    if (_forceEnableMapbox) return false;
    if (_forceDisableMapbox) return true;
    return isIOS26OrLater;
  }

  static bool get disableFragmentShaders {
    if (_forceEnableFragmentShaders) return false;
    if (_forceDisableFragmentShaders) return true;
    return isIOS26OrLater;
  }

  static String? get mapboxDisableReason {
    if (!disableMapbox) return null;
    if (_forceDisableMapbox) {
      return '起動安定化のため、Mapbox を明示的に無効化しています。';
    }
    if (isIOS26OrLater) {
      return 'iOS 26 系では起動直後クラッシュ回避のため、Mapbox を一時停止しています。';
    }
    return 'Mapbox を一時停止しています。';
  }

  static String? get fragmentShaderDisableReason {
    if (!disableFragmentShaders) return null;
    if (_forceDisableFragmentShaders) {
      return '起動安定化のため、GLSL シェーダーを明示的に無効化しています。';
    }
    if (isIOS26OrLater) {
      return 'iOS 26 系では FragmentProgram の互換性確認まで安全な色補正表示へ切り替えています。';
    }
    return 'GLSL シェーダーを一時停止しています。';
  }

  static int _readIosMajorVersion() {
    if (kIsWeb || !Platform.isIOS) return 0;
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
