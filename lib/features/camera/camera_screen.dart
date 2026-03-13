import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/film_session.dart';
import '../../core/services/camera_service.dart';
import '../develop/develop_screen.dart';
import 'camera_notifier.dart';
import 'widgets/film_counter_widget.dart';
import 'widgets/shutter_button.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(cameraProvider.notifier).loadActiveSession();
      await ref.read(cameraProvider.notifier).initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    // 現像フローへ自動遷移
    if (cameraState.activeSession?.status == FilmStatus.developing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DevelopScreen(
              sessionId: cameraState.activeSession!.sessionId,
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
          // カメラプレビュー（タップフォーカス付き）
          _TappableCameraPreview(cameraState: cameraState),

          // UI オーバーレイ
          SafeArea(
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ZootoCam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 4,
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

                // エラー表示
                if (cameraState.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      cameraState.error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),

                // シャッターボタン行
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
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
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 40),

                      // シャッター
                      ShutterButton(
                        isCapturing: cameraState.isCapturing,
                        onPressed: cameraState.canShoot
                            ? () =>
                                ref.read(cameraProvider.notifier).takePicture()
                            : null,
                      ),

                      const SizedBox(width: 68),
                    ],
                  ),
                ),

                // SHUTTER ラベル
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text(
                    'SHUTTER',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      letterSpacing: 4,
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
}

// ── タップフォーカス付きプレビュー ────────────────────────────

class _TappableCameraPreview extends StatefulWidget {
  final CameraState cameraState;

  const _TappableCameraPreview({required this.cameraState});

  @override
  State<_TappableCameraPreview> createState() => _TappableCameraPreviewState();
}

class _TappableCameraPreviewState extends State<_TappableCameraPreview>
    with SingleTickerProviderStateMixin {
  Offset? _focusPoint;
  late AnimationController _focusAnim;
  late Animation<double> _focusScale;

  @override
  void initState() {
    super.initState();
    _focusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _focusScale = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _focusAnim.dispose();
    super.dispose();
  }

  void _onTap(TapUpDetails details) {
    if (!widget.cameraState.isCameraReady) return;

    final size = context.size;
    if (size == null) return;

    final tapPos = details.localPosition;
    final x = (tapPos.dx / size.width).clamp(0.0, 1.0);
    final y = (tapPos.dy / size.height).clamp(0.0, 1.0);

    CameraService.setFocusPoint(x, y);

    setState(() => _focusPoint = tapPos);
    _focusAnim.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.cameraState.isCameraReady ||
        widget.cameraState.textureId == null) {
      return const _CameraLoadingView();
    }

    return GestureDetector(
      onTapUp: _onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Texture(textureId: widget.cameraState.textureId!),
          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: AnimatedBuilder(
                animation: _focusScale,
                builder: (_, __) => Transform.scale(
                  scale: _focusScale.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 1.5),
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white30),
          SizedBox(height: 16),
          Text(
            'カメラ準備中...',
            style: TextStyle(color: Colors.white38, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
