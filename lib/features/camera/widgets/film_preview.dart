import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Film Stock Definitions ───────────────────────────────────

enum LutType {
  natural,
  warm, // ゴールデンアワー — 無料2種目
  fuji,
  mono;

  String get label {
    switch (this) {
      case LutType.natural:
        return 'KODAK';
      case LutType.warm:
        return 'WARM';
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
      case LutType.warm:
        return 'Golden Hour';
      case LutType.fuji:
        return 'Superia';
      case LutType.mono:
        return 'HP5';
    }
  }

  /// FREE = true → Pro購入不要。POST-RELEASE で fuji/mono をゲートする。
  bool get isPro {
    switch (this) {
      case LutType.natural:
      case LutType.warm:
        return false;
      case LutType.fuji:
      case LutType.mono:
        return true;
    }
  }

  /// GLSL-style color matrix (20 values: 5×4 row-major for ColorFilter.matrix)
  List<double> get colorMatrix {
    switch (this) {
      // ── Kodak Gold 200: 暖色・シャドウ持ち上げ・低コントラスト ──
      case LutType.natural:
        return [
          1.10, 0.05, -0.02, 0, 8,
          0.02, 0.98, 0.00, 0, 3,
          -0.03, 0.00, 0.88, 0, -6,
          0, 0, 0, 1, 0,
        ];
      // ── Warm Golden Hour: 強い赤/黄・青大幅カット・夕焼け感 ──
      case LutType.warm:
        return [
          1.20, 0.08, -0.05, 0, 20,
          0.04, 1.02, 0.00, 0, 10,
          -0.08, 0.00, 0.78, 0, -18,
          0, 0, 0, 1, 0,
        ];
      // ── Fuji Superia: クール・高彩度・シアンシャドウ ──
      case LutType.fuji:
        return [
          0.95, -0.02, 0.00, 0, -2,
          0.00, 1.05, 0.03, 0, 4,
          0.04, 0.04, 1.08, 0, 6,
          0, 0, 0, 1, 0,
        ];
      // ── Ilford HP5: モノクロ・骨太グレイン感 ──
      case LutType.mono:
        return [
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }

  /// ビネットの強度
  double get vignetteStrength {
    switch (this) {
      case LutType.natural:
        return 0.45;
      case LutType.warm:
        return 0.50;
      case LutType.fuji:
        return 0.35;
      case LutType.mono:
        return 0.65;
    }
  }
}

// Identity matrix for LUT intensity interpolation
const _kIdentityMatrix = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _interpolateMatrix(List<double> lut, double t) {
  return List.generate(
    20,
    (i) => _kIdentityMatrix[i] + (lut[i] - _kIdentityMatrix[i]) * t,
  );
}

// ── Light Leak ───────────────────────────────────────────────

enum LightLeakStrength { none, weak, medium, strong }

extension LightLeakLabel on LightLeakStrength {
  String get label {
    switch (this) {
      case LightLeakStrength.none:
        return 'OFF';
      case LightLeakStrength.weak:
        return '弱';
      case LightLeakStrength.medium:
        return '中';
      case LightLeakStrength.strong:
        return '強';
    }
  }

  double get opacity {
    switch (this) {
      case LightLeakStrength.none:
        return 0;
      case LightLeakStrength.weak:
        return 0.25;
      case LightLeakStrength.medium:
        return 0.45;
      case LightLeakStrength.strong:
        return 0.70;
    }
  }
}

// ── FilmPreviewWidget ────────────────────────────────────────

class FilmPreviewWidget extends StatefulWidget {
  final int textureId;
  final LutType lutType;
  final double lutIntensity; // 0.0〜1.0
  final bool showGrid;
  final LightLeakStrength lightLeak;
  final Widget? focusIndicator;
  final void Function(TapUpDetails)? onTapUp;

  const FilmPreviewWidget({
    super.key,
    required this.textureId,
    required this.lutType,
    this.lutIntensity = 1.0,
    this.showGrid = false,
    this.lightLeak = LightLeakStrength.none,
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
      duration: const Duration(milliseconds: 83),
    )..repeat();
  }

  @override
  void dispose() {
    _grainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _interpolateMatrix(
      widget.lutType.colorMatrix,
      widget.lutIntensity,
    );

    return GestureDetector(
      onTapUp: widget.onTapUp,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Raw camera texture
          Texture(textureId: widget.textureId),

          // 2. Color grade (intensity-interpolated)
          ColorFiltered(
            colorFilter: ColorFilter.matrix(matrix),
            child: Texture(textureId: widget.textureId),
          ),

          // 3. Optical lens softness
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3),
            child: const SizedBox.expand(),
          ),

          // 4. Vignette
          CustomPaint(
            painter: _VignettePainter(
              strength:
                  widget.lutType.vignetteStrength * widget.lutIntensity,
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

          // 6. Light leak
          if (widget.lightLeak != LightLeakStrength.none)
            IgnorePointer(
              child: CustomPaint(
                painter: _LightLeakPainter(strength: widget.lightLeak),
              ),
            ),

          // 7. Grid overlay
          if (widget.showGrid)
            const IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),

          // 8. Focus indicator (injected from parent)
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

class _GrainPainter extends CustomPainter {
  final int frame;
  final LutType lutType;

  const _GrainPainter({required this.frame, required this.lutType});

  @override
  void paint(Canvas canvas, Size size) {
    const blockSize = 3.0;
    final grainStrength = lutType == LutType.mono ? 0.10 : 0.055;

    final paint = Paint()..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += blockSize) {
      for (double y = 0; y < size.height; y += blockSize) {
        final hash = _hash(x.toInt(), y.toInt(), frame);
        final t = hash & 0xFF;

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

  int _hash(int x, int y, int f) {
    int h = x * 374761393 + y * 668265263 + f * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    return h.abs();
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.frame != old.frame;
}

// ── Light Leak Painter ───────────────────────────────────────
// フィルム左端のオレンジ・赤のハレーション光漏れを再現

class _LightLeakPainter extends CustomPainter {
  final LightLeakStrength strength;

  const _LightLeakPainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = strength.opacity;

    // 左端から広がる光漏れ（オレンジ）
    final leftRect = Rect.fromLTWH(0, 0, size.width * 0.55, size.height);
    final leftGrad = RadialGradient(
      center: const Alignment(-1.0, 0.2),
      radius: 1.1,
      colors: [
        Colors.orange.withValues(alpha: opacity),
        Colors.deepOrange.withValues(alpha: opacity * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 1.0],
    );
    canvas.drawRect(
      leftRect,
      Paint()..shader = leftGrad.createShader(leftRect),
    );

    // 右上端の赤いハレーション（サブ）
    final rightRect = Rect.fromLTWH(
      size.width * 0.5,
      0,
      size.width * 0.5,
      size.height * 0.4,
    );
    final rightGrad = RadialGradient(
      center: const Alignment(1.2, -1.0),
      radius: 0.9,
      colors: [
        Colors.red.withValues(alpha: opacity * 0.5),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );
    canvas.drawRect(
      rightRect,
      Paint()..shader = rightGrad.createShader(rightRect),
    );
  }

  @override
  bool shouldRepaint(_LightLeakPainter old) => old.strength != strength;
}

// ── Grid Painter ─────────────────────────────────────────────
// 3×3 ルールグリッド（写真構図用）

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    // 縦2本
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // 横2本
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
