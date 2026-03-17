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
  static const bool _defaultDisableMapbox = true;
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
    if (_defaultDisableMapbox) return true;
    return isIOS26OrLater;
  }

  static bool get disableFragmentShaders {
    if (_forceEnableFragmentShaders) return false;
    if (_forceDisableFragmentShaders) return true;
    // iOS 26+ でのクラッシュ原因は Mapbox 起動 (→ disableMapbox で対処済み) と
    // Impeller (→ FLTEnableImpeller=false で対処済み)。
    // Skia レンダラー上での FragmentProgram は問題なく動作するため
    // iOS 26 チェックを除外する。
    return false;
  }

  static String? get mapboxDisableReason {
    if (!disableMapbox) return null;
    if (_forceDisableMapbox) {
      return '起動安定化のため、Mapbox を明示的に無効化しています。';
    }
    if (_defaultDisableMapbox) {
      return '運用方針により、Mapbox を一時停止しています。';
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
    return 'GLSL シェーダーを一時停止しています。';
  }

  static int _readIosMajorVersion() {
    if (kIsWeb || !Platform.isIOS) return 0;
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
