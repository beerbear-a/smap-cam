import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/config/runtime_compatibility.dart';

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
        return '写ルんです ISO800';
      case LutType.warm:
        return 'Kodak Gold / 期限切れ';
      case LutType.fuji:
        return 'Superia 400';
      case LutType.mono:
        return 'HP5 Plus 400 B&W';
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

  // ── ライブプレビュー用 ColorFilter.matrix ────────────────────────────────
  //
  // NOTE: GLSLシェーダーはプラットフォームテクスチャに適用不可のため、
  //       ライブカメラプレビューは ColorFilter.matrix で近似する。
  //       静止画（現像・アルバム）は FilmShaderImage (GLSL) を使用。
  //
  // Matrix: [R_r, R_g, R_b, R_a, R_bias,  G_r ...  B_r ...]
  //   出力 R' = R_r*R + R_g*G + R_b*B + R_a*A + R_bias/255
  //   bias は 0-255 スケール。正値 = フロア持ち上げ（シャドウリフト）

  List<double> get colorMatrix {
    switch (this) {
      // ── 写ルんです ISO800 / Kodak Gold 200 ─────────────────────────────
      // 特性: 暖色・シャドウ持ち上げ・blue圧縮・ミルキーハイライト
      case LutType.natural:
        return [
          1.08, 0.04, -0.01, 0, 14, // R': 赤ブースト + 緑クロス + 暖色
          0.01, 0.96, 0.02, 0, 5, // G': ニュートラル
          -0.02, 0.00, 0.83, 0, -14, // B': blue圧縮（写ルんです最大の特徴）
          0, 0, 0, 1, 0,
        ];
      // ── ゴールデンアワー ─────────────────────────────────────────────────
      case LutType.warm:
        return [
          1.16,
          0.07,
          -0.03,
          0,
          24,
          0.02,
          0.97,
          0.01,
          0,
          10,
          -0.06,
          0.00,
          0.76,
          0,
          -22,
          0,
          0,
          0,
          1,
          0,
        ];
      // ── Fuji Superia 400/800 ─────────────────────────────────────────────
      // v2: VSCO Film 400H + Dazz Fuji に合わせてライブプレビューも更新
      //   bias (5列目) をシアン-緑色の D-min に合わせて調整
      //   R bias: -4 → -6  (赤を沈める = シアン感)
      //   G bias:  5 → 12  (緑フロアを上げる = Fuji 緑床)
      //   B bias:  7 → 18  (青フロアを上げる = シアン床 / faded 感)
      case LutType.fuji:
        return [
          0.92,  // R←R: 赤を少し引く（シアン）
          -0.03,
          0.01,
          0,
          -6,    // R bias: -4 → -6
          0.00,
          1.08,  // G←G: 1.06 → 1.08（Fuji 緑ブースト）
          0.04,
          0,
          12,    // G bias: 5 → 12（緑床を上げる）
          0.05,
          0.04,
          1.10,  // B←B: 1.08 → 1.10（シアン成分強化）
          0,
          18,    // B bias: 7 → 18（青床 = faded 感の核心）
          0,
          0,
          0,
          1,
          0,
        ];
      // ── Ilford HP5 Plus ──────────────────────────────────────────────────
      // パンクロマティック変換（緑高感度）
      case LutType.mono:
        return [
          0.215,
          0.652,
          0.133,
          0,
          0,
          0.215,
          0.652,
          0.133,
          0,
          0,
          0.215,
          0.652,
          0.133,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
    }
  }

  /// GLSL シェーダー用パラメータ（静止画現像・アルバム用）
  FilmShaderParams get shaderParams {
    switch (this) {
      case LutType.natural:
        return const FilmShaderParams(
          warmth: 0.85,
          saturation: 0.92,
          shadowLift: 0.55,
          highlightRolloff: 0.75,
          grainAmount: 0.85,
          vignetteStrength: 0.75,
          halationStrength: 0.65,
          softness: 0.55,
          chromaticAberration: 0.60,
          milkyHighlights: 0.80,
          contrast: -0.05,
          blueCrush: 0.18,
          halationWarmth: 0.75,
          grainSize: 2.0,
        );
      case LutType.warm:
        return const FilmShaderParams(
          warmth: 1.0,
          saturation: 0.90,
          shadowLift: 0.50,
          highlightRolloff: 0.80,
          grainAmount: 0.75,
          vignetteStrength: 0.80,
          halationStrength: 0.85,
          softness: 0.60,
          chromaticAberration: 0.55,
          milkyHighlights: 0.90,
          contrast: -0.10,
          blueCrush: 0.25,
          halationWarmth: 1.0,
          grainSize: 2.0,
        );
      case LutType.fuji:
        // v2: VSCO Film 400H + Dazz Fuji のいいとこどり
        //   shadowLift 0.35→0.78: VSCO faded 黒（D-min v2 強化に合わせ）
        //   halationStrength 0.30→0.60: Dazz の視認できる青-紫滲み（5x5 カーネル活用）
        //   grainAmount 0.65→0.90: Dazz の粗っぽい粒感
        //   saturation 1.10→1.18: Fuji の鮮やかな緑をもう一押し
        //   contrast 0.10→0.18: shadowLift で失ったコントラストを補填
        return const FilmShaderParams(
          warmth: 0.18,
          saturation: 1.18,
          shadowLift: 0.78,
          highlightRolloff: 0.65,
          grainAmount: 0.90,
          vignetteStrength: 0.60,
          halationStrength: 0.60,
          softness: 0.35,
          chromaticAberration: 0.35,
          milkyHighlights: 0.45,
          contrast: 0.18,
          blueCrush: 0.02,
          halationWarmth: 0.18,
          grainSize: 1.6,
        );
      case LutType.mono:
        return const FilmShaderParams(
          warmth: 0.0,
          saturation: 0.0,
          shadowLift: 0.45,
          highlightRolloff: 0.70,
          grainAmount: 1.00,
          vignetteStrength: 0.85,
          halationStrength: 0.40,
          softness: 0.50,
          chromaticAberration: 0.0,
          milkyHighlights: 0.60,
          contrast: 0.15,
          blueCrush: 0.0,
          halationWarmth: 0.0,
          grainSize: 1.8,
        );
    }
  }

  /// 静止画用 GLSL シェーダーアセットパス
  /// LUT ごとに専用シェーダーを持つことで、乳剤特性の差を正確に再現する。
  String get shaderAsset {
    switch (this) {
      case LutType.natural:
        return 'shaders/film_iso800.frag'; // 写ルんです QuickSnap ISO800
      case LutType.warm:
        return 'shaders/film_warm.frag'; // Kodak Gold / 期限切れフィルム
      case LutType.fuji:
        return 'shaders/film_fuji400.frag'; // Fujifilm Superia 400
      case LutType.mono:
        return 'shaders/film_mono_hp5.frag'; // Ilford HP5 Plus 400
    }
  }

  /// ビネットの強度（ライブプレビュー用 CustomPainter）
  double get vignetteStrength {
    switch (this) {
      case LutType.natural:
        return 0.52;
      case LutType.warm:
        return 0.58;
      case LutType.fuji:
        return 0.48; // 0.38 → 0.48: Dazz 相当の締まり感
      case LutType.mono:
        return 0.68;
    }
  }
}

