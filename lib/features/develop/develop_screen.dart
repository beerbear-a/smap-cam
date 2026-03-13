import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/utils/routes.dart';
import '../camera/film_session_notifier.dart';
import '../camera/widgets/film_preview.dart';
import '../journal/journal_screen.dart';

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
  List<Photo> _photos = [];
  FilmSession? _session;

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
    super.dispose();
  }

  Future<void> _startDeveloping() async {
    await Future.delayed(const Duration(seconds: 3));

    final session = await DatabaseHelper.getFilmSession(widget.sessionId);
    final photos = await DatabaseHelper.getPhotosForSession(widget.sessionId);
    await ref.read(filmSessionProvider.notifier).markDeveloped(widget.sessionId);

    if (mounted) {
      setState(() {
        _session = session;
        _photos = photos;
        _isDone = true;
      });
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isDone ? _buildResult() : _buildDeveloping(),
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
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          color:
                              const Color(0xFFB22222).withValues(alpha: 0.7),
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
                widget.lutType.label,
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
      ],
    );
  }

  String _developStage(double t) {
    if (t < 0.30) return 'D-76 現像液 ... 20°C';
    if (t < 0.58) return '停止液 処理中 ...';
    if (t < 0.84) return '定着液 処理中 ...';
    return '水洗い 完了';
  }

  // ── 現像完了 ────────────────────────────────────────────────

  Widget _buildResult() {
    return FadeTransition(
      opacity: _fadeIn,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                      ],
                    ),
                  ),
                  // フィルムストック名バッジ
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
                      '${widget.lutType.label} ${widget.lutType.subtitle}',
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

            const SizedBox(height: 16),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) => _FilmPhoto(
                  photo: _photos[index],
                  lutType: widget.lutType,
                  index: index,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
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
                    '観察日記を書く',
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          DarkFadeRoute(page: _PhotoDetailScreen(photo: widget.photo)),
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(widget.lutType.colorMatrix),
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white24,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── フォト詳細 ───────────────────────────────────────────────

class _PhotoDetailScreen extends StatelessWidget {
  final Photo photo;

  const _PhotoDetailScreen({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white70),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(photo.imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
