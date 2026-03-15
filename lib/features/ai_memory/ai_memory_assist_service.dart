import 'package:uuid/uuid.dart';

import '../../core/config/ai_memory_assist.dart';
import '../../core/models/ai_lifelog_draft.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';

enum AiMemoryRefineAction {
  rewrite,
  shorten,
  refineForNote,
}

class AiMemoryAssistService {
  static Future<AiLifelogDraft> generateDraft({
    required FilmSession session,
    required List<Photo> photos,
    required AiMemoryTone tone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final now = DateTime.now();
    final draft = _buildDraft(
      session: session,
      photos: photos,
      tone: tone,
      draftId: const Uuid().v4(),
      createdAt: now,
      updatedAt: now,
    );
    return draft;
  }

  static Future<AiLifelogDraft> refineDraft({
    required AiLifelogDraft draft,
    required FilmSession session,
    required List<Photo> photos,
    required AiMemoryRefineAction action,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return switch (action) {
      AiMemoryRefineAction.rewrite => _buildDraft(
          session: session,
          photos: photos.reversed.toList(),
          tone: draft.tone,
          draftId: draft.draftId,
          createdAt: draft.createdAt,
          updatedAt: DateTime.now(),
        ),
      AiMemoryRefineAction.shorten => draft.copyWith(
          intro: _shortenText(draft.intro, maxLength: 60),
          bodyMarkdown: _shortenText(draft.bodyMarkdown, maxLength: 260),
          bodyPlainText: _shortenText(draft.bodyPlainText, maxLength: 240),
          socialSummary: _shortenText(draft.socialSummary, maxLength: 80),
          updatedAt: DateTime.now(),
        ),
      AiMemoryRefineAction.refineForNote => _buildDraft(
          session: session,
          photos: photos,
          tone: AiMemoryTone.note,
          draftId: draft.draftId,
          createdAt: draft.createdAt,
          updatedAt: DateTime.now(),
        ),
    };
  }

  static AiLifelogDraft _buildDraft({
    required FilmSession session,
    required List<Photo> photos,
    required AiMemoryTone tone,
    required String draftId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final location = session.locationName?.trim().isNotEmpty == true
        ? session.locationName!.trim()
        : session.title;
    final theme = session.theme?.trim();
    final sessionMemo = session.memo?.trim();
    final subjectTokens = photos
        .map((photo) => photo.subject?.trim())
        .whereType<String>()
        .where((subject) => subject.isNotEmpty)
        .toList();
    final subjectSummary = subjectTokens.toSet().take(3).join('、');
    final noteSnippets = photos
        .map((photo) => photo.memo?.trim())
        .whereType<String>()
        .where((memo) => memo.isNotEmpty)
        .toList();

    final title = tone == AiMemoryTone.note
        ? _buildNoteTitle(
            location: location, theme: theme, subjects: subjectSummary)
        : _buildDiaryTitle(location: location, theme: theme);
    final subtitle = subjectSummary.isNotEmpty
        ? '$subjectSummary を見返しながら整理した1本の記録'
        : '${_formatDate(session.date)} のロールをあとから言葉にした記録';
    final intro = _buildIntro(
      location: location,
      theme: theme,
      sessionMemo: sessionMemo,
      photoCount: photos.length,
      tone: tone,
    );
    final bodyParagraphs = _buildBodyParagraphs(
      location: location,
      theme: theme,
      sessionMemo: sessionMemo,
      photoMemos: noteSnippets,
      subjectSummary: subjectSummary,
      photos: photos,
      tone: tone,
    );
    final bodyPlainText = bodyParagraphs.join('\n\n');
    final bodyMarkdown = tone == AiMemoryTone.note
        ? _toNoteSections(bodyParagraphs)
        : bodyPlainText;
    final hashtags = _buildHashtags(location, theme, subjectTokens);
    final socialSummary = _shortenText(
      '${title.isNotEmpty ? '$title。' : ''}${intro.isNotEmpty ? intro : bodyParagraphs.first}',
      maxLength: 110,
    );

    return AiLifelogDraft(
      draftId: draftId,
      sessionId: session.sessionId,
      provider: 'local',
      model: 'memory-assist-local-v1',
      tone: tone,
      title: title,
      subtitle: subtitle,
      intro: intro,
      bodyMarkdown: bodyMarkdown,
      bodyPlainText: bodyPlainText,
      hashtags: hashtags,
      socialSummary: socialSummary,
      sourceSnapshot: {
        'location': location,
        'theme': theme,
        'session_memo': sessionMemo,
        'photo_count': photos.length,
        'subjects': subjectTokens,
        'photo_memos': noteSnippets,
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String _buildNoteTitle({
    required String location,
    required String? theme,
    required String subjects,
  }) {
    if (theme?.isNotEmpty == true) {
      return '$locationで残した、${theme!}のロール';
    }
    if (subjects.isNotEmpty) {
      return '$locationで見た$subjectsを、あとで読み返せる形にする';
    }
    return '$locationで過ごした時間を、あとから見返せるロールにする';
  }

  static String _buildDiaryTitle({
    required String location,
    required String? theme,
  }) {
    if (theme?.isNotEmpty == true) {
      return '$locationのことを、$theme という気分で残した';
    }
    return '$locationで過ごした日のメモ';
  }

  static String _buildIntro({
    required String location,
    required String? theme,
    required String? sessionMemo,
    required int photoCount,
    required AiMemoryTone tone,
  }) {
    if (tone == AiMemoryTone.note) {
      if (sessionMemo?.isNotEmpty == true) {
        return '$locationで残した$photoCount枚のロールを見返していると、$sessionMemo という感触が最初に戻ってくる。';
      }
      if (theme?.isNotEmpty == true) {
        return '$locationでの時間を、$theme というテーマで残したロールをまとめた。';
      }
      return '$locationで残した$photoCount枚のロールを、あとで読み返しやすい形に整理した。';
    }
    if (sessionMemo?.isNotEmpty == true) {
      return '$locationで撮った写真を見返していると、$sessionMemo という言葉がいちばん近い気がした。';
    }
    return '$locationで過ごした時間を、あとから自分の言葉で整えておきたいと思った。';
  }

  static List<String> _buildBodyParagraphs({
    required String location,
    required String? theme,
    required String? sessionMemo,
    required List<String> photoMemos,
    required String subjectSummary,
    required List<Photo> photos,
    required AiMemoryTone tone,
  }) {
    final paragraphs = <String>[];

    if (tone == AiMemoryTone.note) {
      paragraphs.add(
        theme?.isNotEmpty == true
            ? '$locationでのこのロールは、最初から $theme を意識していた。撮影枚数は${photos.length}枚で、1枚ごとにその場の温度を少しずつ拾っていくような流れになった。'
            : '$locationでのこのロールは、特定の出来事を追うというより、その場で気になったものを少しずつ拾い集めるような一本になった。撮影枚数は${photos.length}枚だった。',
      );
      if (subjectSummary.isNotEmpty) {
        paragraphs.add(
          '印象に残っていたのは $subjectSummary あたりで、あとから見返しても、その日どこに目が向いていたのかが分かりやすい。'
          '${photoMemos.isNotEmpty ? '写真メモには「${photoMemos.take(2).join('」「')}」のような断片が残っていて、見たものよりも、その瞬間の距離感や気分がよく出ている。' : ''}',
        );
      } else if (photoMemos.isNotEmpty) {
        paragraphs.add(
          '写真ごとのメモを並べると、「${photoMemos.take(3).join('」「')}」といった断片が残っていて、その日の視線の動きがそのまま文章になりそうだった。',
        );
      }
      paragraphs.add(
        sessionMemo?.isNotEmpty == true
            ? '最終的には $sessionMemo という感覚が、このロール全体の芯になっていた気がする。写真単体よりも、まとめて見返したときに一日の空気が戻ってくる。'
            : '写真単体で完結するというより、ロール全体で見たときにやっとその日の空気が戻ってくる。そのまとまりを残しておきたくて、文章にもしておく。',
      );
      return paragraphs;
    }

    paragraphs.add(
      theme?.isNotEmpty == true
          ? '$locationで撮っていたときは、ずっと $theme みたいなことを考えていた気がする。'
          : '$locationで撮っていたときは、何か大きな目的があるというより、その場で気になったものを少しずつ拾っていた。',
    );
    if (subjectSummary.isNotEmpty || photoMemos.isNotEmpty) {
      paragraphs.add(
        'あとで写真を見返すと、'
        '${subjectSummary.isNotEmpty ? '$subjectSummary が目に残っていて、' : ''}'
        '${photoMemos.isNotEmpty ? 'メモには「${photoMemos.take(2).join('」「')}」みたいな言葉が残っていた。' : 'そのとき何を見ていたかが少しずつ戻ってくる。'}',
      );
    }
    paragraphs.add(
      sessionMemo?.isNotEmpty == true
          ? '$sessionMemo という感覚を忘れたくなくて、このロールをそのまま思い出の整理として残しておく。'
          : 'うまく説明しきれない時間だったけれど、あとから見返したときに思い出せるよう、ひとまず言葉にしておく。',
    );
    return paragraphs;
  }

  static String _toNoteSections(List<String> paragraphs) {
    final labels = [
      '## その日のこと',
      '## 印象に残った場面',
      '## あとから見返したいこと',
    ];
    final buffer = StringBuffer();
    for (var i = 0; i < paragraphs.length; i++) {
      final heading = i < labels.length ? labels[i] : '## メモ';
      if (i > 0) buffer.writeln();
      buffer
        ..writeln(heading)
        ..writeln()
        ..writeln(paragraphs[i]);
    }
    return buffer.toString().trim();
  }

  static List<String> _buildHashtags(
    String location,
    String? theme,
    List<String> subjects,
  ) {
    final tags = <String>{
      location.replaceAll(' ', ''),
      'ZootoCam',
      'フィルムログ',
      if (theme?.isNotEmpty == true) theme!.replaceAll(' ', ''),
      ...subjects.take(3).map((subject) => subject.replaceAll(' ', '')),
    };
    return tags.where((tag) => tag.isNotEmpty).toList();
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}.$month.$day';
  }

  static String _shortenText(String? value, {required int maxLength}) {
    final text = value?.trim() ?? '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1).trim()}…';
  }
}
