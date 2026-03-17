import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraSettings {
  final bool utsurunModeEnabled;

  const CameraSettings({
    this.utsurunModeEnabled = false,
  });

  CameraSettings copyWith({
    bool? utsurunModeEnabled,
  }) {
    return CameraSettings(
      utsurunModeEnabled: utsurunModeEnabled ?? this.utsurunModeEnabled,
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
    state = state.copyWith(utsurunModeEnabled: utsurunEnabled);
  }

  Future<void> setUtsurunModeEnabled(bool value) async {
    state = state.copyWith(utsurunModeEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_utsurun_enabled', value);
  }
}

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>((ref) {
  return CameraSettingsNotifier();
});