// Identity matrix for LUT intensity interpolation
const _kIdentityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
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
// ライブカメラプレビュー用（プラットフォームテクスチャ → ColorFilter.matrix）

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
    // Grain animates at ~12fps (映写機の速度感 — 60fpsにしない)
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
          // 1. Color grade (intensity-interpolated) — raw texture is always
          //    covered by this layer, so we render only one Texture instance.
          ColorFiltered(
            colorFilter: ColorFilter.matrix(matrix),
            child: Texture(textureId: widget.textureId),
          ),

          // 2. Vignette (楕円形・プラスチックレンズ)
          CustomPaint(
            painter: _VignettePainter(
              strength: widget.lutType.vignetteStrength * widget.lutIntensity,
            ),
          ),

          // 3. Animated film grain (12fps, ISO800 粒子)
          AnimatedBuilder(
            animation: _grainController,
            builder: (_, __) => CustomPaint(
              painter: _GrainPainter(
                frame: (_grainController.value * 12).floor(),
                lutType: widget.lutType,
                intensity: widget.lutIntensity,
              ),
            ),
          ),

          // 4. Light leak
          if (widget.lightLeak != LightLeakStrength.none)
            IgnorePointer(
              child: CustomPaint(
                painter: _LightLeakPainter(strength: widget.lightLeak),
              ),
            ),

          // 5. Grid overlay
          if (widget.showGrid)
            const IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),

          // 6. Focus indicator (injected from parent)
          if (widget.focusIndicator != null) widget.focusIndicator!,
        ],
      ),
    );
  }
}

