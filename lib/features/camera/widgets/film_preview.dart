import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Film Stock Definitions ───────────────────────────────────

enum LutType {
  natural,
  fuji,
  mono;

  String get label {
    switch (this) {
      case LutType.natural:
        return 'KODAK';
      case LutType.fuji:
        return 'FUJI';
      case LutType.mono:
        return 'MONO';
    }
  }

  String get subtitle {
    switch (this) {
      case LutType.natural:
        return 'Gold 200';
      case LutType.fuji:
        return 'Superia';
      case LutType.mono:
        return 'HP5';
    }
  }

  /// GLSL-style color matrix (20 values: 5×4 row-major for ColorFilter.matrix)
  /// [R_r, R_g, R_b, R_a, R_const,
  ///  G_r, G_g, G_b, G_a, G_const,
  ///  B_r, B_g, B_b, B_a, B_const,
  ///  A_r, A_g, A_b, A_a, A_const]
  List<double> get colorMatrix {
    switch (this) {
      // ── Kodak Gold 200: 暖色・シャドウ持ち上げ・低コントラスト ──
      case LutType.natural:
        return [
          1.10,  0.05, -0.02, 0,  8,
          0.02,  0.98,  0.00, 0,  3,
         -0.03,  0.00,  0.88, 0, -6,
          0,     0,     0,    1,  0,
        ];
      // ── Fuji Superia: クール・高彩度・シアンシャドウ ──
      case LutType.fuji:
        return [
          0.95, -0.02,  0.00, 0, -2,
          0.00,  1.05,  0.03, 0,  4,
          0.04,  0.04,  1.08, 0,  6,
          0,     0,     0,    1,  0,
        ];
      // ── Ilford HP5: モノクロ・骨太グレイン感 ──
      case LutType.mono:
        return [
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0,     0,     0,     1, 0,
        ];
    }
  }

  /// ビネットの強度
  double get vignetteStrength {
    switch (this) {
      case LutType.natural:
        return 0.45;
      case LutType.fuji:
        return 0.35;
      case LutType.mono:
        return 0.65; // モノクロはビネット強め
    }
  }
}

// ── FilmPreviewWidget ────────────────────────────────────────

class FilmPreviewWidget extends StatefulWidget {
  final int textureId;
  final LutType lutType;
  final Widget? focusIndicator;
  final void Function(TapUpDetails)? onTapUp;

  const FilmPreviewWidget({
    super.key,
    required this.textureId,
    required this.lutType,
    this.focusIndicator,
    this.onTapUp,
  });

  @override
  State<FilmPreviewWidget> createState() => _FilmPreviewWidgetState();
}

class _FilmPreviewWidgetState extends State<FilmPreviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _grainController;

  @override
  void initState() {
    super.initState();
    // Grain animates at ~12fps (film-like, not digital-smooth)
    _grainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 83), // ~12fps
    )..repeat();
  }

  @override
  void dispose() {
    _grainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: widget.onTapUp,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Raw camera texture
          Texture(textureId: widget.textureId),

          // 2. Color grade (ColorFilter is GPU-accelerated via Flutter's Skia/Impeller)
          ColorFiltered(
            colorFilter: ColorFilter.matrix(widget.lutType.colorMatrix),
            child: Texture(textureId: widget.textureId),
          ),

          // 3. Optical lens softness (film lenses have ~0.3-0.5px spread vs digital)
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3),
            child: const SizedBox.expand(),
          ),

          // 4. Vignette (CustomPaint — radial gradient)
          CustomPaint(
            painter: _VignettePainter(
              strength: widget.lutType.vignetteStrength,
            ),
          ),

          // 5. Animated film grain
          AnimatedBuilder(
            animation: _grainController,
            builder: (_, __) => CustomPaint(
              painter: _GrainPainter(
                frame: (_grainController.value * 12).floor(),
                lutType: widget.lutType,
              ),
            ),
          ),

          // 6. Focus indicator (injected from parent)
          if (widget.focusIndicator != null) widget.focusIndicator!,
        ],
      ),
    );
  }
}

// ── Vignette Painter ─────────────────────────────────────────

class _VignettePainter extends CustomPainter {
  final double strength;

  const _VignettePainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: strength * 0.5),
        Colors.black.withValues(alpha: strength),
      ],
      stops: const [0.40, 0.72, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_VignettePainter old) => old.strength != strength;
}

// ── Grain Painter ────────────────────────────────────────────
// Stamp-based grain: 画面を 4×4 ブロックに分割し、各フレームで
// ランダムな明度変化を素早く描画する。
// 完全ランダム per-pixel よりも 60× 高速。

class _GrainPainter extends CustomPainter {
  final int frame;
  final LutType lutType;

  const _GrainPainter({required this.frame, required this.lutType});

  @override
  void paint(Canvas canvas, Size size) {
    const blockSize = 3.0;
    final grainStrength = lutType == LutType.mono ? 0.10 : 0.055;

    // Deterministic random from (x, y, frame) hash
    final paint = Paint()..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += blockSize) {
      for (double y = 0; y < size.height; y += blockSize) {
        final hash = _hash(x.toInt(), y.toInt(), frame);
        final t = hash & 0xFF;

        // Only paint some blocks (sparsity = film characteristic)
        if (t > 160) continue;

        final alpha = (t / 255.0) * grainStrength;
        final isLight = (hash >> 8) & 1 == 1;

        paint.color = isLight
            ? Colors.white.withValues(alpha: alpha)
            : Colors.black.withValues(alpha: alpha * 0.6);

        canvas.drawRect(
          Rect.fromLTWH(x, y, blockSize, blockSize),
          paint,
        );
      }
    }
  }

  // Fast integer hash: frame-varied, spatially distributed
  int _hash(int x, int y, int f) {
    int h = x * 374761393 + y * 668265263 + f * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    return h.abs();
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.frame != old.frame;
}
