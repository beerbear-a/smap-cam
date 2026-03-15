import 'dart:convert';

import '../config/ai_memory_assist.dart';

class AiLifelogDraft {
  final String draftId;
  final String sessionId;
  final String provider;
  final String model;
  final AiMemoryTone tone;
  final String? title;
  final String? subtitle;
  final String? intro;
  final String? bodyMarkdown;
  final String? bodyPlainText;
  final List<String> hashtags;
  final String? socialSummary;
  final Map<String, dynamic>? sourceSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiLifelogDraft({
    required this.draftId,
    required this.sessionId,
    required this.provider,
    required this.model,
    required this.tone,
    this.title,
    this.subtitle,
    this.intro,
    this.bodyMarkdown,
    this.bodyPlainText,
    this.hashtags = const [],
    this.socialSummary,
    this.sourceSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  AiLifelogDraft copyWith({
    String? draftId,
    String? sessionId,
    String? provider,
    String? model,
    AiMemoryTone? tone,
    String? title,
    String? subtitle,
    String? intro,
    String? bodyMarkdown,
    String? bodyPlainText,
    List<String>? hashtags,
    String? socialSummary,
    Map<String, dynamic>? sourceSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiLifelogDraft(
      draftId: draftId ?? this.draftId,
      sessionId: sessionId ?? this.sessionId,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      tone: tone ?? this.tone,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      intro: intro ?? this.intro,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      bodyPlainText: bodyPlainText ?? this.bodyPlainText,
      hashtags: hashtags ?? this.hashtags,
      socialSummary: socialSummary ?? this.socialSummary,
      sourceSnapshot: sourceSnapshot ?? this.sourceSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'draft_id': draftId,
      'session_id': sessionId,
      'provider': provider,
      'model': model,
      'tone': tone.name,
      'title': title,
      'subtitle': subtitle,
      'intro': intro,
      'body_markdown': bodyMarkdown,
      'body_plain_text': bodyPlainText,
      'hashtags_json': jsonEncode(hashtags),
      'social_summary': socialSummary,
      'source_snapshot_json':
          sourceSnapshot == null ? null : jsonEncode(sourceSnapshot),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AiLifelogDraft.fromMap(Map<String, dynamic> map) {
    final hashtagsJson = map['hashtags_json'] as String?;
    final snapshotJson = map['source_snapshot_json'] as String?;
    return AiLifelogDraft(
      draftId: map['draft_id'] as String,
      sessionId: map['session_id'] as String,
      provider: map['provider'] as String? ?? 'local',
      model: map['model'] as String? ?? 'memory-assist-local',
      tone: AiMemoryTone.values.firstWhere(
        (value) => value.name == map['tone'],
        orElse: () => AiMemoryTone.note,
      ),
      title: map['title'] as String?,
      subtitle: map['subtitle'] as String?,
      intro: map['intro'] as String?,
      bodyMarkdown: map['body_markdown'] as String?,
      bodyPlainText: map['body_plain_text'] as String?,
      hashtags: hashtagsJson == null
          ? const []
          : List<String>.from(jsonDecode(hashtagsJson) as List<dynamic>),
      socialSummary: map['social_summary'] as String?,
      sourceSnapshot: snapshotJson == null
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(snapshotJson) as Map<String, dynamic>,
            ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int,
      ),
    );
  }
}