// ── Vignette Painter ─────────────────────────────────────────
// 楕円形ビネット: プラスチックレンズの周辺減光

class _VignettePainter extends CustomPainter {
  final double strength;

  const _VignettePainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.98,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: strength * 0.10),
        Colors.black.withValues(alpha: strength * 0.24),
        Colors.black.withValues(alpha: strength * 0.42),
      ],
      stops: const [0.42, 0.68, 0.84, 1.0],
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.0, 0.92);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VignettePainter old) => old.strength != strength;
}

// ── Grain Painter ────────────────────────────────────────────
// ISO800 銀塩粒子: グリッドっぽさを避けた微細ポイント分布

class _GrainPainter extends CustomPainter {
  final int frame;
  final LutType lutType;
  final double intensity;

  const _GrainPainter({
    required this.frame,
    required this.lutType,
    this.intensity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseSigma = switch (lutType) {
      LutType.mono => 0.092,
      LutType.warm => 0.065,
      LutType.fuji => 0.055,
      LutType.natural => 0.075,
    };
    final grainSigma = baseSigma * intensity;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = false;

    _paintGrainLayer(
      canvas,
      size,
      paint: paint,
      step: 5.0,
      frameOffset: frame,
      densityThreshold: 0.18,
      grainSigma: grainSigma,
      radiusBase: 0.22,
      radiusRange: 0.40,
      alphaScale: 0.40,
      monochrome: true,
    );
    _paintGrainLayer(
      canvas,
      size,
      paint: paint,
      step: 13.0,
      frameOffset: frame + 17,
      densityThreshold: 0.12,
      grainSigma: grainSigma,
      radiusBase: 0.55,
      radiusRange: 1.10,
      alphaScale: 0.12,
      monochrome: false,
    );
  }

  void _paintGrainLayer(
    Canvas canvas,
    Size size, {
    required Paint paint,
    required double step,
    required int frameOffset,
    required double densityThreshold,
    required double grainSigma,
    required double radiusBase,
    required double radiusRange,
    required double alphaScale,
    required bool monochrome,
  }) {
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        final hash = _pcgHash(x.toInt(), y.toInt(), frameOffset);
        final density = (hash & 0xFF) / 255.0;
        if (density > densityThreshold) continue;

        final h2 = ((hash >> 8) & 0xFF) / 255.0;
        final h3 = ((hash >> 16) & 0xFF) / 255.0;
        final h4 = ((hash >> 24) & 0xFF) / 255.0;

        final jitterX = (h2 - 0.5) * step * 0.9;
        final jitterY = (h3 - 0.5) * step * 0.9;
        final alpha = ((h2 + h3) * 0.5) * grainSigma * alphaScale;
        final radius = radiusBase + h4 * radiusRange;

        if (monochrome) {
          final isLight = h4 > 0.56;
          paint.color = isLight
              ? Colors.white.withValues(alpha: alpha.clamp(0.0, 0.06))
              : Colors.black.withValues(
                  alpha: (alpha * 0.82).clamp(0.0, 0.055),
                );
        } else {
          final warm = h2 > 0.55;
          paint.color = warm
              ? const Color(0xFFD8B07A).withValues(
                  alpha: alpha.clamp(0.0, 0.035),
                )
              : const Color(0xFF7A8FB8).withValues(
                  alpha: (alpha * 0.9).clamp(0.0, 0.03),
                );
        }

        canvas.drawCircle(Offset(x + jitterX, y + jitterY), radius, paint);
      }
    }
  }

  // PCG hash
  int _pcgHash(int x, int y, int f) {
    int h = (x * 374761393 + y * 668265263 + f * 2246822519).toUnsigned(32);
    h = ((h ^ (h >> 13)) * 1274126177).toUnsigned(32);
    return (h ^ (h >> 16)).toUnsigned(32);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.frame != frame || old.intensity != intensity;
}

