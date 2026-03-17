import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/film_session.dart';

class CameraSettings {
  final bool utsurunModeEnabled;
  final CaptureMode preferredCaptureMode;

  const CameraSettings({
    this.utsurunModeEnabled = false,
    this.preferredCaptureMode = CaptureMode.film,
  });

  CameraSettings copyWith({
    bool? utsurunModeEnabled,
    CaptureMode? preferredCaptureMode,
  }) {
    return CameraSettings(
      utsurunModeEnabled: utsurunModeEnabled ?? this.utsurunModeEnabled,
      preferredCaptureMode: preferredCaptureMode ?? this.preferredCaptureMode,
    );
  }
}

class CameraSettingsNotifier extends StateNotifier<CameraSettings> {
  CameraSettingsNotifier() : super(const CameraSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final utsurunEnabled = prefs.getBool('camera_utsurun_enabled') ?? false;
    final modeKey = prefs.getString('camera_capture_mode');
    final preferredMode = CaptureMode.values.firstWhere(
      (mode) => mode.name == modeKey,
      orElse: () => CaptureMode.film,
    );
    state = state.copyWith(utsurunModeEnabled: utsurunEnabled);
    state = state.copyWith(preferredCaptureMode: preferredMode);
  }

  Future<void> setUtsurunModeEnabled(bool value) async {
    state = state.copyWith(utsurunModeEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_utsurun_enabled', value);
  }

  Future<void> setPreferredCaptureMode(CaptureMode mode) async {
    state = state.copyWith(preferredCaptureMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_capture_mode', mode.name);
  }
}

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>((ref) {
  return CameraSettingsNotifier();
});
