import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/ai_memory_assist.dart';
import '../../core/database/database_helper.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../../core/models/ai_lifelog_draft.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/models/species.dart';
import '../../core/widgets/mock_photo.dart';
import '../ai_memory/ai_memory_assist_service.dart';
import '../settings/settings_screen.dart';
import '../share/share_service.dart';

class JournalScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final List<Photo> photos;
  final int initialIndex;
  final bool startWithAiAssist;

  const JournalScreen({
    super.key,
    required this.sessionId,
    required this.photos,
    this.initialIndex = 0,
    this.startWithAiAssist = false,
  });

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late List<_JournalEntry> _entries;
  late final PageController _pageController;
  final _sessionMemoController = TextEditingController();
  final _aiTitleController = TextEditingController();
  final _aiSubtitleController = TextEditingController();
  final _aiIntroController = TextEditingController();
  final _aiBodyController = TextEditingController();
  final _aiHashtagsController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingAiDraft = true;
  bool _isGeneratingAiDraft = false;
  int _currentIndex = 0;
  String? _sessionTheme;
  String? _aiDraftId;
  String? _aiDraftSocialSummary;
  AiMemoryTone _aiDraftTone = AiMemoryTone.note;

  // レアリティ4 遭遇演出
  bool _showRareOverlay = false;
  String? _rareSpeciesName;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _entries = widget.photos
        .map((p) => _JournalEntry(
              photo: p,
              subjectController: TextEditingController(text: p.subject ?? ''),
              memoController: TextEditingController(text: p.memo ?? ''),
            ))
        .toList();
    _loadSessionMemo();
    _loadAiDraft();
  }

  Future<void> _loadSessionMemo() async {
    final session = await DatabaseHelper.getFilmSession(widget.sessionId);
    if (!mounted || session == null) return;
    _sessionMemoController.text = session.memo ?? '';
    setState(() => _sessionTheme = session.theme);
  }

  Future<void> _loadAiDraft() async {
    final draft = await DatabaseHelper.getLatestAiLifelogDraftForSession(
        widget.sessionId);
    if (!mounted) return;
    if (draft != null) {
      _applyDraftToControllers(draft);
    }
    setState(() => _isLoadingAiDraft = false);
    if (draft == null &&
        widget.startWithAiAssist &&
        ref.read(aiMemoryAssistSettingsProvider).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _generateAiDraft();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sessionMemoController.dispose();
    _aiTitleController.dispose();
    _aiSubtitleController.dispose();
    _aiIntroController.dispose();
    _aiBodyController.dispose();
    _aiHashtagsController.dispose();
    for (final e in _entries) {
      e.subjectController.dispose();
      e.memoController.dispose();
    }
    super.dispose();
  }

  void _applyDraftToControllers(AiLifelogDraft draft) {
    _aiDraftId = draft.draftId;
    _aiDraftTone = draft.tone;
    _aiDraftSocialSummary = draft.socialSummary;
    _aiTitleController.text = draft.title ?? '';
    _aiSubtitleController.text = draft.subtitle ?? '';
    _aiIntroController.text = draft.intro ?? '';
    _aiBodyController.text = draft.bodyPlainText ?? draft.bodyMarkdown ?? '';
    _aiHashtagsController.text = draft.hashtags.map((tag) => '#$tag').join(' ');
  }

  List<Photo> _buildAiSourcePhotos() {
    return _entries
        .map(
          (entry) => entry.photo.copyWith(
            subject: entry.subjectController.text.trim().isEmpty
                ? null
                : entry.subjectController.text.trim(),
            memo: entry.memoController.text.trim().isEmpty
                ? null
                : entry.memoController.text.trim(),
          ),
        )
        .toList();
  }

  Future<FilmSession?> _buildAiSourceSession() async {
    final session = await DatabaseHelper.getFilmSession(widget.sessionId);
    if (session == null) return null;
    final memo = _sessionMemoController.text.trim();
    return session.copyWith(memo: memo.isEmpty ? null : memo);
  }

  List<String> _parseHashtags() {
    return _aiHashtagsController.text
        .split(RegExp(r'[\s,、]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .map((token) => token.startsWith('#') ? token.substring(1) : token)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  AiLifelogDraft? _draftFromControllers(FilmSession session) {
    final title = _aiTitleController.text.trim();
    final subtitle = _aiSubtitleController.text.trim();
    final intro = _aiIntroController.text.trim();
    final body = _aiBodyController.text.trim();
    final hashtags = _parseHashtags();
    if (title.isEmpty &&
        subtitle.isEmpty &&
        intro.isEmpty &&
        body.isEmpty &&
        hashtags.isEmpty) {
      return null;
    }

    final existingId = _aiDraftId;
    final now = DateTime.now();
    return AiLifelogDraft(
      draftId: existingId ??
          'draft_${widget.sessionId}_${now.millisecondsSinceEpoch}',
      sessionId: widget.sessionId,
      provider: 'local',
      model: 'memory-assist-local-v1',
      tone: _aiDraftTone,
      title: title.isEmpty ? null : title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      intro: intro.isEmpty ? null : intro,
      bodyMarkdown: body.isEmpty ? null : body,
      bodyPlainText: body.isEmpty ? null : body,
      hashtags: hashtags,
      socialSummary: _aiDraftSocialSummary,
      sourceSnapshot: {
        'theme': session.theme,
        'memo': session.memo,
        'photo_count': _entries.length,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _persistAiDraft() async {
    final session = await _buildAiSourceSession();
    if (session == null) return;
    final draft = _draftFromControllers(session);
    if (draft == null) return;
    await DatabaseHelper.insertAiLifelogDraft(draft);
    _aiDraftId = draft.draftId;
  }

  Future<void> _generateAiDraft() async {
    final settings = ref.read(aiMemoryAssistSettingsProvider);
    if (!settings.enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定から「AIで思い出を整理」を有効にしてください')),
      );
      return;
    }
    final session = await _buildAiSourceSession();
    if (session == null) return;

    setState(() => _isGeneratingAiDraft = true);
    try {
      final draft = await AiMemoryAssistService.generateDraft(
        session: session,
        photos: _buildAiSourcePhotos(),
        tone: settings.tone,
      );
      await DatabaseHelper.insertAiLifelogDraft(draft);
      if (!mounted) return;
      setState(() {
        _applyDraftToControllers(draft);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AIでの整理に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAiDraft = false);
    }
  }

  Future<void> _refineAiDraft(AiMemoryRefineAction action) async {
    final session = await _buildAiSourceSession();
    if (session == null) return;
    final current = _draftFromControllers(session);
    if (current == null) {
      await _generateAiDraft();
      return;
    }

    setState(() => _isGeneratingAiDraft = true);
    try {
      final refined = await AiMemoryAssistService.refineDraft(
        draft: current,
        session: session,
        photos: _buildAiSourcePhotos(),
        action: action,
      );
      await DatabaseHelper.insertAiLifelogDraft(refined);
      if (!mounted) return;
      setState(() {
        _applyDraftToControllers(refined);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI下書きの更新に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAiDraft = false);
    }
  }

  String _buildAiExportText({required bool markdown}) {
    final title = _aiTitleController.text.trim();
    final subtitle = _aiSubtitleController.text.trim();
    final intro = _aiIntroController.text.trim();
    final body = _aiBodyController.text.trim();
    final hashtags = _parseHashtags();

    if (markdown) {
      return [
        if (title.isNotEmpty) '# $title',
        if (subtitle.isNotEmpty) subtitle,
        if (intro.isNotEmpty) intro,
        if (body.isNotEmpty) body,
        if (hashtags.isNotEmpty) hashtags.map((tag) => '#$tag').join(' '),
      ].join('\n\n').trim();
    }

    return [
      if (title.isNotEmpty) title,
      if (subtitle.isNotEmpty) subtitle,
      if (intro.isNotEmpty) intro,
      if (body.isNotEmpty) body,
      if (hashtags.isNotEmpty) hashtags.map((tag) => '#$tag').join(' '),
    ].join('\n\n').trim();
  }

  Future<void> _copyAiDraft() async {
    final text = _buildAiExportText(markdown: true);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('note向けの本文をコピーしました')),
    );
  }

  Future<void> _shareAiDraft() async {
    final text = _buildAiExportText(markdown: false);
    if (text.isEmpty) return;
    await Share.share(text);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      // 入力されたすべての subject を収集
      final subjectTexts = _entries
          .map((e) => e.subjectController.text.trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      // レアリティ4チェック
      Species? rareFind;
      if (subjectTexts.isNotEmpty) {
        final allSpecies = await DatabaseHelper.getAllSpecies();
        final rarity4 = allSpecies.where((s) => s.rarity == 4).toList();
        for (final sp in rarity4) {
          if (subjectTexts
              .any((t) => t.contains(sp.nameJa) || t.contains(sp.nameEn))) {
            rareFind = sp;
            break;
          }
        }
      }

      for (final entry in _entries) {
        await DatabaseHelper.updatePhotoJournal(
          entry.photo.photoId,
          entry.subjectController.text.trim().isEmpty
              ? null
              : entry.subjectController.text.trim(),
          entry.memoController.text.trim().isEmpty
              ? null
              : entry.memoController.text.trim(),
        );
      }
      final session = await DatabaseHelper.getFilmSession(widget.sessionId);
      if (session != null) {
        final memo = _sessionMemoController.text.trim();
        await DatabaseHelper.updateFilmSession(
          session.copyWith(memo: memo.isEmpty ? null : memo),
        );
      }
      await _persistAiDraft();

      setState(() => _isSaving = false);

      // レアリティ4演出
      if (rareFind != null && mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _showRareOverlay = true;
          _rareSpeciesName = rareFind!.nameJa;
        });
        // 演出後に自動遷移
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _navigateToAlbum();
        });
      } else if (mounted) {
        _navigateToAlbum();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  void _navigateToAlbum() {
    ref.read(mainTabIndexProvider.notifier).state = 1;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entries[_currentIndex];
    final aiSettings = ref.watch(aiMemoryAssistSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // メインコンテンツ
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  '${_currentIndex + 1} / ${_entries.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),

              // 写真
              SizedBox(
                height: 268,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _entries.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    final p = _entries[index].photo;
                    final file = File(p.imagePath);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : const MockPhotoView(),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'CUT ${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTimestamp(p.timestamp),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 68,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final p = _entries[index].photo;
                    final file = File(p.imagePath);
                    final selected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                        setState(() => _currentIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 68,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? Colors.white70 : Colors.white12,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : const MockPhotoView(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // フォーム
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'この1枚のアルバムメモ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '何が写っていたか、あとで思い出したいことを残せます。',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.46),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              '写っている動物',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: entry.subjectController,
                              hint: 'レッサーパンダ',
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'このカットのメモ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: entry.memoController,
                              hint: '寝顔がやさしかった',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現像ノート',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            if (_sessionTheme?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                'テーマ: $_sessionTheme',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _sessionMemoController,
                              hint: 'フィルムを見返したときに思い出したいこと',
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'AIで思い出を整理',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (_isGeneratingAiDraft)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white38,
                                      strokeWidth: 1.5,
                                    ),
                                  )
                                else
                                  Text(
                                    aiSettings.tone.label,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              aiSettings.enabled
                                  ? '写真やメモから、このロール全体の下書きを作れます。noteに貼りやすい形にも整えられます。'
                                  : '設定で有効にすると、ロール全体の記録を整理する下書きを作れます。',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.46),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (!aiSettings.enabled)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side:
                                        const BorderSide(color: Colors.white24),
                                  ),
                                  child: const Text('設定で有効にする'),
                                ),
                              )
                            else ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: _isGeneratingAiDraft
                                        ? null
                                        : _generateAiDraft,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.12),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      _aiDraftId == null ? '生成' : '書き直す',
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isGeneratingAiDraft
                                        ? null
                                        : () => _refineAiDraft(
                                              AiMemoryRefineAction
                                                  .refineForNote,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                          color: Colors.white24),
                                    ),
                                    child: const Text('note向けに整える'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isGeneratingAiDraft
                                        ? null
                                        : () => _refineAiDraft(
                                              AiMemoryRefineAction.shorten,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                          color: Colors.white24),
                                    ),
                                    child: const Text('短くする'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_isLoadingAiDraft)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white24,
                                        strokeWidth: 1.4,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _buildTextField(
                                  controller: _aiTitleController,
                                  hint: 'タイトル',
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _aiSubtitleController,
                                  hint: 'サブタイトル',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _aiIntroController,
                                  hint: '導入',
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _aiBodyController,
                                  hint: '本文',
                                  maxLines: 8,
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _aiHashtagsController,
                                  hint: '#上野動物園 #フィルムログ',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _copyAiDraft,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: const BorderSide(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: const Text('コピー'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _shareAiDraft,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('共有'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // シェアボタン
                      if (_currentIndex < _entries.length)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final e = _entries[_currentIndex];
                            await ShareService.sharePhoto(
                              photo: e.photo.copyWith(
                                subject: e.subjectController.text,
                                memo: e.memoController.text,
                              ),
                              session: await DatabaseHelper.getFilmSession(
                                widget.sessionId,
                              ),
                              username: ref.read(usernameProvider),
                              position: ref.read(watermarkPositionProvider),
                            );
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('この写真をシェア'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── レアリティ4 遭遇演出 ─────────────────────────
          if (_showRareOverlay)
            _RareEncounterOverlay(
              speciesName: _rareSpeciesName ?? '',
              onDismiss: _navigateToAlbum,
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.white38),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ── レアリティ4 遭遇演出オーバーレイ ──────────────────────────

class _RareEncounterOverlay extends StatefulWidget {
  final String speciesName;
  final VoidCallback onDismiss;

  const _RareEncounterOverlay({
    required this.speciesName,
    required this.onDismiss,
  });

  @override
  State<_RareEncounterOverlay> createState() => _RareEncounterOverlayState();
}

class _RareEncounterOverlayState extends State<_RareEncounterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _fadeIn.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.88),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 星アイコン群
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber.withValues(
                              alpha: (_controller.value > i * 0.15) ? 1.0 : 0.0,
                            ),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'LEGENDARY',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.speciesName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'に出会いました',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'タップして続ける',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalEntry {
  final Photo photo;
  final TextEditingController subjectController;
  final TextEditingController memoController;

  _JournalEntry({
    required this.photo,
    required this.subjectController,
    required this.memoController,
  });
}