// ── Light Leak Painter ───────────────────────────────────────

class _LightLeakPainter extends CustomPainter {
  final LightLeakStrength strength;

  const _LightLeakPainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = strength.opacity;

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
        leftRect, Paint()..shader = leftGrad.createShader(leftRect));

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
        rightRect, Paint()..shader = rightGrad.createShader(rightRect));
  }

  @override
  bool shouldRepaint(_LightLeakPainter old) => old.strength != strength;
}

// ── Grid Painter ─────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ═══════════════════════════════════════════════════════════════
// GLSL シェーダー パイプライン（静止画用）
// ═══════════════════════════════════════════════════════════════

// ── Film Shader Params ────────────────────────────────────────

class FilmShaderParams {
  final double warmth;
  final double saturation;
  final double shadowLift;
  final double highlightRolloff;
  final double grainAmount;
  final double vignetteStrength;
  final double halationStrength;
  final double softness;
  final double chromaticAberration;
  final double milkyHighlights;
  final double contrast;
  final double blueCrush;
  final double halationWarmth;
  final double grainSize;

  const FilmShaderParams({
    required this.warmth,
    required this.saturation,
    required this.shadowLift,
    required this.highlightRolloff,
    required this.grainAmount,
    required this.vignetteStrength,
    required this.halationStrength,
    required this.softness,
    required this.chromaticAberration,
    required this.milkyHighlights,
    required this.contrast,
    required this.blueCrush,
    required this.halationWarmth,
    required this.grainSize,
  });

  /// intensity (0–1) で identity とブレンド
  FilmShaderParams lerp(double t) => FilmShaderParams(
        warmth: warmth * t,
        saturation: 1.0 + (saturation - 1.0) * t,
        shadowLift: shadowLift * t,
        highlightRolloff: highlightRolloff * t,
        grainAmount: grainAmount * t,
        vignetteStrength: vignetteStrength * t,
        halationStrength: halationStrength * t,
        softness: softness * t,
        chromaticAberration: chromaticAberration * t,
        milkyHighlights: milkyHighlights * t,
        contrast: contrast * t,
        blueCrush: blueCrush * t,
        halationWarmth: halationWarmth * t,
        grainSize: grainSize,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilmShaderParams &&
        other.warmth == warmth &&
        other.saturation == saturation &&
        other.shadowLift == shadowLift &&
        other.highlightRolloff == highlightRolloff &&
        other.grainAmount == grainAmount &&
        other.vignetteStrength == vignetteStrength &&
        other.halationStrength == halationStrength &&
        other.softness == softness &&
        other.chromaticAberration == chromaticAberration &&
        other.milkyHighlights == milkyHighlights &&
        other.contrast == contrast &&
        other.blueCrush == blueCrush &&
        other.halationWarmth == halationWarmth &&
        other.grainSize == grainSize;
  }

  @override
  int get hashCode => Object.hash(
        warmth,
        saturation,
        shadowLift,
        highlightRolloff,
        grainAmount,
        vignetteStrength,
        halationStrength,
        softness,
        chromaticAberration,
        milkyHighlights,
        contrast,
        blueCrush,
        halationWarmth,
        grainSize,
      );
}

