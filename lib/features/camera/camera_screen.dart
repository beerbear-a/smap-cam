import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final cameraState = ref.read(cameraProvider);
    // タイマーOFFのときだけフラッシュを即時表示
    if (cameraState.timerMode == TimerMode.off) {
      _flashController.forward().then((_) => _flashController.reverse());
    }
    HapticFeedback.mediumImpact();
    ref.read(cameraProvider.notifier).triggerShutter();
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

          // ── タイマーカウントダウン表示 ────────────────────
          if (cameraState.timerCountdown != null)
            _TimerCountdownOverlay(
              count: cameraState.timerCountdown!,
              onCancel: () {
                HapticFeedback.lightImpact();
                ref.read(cameraProvider.notifier).cancelTimer();
              },
            ),

          // ── UI オーバーレイ ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
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

                      const Spacer(),

                      FilmCounterWidget(
                        remaining: cameraState.remainingShots,
                        total: FilmSession.maxPhotos,
                      ),

                      const Spacer(),

                      // グリッドトグル
                      _HeaderIconButton(
                        icon: cameraState.showGrid
                            ? Icons.grid_on
                            : Icons.grid_off,
                        active: cameraState.showGrid,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cameraProvider.notifier).toggleGrid();
                        },
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

                // LUT 強度スライダー
                if (cameraState.isCameraReady)
                  _LutIntensitySlider(
                    value: cameraState.lutIntensity,
                    onChanged: (v) =>
                        ref.read(cameraProvider.notifier).setLutIntensity(v),
                  ),

                const SizedBox(height: 8),

                // シャッター行
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // フラッシュ
                      _HeaderIconButton(
                        icon: cameraState.flashEnabled
                            ? Icons.flash_on
                            : Icons.flash_off,
                        active: cameraState.flashEnabled,
                        activeColor: Colors.yellow,
                        onTap: () =>
                            ref.read(cameraProvider.notifier).toggleFlash(),
                      ),

                      const SizedBox(width: 16),

                      // ライトリーク
                      _LightLeakButton(
                        current: cameraState.lightLeak,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          final next = LightLeakStrength.values[
                              (LightLeakStrength.values
                                          .indexOf(cameraState.lightLeak) +
                                      1) %
                                  LightLeakStrength.values.length];
                          ref
                              .read(cameraProvider.notifier)
                              .setLightLeak(next);
                        },
                      ),

                      const Spacer(),

                      ShutterButton(
                        isCapturing: cameraState.isCapturing,
                        onPressed: cameraState.canShoot ? _onShutter : null,
                      ),

                      const Spacer(),

                      // セルフタイマー
                      _TimerButton(
                        mode: cameraState.timerMode,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(cameraProvider.notifier).cycleTimerMode();
                        },
                      ),

                      // NOTE: シャッター音OFFは日本国内法規制により非提供
                      const SizedBox(width: 8),
                    ],
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
      lutIntensity: cameraState.lutIntensity,
      showGrid: cameraState.showGrid,
      lightLeak: cameraState.lightLeak,
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

// ── 汎用ヘッダーアイコンボタン ───────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: active ? activeColor : Colors.white38,
          size: 22,
        ),
      ),
    );
  }
}

// ── ライトリークボタン ────────────────────────────────────────

class _LightLeakButton extends StatelessWidget {
  final LightLeakStrength current;
  final VoidCallback onTap;

  const _LightLeakButton({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current != LightLeakStrength.none;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.orange.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active
                ? Colors.orange.withValues(alpha: 0.6)
                : Colors.white24,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flare,
              size: 14,
              color: active ? Colors.orange : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              current.label,
              style: TextStyle(
                color: active ? Colors.orange : Colors.white38,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── タイマーボタン ────────────────────────────────────────────

class _TimerButton extends StatelessWidget {
  final TimerMode mode;
  final VoidCallback onTap;

  const _TimerButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = mode != TimerMode.off;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? Colors.white54 : Colors.white24,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: 14,
              color: active ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              mode.label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LUT強度スライダー ─────────────────────────────────────────

class _LutIntensitySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _LutIntensitySlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text(
            'LUT',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 1.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white54,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── タイマーカウントダウンオーバーレイ ───────────────────────

class _TimerCountdownOverlay extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;

  const _TimerCountdownOverlay({required this.count, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 1.4, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w100,
                    letterSpacing: -4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'タップでキャンセル',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── フォーカスレティクル ──────────────────────────────────────

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

    final paths = [
      Path()
        ..moveTo(0, corner)
        ..lineTo(0, 0)
        ..lineTo(corner, 0),
      Path()
        ..moveTo(w - corner, 0)
        ..lineTo(w, 0)
        ..lineTo(w, corner),
      Path()
        ..moveTo(w, h - corner)
        ..lineTo(w, h)
        ..lineTo(w - corner, h),
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
