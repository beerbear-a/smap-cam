import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/film_session.dart';
import '../../core/services/camera_service.dart';
import '../../core/utils/routes.dart';
import '../develop/develop_screen.dart';
import 'camera_notifier.dart';
import 'widgets/film_counter_widget.dart';
import 'widgets/film_preview.dart';
import 'widgets/lut_selector.dart';
import 'widgets/shutter_button.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // シャッターフラッシュ
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  // フォーカス枠
  Offset? _focusPoint;
  late AnimationController _focusController;
  late Animation<double> _focusScale;
  late Animation<double> _focusOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _focusScale = Tween<double>(begin: 1.6, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeOut),
    );
    _focusOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(cameraProvider.notifier).loadActiveSession();
      await ref.read(cameraProvider.notifier).initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    _focusController.dispose();
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(cameraProvider.notifier).disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initializeCamera();
    }
  }

  void _onShutter() {
    // フラッシュ: forward→reverse で白フラッシュ
    _flashController.forward().then((_) {
      _flashController.reverse();
    });
    ref.read(cameraProvider.notifier).takePicture();
  }

  void _onTapUp(TapUpDetails details) {
    final state = ref.read(cameraProvider);
    if (!state.isCameraReady) return;

    final size = context.size;
    if (size == null) return;

    final tapPos = details.localPosition;
    CameraService.setFocusPoint(
      (tapPos.dx / size.width).clamp(0.0, 1.0),
      (tapPos.dy / size.height).clamp(0.0, 1.0),
    );

    setState(() => _focusPoint = tapPos);
    _focusController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    // 現像フローへ自動遷移
    if (cameraState.activeSession?.status == FilmStatus.developing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          DarkFadeRoute(
            page: DevelopScreen(
              sessionId: cameraState.activeSession!.sessionId,
              lutType: cameraState.selectedLut,
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── カメラプレビュー ──────────────────────────────
          _buildPreview(cameraState),

          // ── シャッターフラッシュ ──────────────────────────
          FadeTransition(
            opacity: _flashOpacity,
            child: const ColoredBox(color: Colors.white),
          ),

          // ── UI オーバーレイ ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 戻るボタン
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      FilmCounterWidget(
                        remaining: cameraState.remainingShots,
                        total: FilmSession.maxPhotos,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // エラー
                if (cameraState.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      cameraState.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // LUT セレクター
                if (cameraState.isCameraReady)
                  LutSelectorWidget(
                    selected: cameraState.selectedLut,
                    onSelected: (lut) =>
                        ref.read(cameraProvider.notifier).setLut(lut),
                  ),

                const SizedBox(height: 12),

                // シャッター行
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // フラッシュトグル
                      IconButton(
                        onPressed: () =>
                            ref.read(cameraProvider.notifier).toggleFlash(),
                        icon: Icon(
                          cameraState.flashEnabled
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: cameraState.flashEnabled
                              ? Colors.yellow
                              : Colors.white54,
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 32),

                      ShutterButton(
                        isCapturing: cameraState.isCapturing,
                        onPressed: cameraState.canShoot ? _onShutter : null,
                      ),

                      const SizedBox(width: 62),
                    ],
                  ),
                ),

                // SHUTTER ラベル
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'SHUTTER',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraState cameraState) {
    if (!cameraState.isCameraReady || cameraState.textureId == null) {
      return const _CameraLoadingView();
    }

    return FilmPreviewWidget(
      textureId: cameraState.textureId!,
      lutType: cameraState.selectedLut,
      onTapUp: _onTapUp,
      focusIndicator: _focusPoint != null
          ? Positioned(
              left: _focusPoint!.dx - 32,
              top: _focusPoint!.dy - 32,
              child: AnimatedBuilder(
                animation: _focusController,
                builder: (_, __) => Transform.scale(
                  scale: _focusScale.value,
                  child: Opacity(
                    opacity: _focusOpacity.value,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CustomPaint(
                        painter: _FocusReticlePainter(),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── フォーカスレティクル（4隅コーナー型）─────────────────────

class _FocusReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const corner = 12.0;
    final w = size.width;
    final h = size.height;

    // 4コーナー
    final paths = [
      // 左上
      Path()
        ..moveTo(0, corner)
        ..lineTo(0, 0)
        ..lineTo(corner, 0),
      // 右上
      Path()
        ..moveTo(w - corner, 0)
        ..lineTo(w, 0)
        ..lineTo(w, corner),
      // 右下
      Path()
        ..moveTo(w, h - corner)
        ..lineTo(w, h)
        ..lineTo(w - corner, h),
      // 左下
      Path()
        ..moveTo(corner, h)
        ..lineTo(0, h)
        ..lineTo(0, h - corner),
    ];

    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FocusReticlePainter _) => false;
}

// ── ローディング ─────────────────────────────────────────────

class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Colors.white30,
              strokeWidth: 1,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'LOADING',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              letterSpacing: 5,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
