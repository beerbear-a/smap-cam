import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/config/runtime_compatibility.dart';
import '../../shader/fragment_program_cache.dart';
import 'widgets/film_preview.dart';

class FilmStillService {
  FilmStillService._();

  static Future<String> bakeFilmPhoto({
    required String inputPath,
    required String outputPath,
    LutType lutType = LutType.natural,
    double intensity = 1.0,
    String? shaderAssetOverride,
  }) async {
    if (RuntimeCompatibility.disableFragmentShaders) {
      return _bakeWithCanvas(
        inputPath: inputPath,
        outputPath: outputPath,
        lutType: lutType,
        intensity: intensity,
      );
    }

    return _bakeWithShader(
      inputPath: inputPath,
      outputPath: outputPath,
      lutType: lutType,
      intensity: intensity,
      shaderAssetOverride: shaderAssetOverride,
    );
  }

  static Future<String> _bakeWithShader({
    required String inputPath,
    required String outputPath,
    required LutType lutType,
    required double intensity,
    String? shaderAssetOverride,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1800,
    );
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final width = srcImage.width.toDouble();
    final height = srcImage.height.toDouble();
    final size = ui.Size(width, height);

    final shaderAsset = shaderAssetOverride ?? lutType.shaderAsset;
    final program = await loadFragmentProgram(shaderAsset);
    final shader = program.fragmentShader();

    final params =
        lutType.shaderParams.lerp(intensity.clamp(0.0, 1.0));
    final seed = _stableSeed(inputPath);
    final time = (seed % 1000) / 10.0;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
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
    shader.setFloat(17, srcImage.width.toDouble());
    shader.setFloat(18, srcImage.height.toDouble());
    shader.setFloat(19, params.distortion);
    shader.setFloat(20, params.shadowDesat);
    shader.setFloat(21, params.colorSplit);
    shader.setFloat(22, params.crossover);
    shader.setFloat(23, params.bloomStrength);
    shader.setImageSampler(0, srcImage);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width, height),
    );

    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..shader = shader,
    );

    final picture = recorder.endRecording();
    final processed = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await processed.toByteData(format: ui.ImageByteFormat.png);

    processed.dispose();
    picture.dispose();
    srcImage.dispose();

    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) {
      throw Exception('フィルム画像の書き出しに失敗しました');
    }

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(pngBytes, flush: true);
    return outFile.path;
  }

  static Future<String> _bakeWithCanvas({
    required String inputPath,
    required String outputPath,
    required LutType lutType,
    required double intensity,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1800,
    );
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final width = srcImage.width.toDouble();
    final height = srcImage.height.toDouble();
    final size = ui.Size(width, height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width, height),
    );

    final paint = ui.Paint()
      ..colorFilter = ui.ColorFilter.matrix(
        _interpolateMatrix(lutType.colorMatrix, intensity.clamp(0.0, 1.0)),
      )
      ..filterQuality = ui.FilterQuality.high;

    canvas.drawImage(srcImage, ui.Offset.zero, paint);
    _drawVignette(
      canvas,
      size,
      lutType.vignetteStrength * intensity.clamp(0.0, 1.0),
    );
    _drawGrain(
      canvas,
      size,
      lutType: lutType,
      intensity: intensity.clamp(0.0, 1.0),
      seed: _stableSeed(inputPath),
    );

    final picture = recorder.endRecording();
    final processed = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await processed.toByteData(format: ui.ImageByteFormat.png);

    processed.dispose();
    picture.dispose();
    srcImage.dispose();

    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) {
      throw Exception('フィルム画像の書き出しに失敗しました');
    }

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(pngBytes, flush: true);
    return outFile.path;
  }

  static List<double> _interpolateMatrix(List<double> lut, double t) {
    const identity = <double>[
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
    return List.generate(
      20,
      (i) => identity[i] + (lut[i] - identity[i]) * t,
    );
  }

  static void _drawVignette(ui.Canvas canvas, ui.Size size, double strength) {
    if (strength <= 0) return;

    final rect = ui.Offset.zero & size;
    final center = ui.Offset(size.width / 2, size.height / 2);
    final outer = ui.Path()..addRect(rect);
    final rings = [
      (1.08, 0.36, strength * 0.14),
      (0.96, 0.50, strength * 0.20),
      (0.84, 0.64, strength * 0.28),
      (0.72, 0.76, strength * 0.36),
    ];

    for (final (widthScale, heightScale, alpha) in rings) {
      final inner = ui.Path()
        ..addOval(
          ui.Rect.fromCenter(
            center: center,
            width: size.width * widthScale,
            height: size.height * heightScale,
          ),
        );
      final ring = ui.Path.combine(ui.PathOperation.difference, outer, inner);
      canvas.drawPath(
        ring,
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
      );
    }
  }

  static void _drawGrain(
    ui.Canvas canvas,
    ui.Size size, {
    required LutType lutType,
    required double intensity,
    required int seed,
  }) {
    final baseSigma = switch (lutType) {
      LutType.mono => 0.092,
      LutType.warm => 0.065,
      LutType.fuji => 0.055,
      LutType.natural => 0.075,
    };
    final grainSigma = baseSigma * intensity;
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = false;

    _drawGrainLayer(
      canvas,
      size,
      paint: paint,
      step: math.max(3.0, math.min(size.width, size.height) / 260.0),
      seed: seed,
      densityThreshold: 0.20,
      grainSigma: grainSigma,
      radiusBase: 0.22,
      radiusRange: 0.55,
      alphaScale: 0.46,
      monochrome: true,
    );
    _drawGrainLayer(
      canvas,
      size,
      paint: paint,
      step: math.max(10.0, math.min(size.width, size.height) / 120.0),
      seed: seed ^ 0x9E3779B9,
      densityThreshold: 0.11,
      grainSigma: grainSigma,
      radiusBase: 0.8,
      radiusRange: 1.6,
      alphaScale: 0.14,
      monochrome: false,
    );
  }

  static void _drawGrainLayer(
    ui.Canvas canvas,
    ui.Size size, {
    required ui.Paint paint,
    required double step,
    required int seed,
    required double densityThreshold,
    required double grainSigma,
    required double radiusBase,
    required double radiusRange,
    required double alphaScale,
    required bool monochrome,
  }) {
    final random = math.Random(seed);
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if (random.nextDouble() > densityThreshold) continue;

        final jitterX = (random.nextDouble() - 0.5) * step * 0.9;
        final jitterY = (random.nextDouble() - 0.5) * step * 0.9;
        final alpha = random.nextDouble() * grainSigma * alphaScale;
        final radius = radiusBase + random.nextDouble() * radiusRange;

        if (monochrome) {
          final isLight = random.nextDouble() > 0.56;
          paint.color = isLight
              ? ui.Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 0.06))
              : ui.Color.fromRGBO(
                  0,
                  0,
                  0,
                  (alpha * 0.82).clamp(0.0, 0.055),
                );
        } else {
          final isWarm = random.nextDouble() > 0.5;
          paint.color = isWarm
              ? ui.Color.fromRGBO(216, 176, 122, alpha.clamp(0.0, 0.035))
              : ui.Color.fromRGBO(
                  122,
                  143,
                  184,
                  (alpha * 0.9).clamp(0.0, 0.03),
                );
        }

        canvas.drawCircle(ui.Offset(x + jitterX, y + jitterY), radius, paint);
      }
    }
  }

  static int _stableSeed(String input) {
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
