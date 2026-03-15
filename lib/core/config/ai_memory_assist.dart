import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiMemoryTone {
  note,
  diary;

  String get label {
    switch (this) {
      case AiMemoryTone.note:
        return 'note寄り';
      case AiMemoryTone.diary:
        return '日記寄り';
    }
  }

  String get description {
    switch (this) {
      case AiMemoryTone.note:
        return '読みやすく整理して、あとで貼り出しやすい雰囲気';
      case AiMemoryTone.diary:
        return '体験の空気感を残しながら、私的な記録としてまとめる';
    }
  }
}

class AiMemoryAssistSettings {
  final bool enabled;
  final bool promptAfterDevelop;
  final AiMemoryTone tone;

  const AiMemoryAssistSettings({
    this.enabled = false,
    this.promptAfterDevelop = true,
    this.tone = AiMemoryTone.note,
  });

  AiMemoryAssistSettings copyWith({
    bool? enabled,
    bool? promptAfterDevelop,
    AiMemoryTone? tone,
  }) {
    return AiMemoryAssistSettings(
      enabled: enabled ?? this.enabled,
      promptAfterDevelop: promptAfterDevelop ?? this.promptAfterDevelop,
      tone: tone ?? this.tone,
    );
  }
}

class AiMemoryAssistSettingsNotifier
    extends StateNotifier<AiMemoryAssistSettings> {
  AiMemoryAssistSettingsNotifier() : super(const AiMemoryAssistSettings()) {
    _load();
  }

  static const _enabledKey = 'ai_memory_assist_enabled';
  static const _promptAfterDevelopKey = 'ai_memory_assist_prompt_after_develop';
  static const _toneKey = 'ai_memory_assist_tone';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final toneIndex = prefs.getInt(_toneKey) ?? AiMemoryTone.note.index;
    state = AiMemoryAssistSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      promptAfterDevelop: prefs.getBool(_promptAfterDevelopKey) ?? true,
      tone: AiMemoryTone
          .values[toneIndex.clamp(0, AiMemoryTone.values.length - 1)],
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setPromptAfterDevelop(bool value) async {
    state = state.copyWith(promptAfterDevelop: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptAfterDevelopKey, value);
  }

  Future<void> setTone(AiMemoryTone value) async {
    state = state.copyWith(tone: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_toneKey, value.index);
  }
}

final aiMemoryAssistSettingsProvider = StateNotifierProvider<
    AiMemoryAssistSettingsNotifier, AiMemoryAssistSettings>((ref) {
  return AiMemoryAssistSettingsNotifier();
});