// ── Fragment Program Cache ────────────────────────────────────
// LUT ごとに専用シェーダーを持つため、Map でキャッシュする。

final _programCache = <String, ui.FragmentProgram>{};
final _programFutures = <String, Future<ui.FragmentProgram>>{};

Future<ui.FragmentProgram> _loadShaderProgram(String asset) {
  if (_programCache.containsKey(asset)) {
    return Future.value(_programCache[asset]!);
  }
  _programFutures[asset] ??= ui.FragmentProgram.fromAsset(asset).then((p) {
    _programCache[asset] = p;
    return p;
  }).catchError((Object error) {
    _programFutures.remove(asset);
    throw error;
  });
  return _programFutures[asset]!;
}

// ── Film Shader Painter ───────────────────────────────────────

class FilmShaderPainter extends CustomPainter {
  final ui.Image image;
  final ui.FragmentProgram program;
  final FilmShaderParams params;
  final double time;

  const FilmShaderPainter({
    required this.image,
    required this.program,
    required this.params,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    // float 0,1: u_size
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // float 2: u_time
    shader.setFloat(2, time);
    // float 3–16: LUT params (順序はシェーダーのuniform宣言に対応)
    shader.setFloat(3, params.warmth);
    shader.setFloat(4, params.saturation);
    shader.setFloat(5, params.shadowLift);
    shader.setFloat(6, params.highlightRolloff);
    shader.setFloat(7, params.grainAmount);
    shader.setFloat(8, params.vignetteStrength);
    shader.setFloat(9, params.halationStrength);
    shader.setFloat(10, params.softness);
    shader.setFloat(11, params.chromaticAberration);
    shader.setFloat(12, params.milkyHighlights);
    shader.setFloat(13, params.contrast);
    shader.setFloat(14, params.blueCrush);
    shader.setFloat(15, params.halationWarmth);
    shader.setFloat(16, params.grainSize);
    // float 17,18: source image dimensions (coverUV計算用)
    shader.setFloat(17, image.width.toDouble());
    shader.setFloat(18, image.height.toDouble());
    // image sampler 0
    shader.setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(FilmShaderPainter old) =>
      old.time != time || old.params != params || old.image != image;
}

// ── FilmShaderImage ───────────────────────────────────────────
//
// 静止画ファイルに GLSL シェーダーを適用するウィジェット。
// 現像画面・アルバム・フォト詳細で使用。

class FilmShaderImage extends StatefulWidget {
  final String imagePath;
  final LutType lutType;
  final double lutIntensity;
  final BoxFit fit;
  final bool animateGrain;

  const FilmShaderImage({
    super.key,
    required this.imagePath,
    required this.lutType,
    this.lutIntensity = 1.0,
    this.fit = BoxFit.cover,
    this.animateGrain = false,
  });

  @override
  State<FilmShaderImage> createState() => _FilmShaderImageState();
}

class _FilmShaderImageState extends State<FilmShaderImage>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  ui.FragmentProgram? _program;
  late AnimationController _grainController;
  bool _loading = true;

  bool get _useShaderPipeline => !RuntimeCompatibility.disableFragmentShaders;

  @override
  void initState() {
    super.initState();
    _grainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 83),
    );
    if (widget.animateGrain) _grainController.repeat();
    if (_useShaderPipeline) {
      _loadResources();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(FilmShaderImage old) {
    super.didUpdateWidget(old);
    if (!_useShaderPipeline) {
      if (widget.animateGrain && !old.animateGrain) {
        _grainController.repeat();
      } else if (!widget.animateGrain && old.animateGrain) {
        _grainController.stop();
      }
      if (_loading) {
        setState(() => _loading = false);
      }
      return;
    }
    if (old.lutType != widget.lutType) {
      // LUT が変わった → 別シェーダーファイルをロード
      _program = null;
      setState(() => _loading = true);
      _loadResources();
      return; // _loadResources 内で _loadImage も呼ばれる
    }
    if (old.imagePath != widget.imagePath) {
      _image?.dispose();
      _image = null;
      setState(() => _loading = true);
      _loadImage();
    }
    if (widget.animateGrain && !old.animateGrain) {
      _grainController.repeat();
    } else if (!widget.animateGrain && old.animateGrain) {
      _grainController.stop();
    }
  }

  Future<void> _loadResources() async {
    try {
      final program = await _loadShaderProgram(widget.lutType.shaderAsset);
      if (!mounted) return;
      setState(() => _program = program);
      await _loadImage();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _program = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      // targetWidth: デコード時にスケールダウン → メモリ・GPU 負荷削減
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image?.dispose();
          _image = frame.image;
          _loading = false;
        });
      } else {
        frame.image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _grainController.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_useShaderPipeline) {
      final file = File(widget.imagePath);
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.lutType.colorMatrix),
        child: file.existsSync()
            ? Image.file(file, fit: widget.fit)
            : const _MockPlaceholder(),
      );
    }

    if (_loading) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: Colors.white24,
              strokeWidth: 1,
            ),
          ),
        ),
      );
    }

    final image = _image;
    final program = _program;

    // シェーダー未ロード時: ColorFilter フォールバック
    if (image == null || program == null) {
      final file = File(widget.imagePath);
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.lutType.colorMatrix),
        child: file.existsSync()
            ? Image.file(file, fit: widget.fit)
            : const _MockPlaceholder(),
      );
    }

    final blended =
        widget.lutType.shaderParams.lerp(widget.lutIntensity.clamp(0.0, 1.0));

    return AnimatedBuilder(
      animation: _grainController,
      builder: (_, __) => CustomPaint(
        painter: FilmShaderPainter(
          image: image,
          program: program,
          params: blended,
          // animateGrain=false のとき time 固定 → グレイン静止
          time: widget.animateGrain ? _grainController.value * 100.0 : 0.5,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _MockPlaceholder extends StatelessWidget {
  const _MockPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF111111),
        child: const Center(
          child: Icon(Icons.photo, color: Colors.white12, size: 32),
        ),
      );
}

// ── FilmProcessedSurface ──────────────────────────────────────
//
// 任意の child ウィジェットにフィルムルックを適用するラッパー。
// カメラシミュレーター・現像画面・アルバムのチャイルドベース表示で使用。
//
// 実装: ColorFilter.matrix (カラーグレード) + CustomPainter (ビネット + グレイン)
// ※ 静止画ファイルへの高品質適用は FilmShaderImage を使用すること。

class FilmProcessedSurface extends StatefulWidget {
  final LutType lutType;
  final double lutIntensity;
  final bool animated; // true = 12fps グレインアニメーション
  final Widget child;

  const FilmProcessedSurface({
    super.key,
    required this.lutType,
    required this.child,
    this.lutIntensity = 1.0,
    this.animated = false,
  });

  @override
  State<FilmProcessedSurface> createState() => _FilmProcessedSurfaceState();
}

class _FilmProcessedSurfaceState extends State<FilmProcessedSurface>
    with SingleTickerProviderStateMixin {
  late AnimationController _grainController;

  @override
  void initState() {
    super.initState();
    _grainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 83), // 12fps
    );
    if (widget.animated) _grainController.repeat();
  }

  @override
  void didUpdateWidget(FilmProcessedSurface old) {
    super.didUpdateWidget(old);
    if (widget.animated && !old.animated) {
      _grainController.repeat();
    } else if (!widget.animated && old.animated) {
      _grainController.stop();
    }
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

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Color grade
        ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: widget.child,
        ),

        // 2. Vignette
        Positioned.fill(
          child: CustomPaint(
            painter: _VignettePainter(
              strength: widget.lutType.vignetteStrength * widget.lutIntensity,
            ),
          ),
        ),

        // 3. Grain (animated or static frame 0)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _grainController,
            builder: (_, __) => CustomPaint(
              painter: _GrainPainter(
                frame:
                    widget.animated ? (_grainController.value * 12).floor() : 0,
                lutType: widget.lutType,
                intensity: widget.lutIntensity,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
