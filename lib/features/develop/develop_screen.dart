import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/ai_memory_assist.dart';
import '../../core/config/pro_access.dart';
import '../../core/database/database_helper.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/mock_photo.dart';
import '../album/photo_viewer_screen.dart';
import '../camera/film_session_notifier.dart';
import '../camera/widgets/film_preview.dart';
import '../journal/journal_screen.dart';
import '../share/contact_sheet_service.dart';

class DevelopScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final LutType lutType;

  const DevelopScreen({
    super.key,
    required this.sessionId,
    this.lutType = LutType.natural,
  });

  @override
  ConsumerState<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends ConsumerState<DevelopScreen>
    with TickerProviderStateMixin {
  // 化学発色プログレス
  late AnimationController _chemController;
  late Animation<double> _chemProgress;

  // フィルムストリップ流れ
  late AnimationController _stripController;

  // 完了後フェードイン
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  bool _isDone = false;
  bool _isWaiting = false;
  List<Photo> _photos = [];
  FilmSession? _session;
  String? _indexSheetPath;
  bool _isGeneratingIndexSheet = false;
  Timer? _waitingTimer;

  LutType get _effectiveLutType =>
      _session?.isFilmMode == true ? LutType.natural : widget.lutType;

  @override
  void initState() {
    super.initState();

    _chemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _chemProgress = CurvedAnimation(
      parent: _chemController,
      curve: Curves.easeInOut,
    );

    _stripController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _chemController.forward();
    _startDeveloping();
  }

  @override
  void dispose() {
    _chemController.dispose();
    _stripController.dispose();
    _fadeController.dispose();
    _waitingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDeveloping() async {
    final session = await DatabaseHelper.getFilmSession(widget.sessionId);
    final photos = await DatabaseHelper.getPhotosForSession(widget.sessionId);
    if (session == null) return;

    if (session.status == FilmStatus.developed) {
      if (!mounted) return;
      setState(() {
        _session = session;
        _photos = photos;
        _indexSheetPath = session.indexSheetPath;
        _isDone = true;
      });
      _fadeController.forward();
      return;
    }

    if (!session.isDevelopReady) {
      if (!mounted) return;
      setState(() {
        _session = session;
        _photos = photos;
        _indexSheetPath = session.indexSheetPath;
        _isWaiting = true;
      });
      // 30秒ごとに残り時間表示を更新
      _waitingTimer?.cancel();
      _waitingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
      return;
    }

    await Future.delayed(const Duration(seconds: 3));
    await ref
        .read(filmSessionProvider.notifier)
        .markDeveloped(widget.sessionId);

    if (mounted) {
      setState(() {
        _session = session;
        _photos = photos;
        _indexSheetPath = session.indexSheetPath;
        _isDone = true;
        _isWaiting = false;
      });
      _fadeController.forward();
      if (session.isFilmMode && photos.length >= FilmSession.maxPhotos) {
        _generateIndexSheet(session, photos);
      }
    }
  }

  Future<void> _generateIndexSheet(
    FilmSession session,
    List<Photo> photos,
  ) async {
    if (_isGeneratingIndexSheet || photos.isEmpty) return;
    setState(() => _isGeneratingIndexSheet = true);
    try {
      final path = await ContactSheetService.generate(
        session: session,
        photos: photos,
        format: ContactSheetFormat.indexSheet,
        persist: true,
      );
      final updatedSession = session.copyWith(
        status: FilmStatus.developed,
        indexSheetPath: path,
      );
      await DatabaseHelper.updateFilmSession(
        updatedSession,
      );
      if (!mounted) return;
      setState(() {
        _indexSheetPath = path;
        _session = updatedSession;
      });
    } finally {
      if (mounted) setState(() => _isGeneratingIndexSheet = false);
    }
  }

  Future<void> _shareIndexSheet() async {
    final session = _session;
    final path = _indexSheetPath;
    if (session == null || path == null) return;
    await Share.shareXFiles(
      [XFile(path)],
      text:
          'INDEX PRINT\n${session.locationName ?? session.title}\n${session.theme ?? ''}',
    );
  }

  Future<void> _skipWaitWithPro() async {
    await ref
        .read(filmSessionProvider.notifier)
        .unlockDevelopNow(widget.sessionId);
    if (!mounted) return;
    setState(() => _isWaiting = false);
    await _startDeveloping();
  }

  Future<void> _showProSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pro 機能',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Proなら、フィルム現像の待ち時間をスキップしてすぐ開けます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(proAccessProvider.notifier).setEnabled(true);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _skipWaitWithPro();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Proを有効化して今すぐ現像',
                    style: TextStyle(letterSpacing: 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'あとで',
                    style: TextStyle(letterSpacing: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openIndexSheetReview() {
    final session = _session;
    final path = _indexSheetPath;
    if (session == null || path == null || _photos.isEmpty) return;
    Navigator.of(context).push(
      DarkFadeRoute(
        page: _IndexSheetReviewScreen(
          session: session,
          photos: _photos,
          sheetPath: path,
          onShare: _shareIndexSheet,
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    _goToAlbum();
  }

  void _goToAlbum() {
    ref.read(mainTabIndexProvider.notifier).state = 1;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildScreenChrome({
    required String label,
    String? trailingLabel,
    VoidCallback? onTrailingTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
            tooltip: '戻る',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2.4,
              ),
            ),
          ),
          TextButton(
            onPressed: onTrailingTap ?? _goToAlbum,
            child: Text(
              trailingLabel ?? 'アルバム',
              style: const TextStyle(
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isDone
          ? _buildResult()
          : _isWaiting
              ? _buildWaiting()
              : _buildDeveloping(),
    );
  }

  // ── 現像中 ─────────────────────────────────────────────────

  Widget _buildDeveloping() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // フィルムストリップ背景
        AnimatedBuilder(
          animation: _stripController,
          builder: (_, __) => CustomPaint(
            painter: _FilmStripPainter(progress: _stripController.value),
          ),
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 暗室ランプ
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB22222).withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB22222).withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.circle,
                  color: Color(0xFFB22222),
                  size: 14,
                ),
              ),

              const SizedBox(height: 48),

              AnimatedBuilder(
                animation: _chemProgress,
                builder: (_, __) => Column(
                  children: [
                    // 現像プログレスバー
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: _chemProgress.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: const Color(0xFFB22222).withValues(alpha: 0.7),
                          minHeight: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      '現像中',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.3 + 0.5 * _chemProgress.value,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _developStage(_chemProgress.value),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),

              Text(
                _effectiveLutType.label,
                style: const TextStyle(
                  color: Color(0xFFB22222),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildScreenChrome(label: 'DARKROOM'),
          ),
        ),
      ],
    );
  }

  String _developStage(double t) {
    if (t < 0.30) return 'D-76 現像液 ... 20°C';
    if (t < 0.58) return '停止液 処理中 ...';
    if (t < 0.84) return '定着液 処理中 ...';
    return '水洗い 完了';
  }

  Widget _buildWaiting() {
    final session = _session;
    final readyAt = session?.developReadyAt;
    final isPro = ref.watch(proAccessProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScreenChrome(label: 'DEVELOP WAIT'),
            const SizedBox(height: 8),
            const Text(
              '現像待ち',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            if (readyAt != null) ...[
              Text(
                _formatRemaining(readyAt.difference(DateTime.now())),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatReadyAt(readyAt)} に開封できます',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'このロールはまだ暗室で休ませています。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session?.title ?? 'CURRENT ROLL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session?.theme?.isNotEmpty == true
                        ? 'THEME  ${session!.theme!}'
                        : '撮り切ったロールをすぐ開かず、少し寝かせます。',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_photos.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: _FilmHeroPreview(
                          photo: _photos.last,
                          lutType: _effectiveLutType,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isPro ? _skipWaitWithPro : _showProSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  isPro ? '今すぐ現像する' : '今すぐ現像する  PRO',
                  style: const TextStyle(letterSpacing: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(mainTabIndexProvider.notifier).state = 1;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'アルバムへ戻る',
                  style: TextStyle(letterSpacing: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 現像完了 ────────────────────────────────────────────────

  Widget _buildResult() {
    final aiSettings = ref.watch(aiMemoryAssistSettingsProvider);
    return FadeTransition(
      opacity: _fadeIn,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildScreenChrome(label: 'DEVELOPED'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '現像完了',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 4,
                            ),
                          ),
                          if (_session?.title != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _session!.title,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                          if (_session?.theme?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              'THEME  ${_session!.theme!}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 2.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _effectiveLutType.subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_photos.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: _FilmHeroPreview(
                        photo: _photos.last,
                        lutType: _effectiveLutType,
                      ),
                    ),
                  ),
                ),
              ),
            if (_session?.isFilmMode == true &&
                _photos.length >= FilmSession.maxPhotos)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: _IndexSheetCard(
                    sheetPath: _indexSheetPath,
                    isGenerating: _isGeneratingIndexSheet,
                    onShare: _indexSheetPath == null ? null : _shareIndexSheet,
                  ),
                ),
              ),
            if (_session?.isFilmMode == true &&
                _photos.length >= FilmSession.maxPhotos)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _indexSheetPath == null || _isGeneratingIndexSheet
                              ? null
                              : _openIndexSheetReview,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        'インデックスシートで振り返る',
                        style: TextStyle(letterSpacing: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FilmPhoto(
                    photo: _photos[index],
                    lutType: _effectiveLutType,
                    index: index,
                  ),
                  childCount: _photos.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  children: [
                    if (aiSettings.enabled &&
                        aiSettings.promptAfterDevelop &&
                        _session?.isFilmMode == true) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              DarkFadeRoute(
                                page: JournalScreen(
                                  sessionId: widget.sessionId,
                                  photos: _photos,
                                  startWithAiAssist: true,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'AIで思い出を整理する',
                            style: TextStyle(
                              fontSize: 15,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            DarkFadeRoute(
                              page: JournalScreen(
                                sessionId: widget.sessionId,
                                photos: _photos,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ロールと写真にメモを残す',
                          style: TextStyle(
                            fontSize: 15,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(mainTabIndexProvider.notifier).state = 1;
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'あとでアルバムから見返す',
                          style: TextStyle(letterSpacing: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexSheetCard extends StatelessWidget {
  final String? sheetPath;
  final bool isGenerating;
  final VoidCallback? onShare;

  const _IndexSheetCard({
    required this.sheetPath,
    required this.isGenerating,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final file = sheetPath == null ? null : File(sheetPath!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INDEX SHEET',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGenerating
                ? '撮り切ったロールから、現像所のインデックスシートを作っています。'
                : '撮り切ったフィルムから、自動でインデックスシートを書き出しました。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 900 / 600, // IndexSheet 出力サイズ(900×600)に合わせた 3:2
              child: isGenerating
                  ? Container(
                      color: const Color(0xFFF3EDE1),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.black54,
                          strokeWidth: 1.4,
                        ),
                      ),
                    )
                  : file != null && file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : const MockPhotoView(fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onShare,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                isGenerating ? 'インデックスシート生成中' : 'インデックスシートを共有',
                style: const TextStyle(letterSpacing: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexSheetReviewScreen extends StatelessWidget {
  final FilmSession session;
  final List<Photo> photos;
  final String sheetPath;
  final Future<void> Function() onShare;

  const _IndexSheetReviewScreen({
    required this.session,
    required this.photos,
    required this.sheetPath,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(sheetPath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'INDEX SHEET',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Text(
                      session.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (session.theme?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        'THEME  ${session.theme!}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'まずはロール全体の並びを見てから、1コマずつ振り返ります。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 1.48,
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.contain)
                            : const MockPhotoView(fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            DarkFadeRoute(
                              page: PhotoViewerScreen(
                                session: session,
                                photos: photos,
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'コマを1枚ずつ見る',
                          style: TextStyle(letterSpacing: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onShare,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'インデックスシートを共有',
                          style: TextStyle(letterSpacing: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRemaining(Duration d) {
  if (d.isNegative) return '現像できます';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return 'あと$h時間${m > 0 ? '$m分' : ''}';
  return 'あと$m分';
}

String _formatReadyAt(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

// ── フィルムストリップ背景 ────────────────────────────────────

class _FilmStripPainter extends CustomPainter {
  final double progress;

  const _FilmStripPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const frameW = 80.0;
    const frameH = 56.0;
    const perf = 7.0;
    const stripH = frameH + perf * 2 + 14;
    final dy = (progress * stripH) % stripH - stripH;

    for (double y = dy; y < size.height + stripH; y += stripH) {
      for (double x = 0; x < size.width; x += frameW + 10) {
        final r = Rect.fromLTWH(x + 5, y + perf + 7, frameW, frameH);
        canvas.drawRect(r, framePaint);
        canvas.drawRect(r, borderPaint);
        // パーフォレーション
        for (double px = x + 5; px < x + frameW; px += 14) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(px, y + 1, 8, perf - 1),
              const Radius.circular(2),
            ),
            framePaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(px, y + perf + 7 + frameH + 1, 8, perf - 1),
              const Radius.circular(2),
            ),
            framePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FilmStripPainter old) => old.progress != progress;
}

// ── フィルム写真タイル（スタガーフェードイン）────────────────

class _FilmPhoto extends StatefulWidget {
  final Photo photo;
  final LutType lutType;
  final int index;

  const _FilmPhoto({
    required this.photo,
    required this.lutType,
    required this.index,
  });

  @override
  State<_FilmPhoto> createState() => _FilmPhotoState();
}

class _FilmPhotoState extends State<_FilmPhoto>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.photo.imagePath);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          DarkFadeRoute(
            page: _PhotoDetailScreen(
              photo: widget.photo,
              lutType: widget.lutType,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: !file.existsSync()
              ? const MockPhotoView()
              : widget.photo.imagePath.endsWith('_film.png')
                  ? Image.file(file, fit: BoxFit.cover)
                  : FilmShaderImage(
                      imagePath: widget.photo.imagePath,
                      lutType: widget.lutType,
                      fit: BoxFit.cover,
                    ),
        ),
      ),
    );
  }
}

// ── フォト詳細 ───────────────────────────────────────────────

class _PhotoDetailScreen extends StatelessWidget {
  final Photo photo;
  final LutType lutType;

  const _PhotoDetailScreen({
    required this.photo,
    required this.lutType,
  });

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);
    final isBaked = photo.imagePath.endsWith('_film.png');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 写真（インタラクティブ）
          InteractiveViewer(
            child: Center(
              child: !file.existsSync()
                  ? const MockPhotoView(fit: BoxFit.contain)
                  : isBaked
                      ? Image.file(file, fit: BoxFit.contain)
                      : FilmShaderImage(
                          imagePath: photo.imagePath,
                          lutType: lutType,
                          fit: BoxFit.contain,
                        ),
            ),
          ),
          // 下部メタデータバー
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (photo.subject?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              photo.subject!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        Text(
                          _formatTimestamp(photo.timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lutType.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilmHeroPreview extends StatelessWidget {
  final Photo photo;
  final LutType lutType;

  const _FilmHeroPreview({
    required this.photo,
    required this.lutType,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);
    final isBaked = photo.imagePath.endsWith('_film.png');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!file.existsSync())
          const MockPhotoView()
        else if (isBaked)
          Image.file(file, fit: BoxFit.cover)
        else
          FilmShaderImage(
            imagePath: photo.imagePath,
            lutType: lutType,
            fit: BoxFit.cover,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
