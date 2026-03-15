import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiConnectionMode {
  localPreview,
  selfHosted;

  String get label {
    switch (this) {
      case AiConnectionMode.localPreview:
        return 'ローカル';
      case AiConnectionMode.selfHosted:
        return '自前API';
    }
  }

  String get description {
    switch (this) {
      case AiConnectionMode.localPreview:
        return 'まずは端末内のプレビュー生成で試す';
      case AiConnectionMode.selfHosted:
        return '自前バックエンドの接続先とトークンを使う';
    }
  }
}

class AiConnectionSettings {
  final AiConnectionMode mode;
  final String displayName;
  final String baseUrl;
  final String accessToken;

  const AiConnectionSettings({
    this.mode = AiConnectionMode.localPreview,
    this.displayName = '',
    this.baseUrl = '',
    this.accessToken = '',
  });

  bool get isSelfHostedConfigured =>
      mode == AiConnectionMode.selfHosted &&
      baseUrl.trim().isNotEmpty &&
      accessToken.trim().isNotEmpty;

  bool get canUseSelfHosted => isSelfHostedConfigured;

  String get statusLabel {
    switch (mode) {
      case AiConnectionMode.localPreview:
        return 'ローカル';
      case AiConnectionMode.selfHosted:
        return isSelfHostedConfigured ? '接続済み' : '未接続';
    }
  }

  String get summary {
    switch (mode) {
      case AiConnectionMode.localPreview:
        return 'いまは端末内の下書き生成を使います';
      case AiConnectionMode.selfHosted:
        final name = displayName.trim();
        if (isSelfHostedConfigured) {
          return name.isNotEmpty ? '$name の自前AIへ接続します' : '自前AI API に接続します';
        }
        return '自前AI API の接続先を設定してください';
    }
  }

  String get maskedToken {
    final trimmed = accessToken.trim();
    if (trimmed.isEmpty) return '未設定';
    if (trimmed.length <= 8) {
      return '••••${trimmed.substring(trimmed.length - 2)}';
    }
    return '••••${trimmed.substring(trimmed.length - 4)}';
  }

  AiConnectionSettings copyWith({
    AiConnectionMode? mode,
    String? displayName,
    String? baseUrl,
    String? accessToken,
  }) {
    return AiConnectionSettings(
      mode: mode ?? this.mode,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

class AiConnectionSettingsNotifier extends StateNotifier<AiConnectionSettings> {
  AiConnectionSettingsNotifier() : super(const AiConnectionSettings()) {
    _load();
  }

  static const _modeKey = 'ai_connection_mode';
  static const _displayNameKey = 'ai_connection_display_name';
  static const _baseUrlKey = 'ai_connection_base_url';
  static const _accessTokenKey = 'ai_connection_access_token';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex =
        prefs.getInt(_modeKey) ?? AiConnectionMode.localPreview.index;
    state = AiConnectionSettings(
      mode: AiConnectionMode
          .values[modeIndex.clamp(0, AiConnectionMode.values.length - 1)],
      displayName: prefs.getString(_displayNameKey) ?? '',
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
      accessToken: prefs.getString(_accessTokenKey) ?? '',
    );
  }

  Future<void> save(AiConnectionSettings next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, next.mode.index);
    await prefs.setString(_displayNameKey, next.displayName);
    await prefs.setString(_baseUrlKey, next.baseUrl);
    await prefs.setString(_accessTokenKey, next.accessToken);
  }

  Future<void> clearSelfHostedCredentials() async {
    final next = state.copyWith(
      displayName: '',
      baseUrl: '',
      accessToken: '',
    );
    await save(next);
  }
}

final aiConnectionSettingsProvider =
    StateNotifierProvider<AiConnectionSettingsNotifier, AiConnectionSettings>(
        (ref) {
  return AiConnectionSettingsNotifier();
});
