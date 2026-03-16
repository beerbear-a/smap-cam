import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugSettings {
  final bool enabled;
  final bool zooFeaturesEnabled;
  final String? filmShaderAssetOverride;

  const DebugSettings({
    this.enabled = false,
    this.zooFeaturesEnabled = true,
    this.filmShaderAssetOverride,
  });

  DebugSettings copyWith({
    bool? enabled,
    bool? zooFeaturesEnabled,
    String? filmShaderAssetOverride,
    bool clearFilmShaderAsset = false,
  }) {
    return DebugSettings(
      enabled: enabled ?? this.enabled,
      zooFeaturesEnabled: zooFeaturesEnabled ?? this.zooFeaturesEnabled,
      filmShaderAssetOverride: clearFilmShaderAsset
          ? null
          : filmShaderAssetOverride ?? this.filmShaderAssetOverride,
    );
  }
}

class DebugSettingsNotifier extends StateNotifier<DebugSettings> {
  DebugSettingsNotifier() : super(const DebugSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('debug_mode_enabled') ?? false;
    final zooEnabled = prefs.getBool('debug_zoo_features_enabled') ?? true;
    final shaderOverride = prefs.getString('debug_film_shader_override');
    state = state.copyWith(
      enabled: enabled,
      zooFeaturesEnabled: zooEnabled,
      filmShaderAssetOverride: shaderOverride?.isEmpty == true
          ? null
          : shaderOverride,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_mode_enabled', value);
  }

  Future<void> setZooFeaturesEnabled(bool value) async {
    state = state.copyWith(zooFeaturesEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_zoo_features_enabled', value);
  }

  Future<void> setFilmShaderAssetOverride(String? value) async {
    state = state.copyWith(
      filmShaderAssetOverride: value,
      clearFilmShaderAsset: value == null,
    );
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('debug_film_shader_override');
    } else {
      await prefs.setString('debug_film_shader_override', value);
    }
  }
}

final debugSettingsProvider =
    StateNotifierProvider<DebugSettingsNotifier, DebugSettings>((ref) {
  return DebugSettingsNotifier();
});

class FeatureVisibility {
  final bool mapVisible;
  final bool zukanVisible;
  final bool mapAvailable;

  const FeatureVisibility({
    required this.mapVisible,
    required this.zukanVisible,
    required this.mapAvailable,
  });
}

FeatureVisibility computeFeatureVisibility({
  required DebugSettings debug,
  required bool showMap,
  required bool showZukan,
  required bool mapboxDisabled,
}) {
  final mapAvailable = debug.zooFeaturesEnabled && !mapboxDisabled;
  return FeatureVisibility(
    mapVisible: debug.zooFeaturesEnabled && showMap,
    zukanVisible: debug.zooFeaturesEnabled && showZukan,
    mapAvailable: mapAvailable,
  );
}

const debugFilmShaderOptions = <String, String?>{
  'AUTO (フィルム別)': null,
  'PIPELINE (film_pipeline.frag)': 'shaders/film_pipeline.frag',
  'LEGACY ISO800': 'shaders/legacy/film_iso800.frag',
  'LEGACY WARM': 'shaders/legacy/film_warm.frag',
  'LEGACY FUJI400': 'shaders/legacy/film_fuji400.frag',
  'LEGACY MONO HP5': 'shaders/legacy/film_mono_hp5.frag',
};
