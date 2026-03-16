import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// ── 透かし位置 ────────────────────────────────────────────────

enum WatermarkPosition {
  bottomRight,
  bottomLeft,
  bottomCenter;

  String get label {
    switch (this) {
      case WatermarkPosition.bottomRight:
        return '右下';
      case WatermarkPosition.bottomLeft:
        return '左下';
      case WatermarkPosition.bottomCenter:
        return '中央下';
    }
  }
}

/// WatermarkService
///
/// 写真に透かしを合成してテンポラリPNGとして返す。
/// 透かし形式: `@username · 場所名 · ZOOSMAP`
class WatermarkService {
  WatermarkService._();

  static const double _watermarkHeight = 48.0;
  static const double _fontSize = 12.0;
  static const double _letterSpacing = 1.5;
  static const double _sidePad = 12.0;

  static Future<String> apply({
    required String imagePath,
    required String username,
    required String locationName,
    WatermarkPosition position = WatermarkPosition.bottomRight,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final imgW = srcImage.width.toDouble();
    final imgH = srcImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(srcImage, Offset.zero, Paint());

    // 下部グラデーション
    const gradientHeight = _watermarkHeight * 2.5;
    final gradientRect = Rect.fromLTWH(
      0,
      imgH - gradientHeight,
      imgW,
      gradientHeight,
    );
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC000000)],
    );
    canvas.drawRect(
      gradientRect,
      Paint()..shader = gradient.createShader(gradientRect),
    );

    // 透かしテキスト
    final label = _buildLabel(username: username, locationName: locationName);
    final textY = imgH - _watermarkHeight + (_watermarkHeight - _fontSize) / 2;

    switch (position) {
      case WatermarkPosition.bottomRight:
        _drawAlignedText(
          canvas,
          label,
          x: _sidePad,
          y: textY,
          maxWidth: imgW - _sidePad * 2,
          align: TextAlign.right,
        );
      case WatermarkPosition.bottomLeft:
        _drawAlignedText(
          canvas,
          label,
          x: _sidePad,
          y: textY,
          maxWidth: imgW - _sidePad * 2,
          align: TextAlign.left,
        );
      case WatermarkPosition.bottomCenter:
        _drawAlignedText(
          canvas,
          label,
          x: 0,
          y: textY,
          maxWidth: imgW,
          align: TextAlign.center,
        );
    }

    srcImage.dispose();

    final picture = recorder.endRecording();
    final composited = await picture.toImage(imgW.toInt(), imgH.toInt());
    final byteData =
        await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();
    picture.dispose();

    final pngBytes = byteData!.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final baseName =
        'zoosmap_wm_${DateTime.now().millisecondsSinceEpoch}.png';
    final outFile = File('${tempDir.path}/$baseName');
    await outFile.writeAsBytes(pngBytes, flush: true);
    return outFile.path;
  }

  static void _drawAlignedText(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double maxWidth,
    required TextAlign align,
  }) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: align,
        maxLines: 1,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xCCFFFFFF),
        fontSize: _fontSize,
        letterSpacing: _letterSpacing,
        fontWeight: ui.FontWeight.w300,
        shadows: const [ui.Shadow(color: ui.Color(0xFF000000), blurRadius: 6)],
      ))
      ..addText(text);

    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  static String _buildLabel({
    required String username,
    required String locationName,
  }) {
    final parts = <String>[];
    if (username.isNotEmpty) parts.add('@$username');
    if (locationName.isNotEmpty) parts.add(locationName);
    parts.add('ZOOSMAP');
    return parts.join(' · ');
  }
}
