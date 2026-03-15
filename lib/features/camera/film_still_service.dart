import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'widgets/film_preview.dart';

class FilmStillService {
  FilmStillService._();

  static Future<String> bakeFilmPhoto({
    required String inputPath,
    required String outputPath,
    LutType lutType = LutType.natural,
    double intensity = 1.0,
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
    final gradient = ui.Gradient.radial(
      ui.Offset(size.width / 2, size.height / 2),
      math.max(size.width, size.height) * 0.62,
      [
        const ui.Color(0x00000000),
        ui.Color.fromRGBO(0, 0, 0, strength * 0.45),
        ui.Color.fromRGBO(0, 0, 0, strength * 0.92),
      ],
      const [0.38, 0.68, 1.0],
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.0, 0.88);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, ui.Paint()..shader = gradient);
    canvas.restore();
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
    final random = math.Random(seed);
    final paint = ui.Paint()..style = ui.PaintingStyle.fill;

    final step = math.max(3.0, math.min(size.width, size.height) / 220.0);
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if (random.nextDouble() > 0.42) continue;

        final jitterX = (random.nextDouble() - 0.5) * 2.0;
        final jitterY = (random.nextDouble() - 0.5) * 2.0;
        final alpha = random.nextDouble() * grainSigma * 0.55;
        final radius = 0.35 + random.nextDouble() * 0.55;
        final isLight = random.nextDouble() > 0.55;

        paint.color = isLight
            ? ui.Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 0.06))
            : ui.Color.fromRGBO(
                0,
                0,
                0,
                (alpha * 0.75).clamp(0.0, 0.05),
              );

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
