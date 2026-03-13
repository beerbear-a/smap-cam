import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// WatermarkService
///
/// 写真に透かしを合成してテンポラリPNGとして返す。
/// 透かし形式: `@username · 動物園名 · ZOOSMAP`
/// 配置: 右下、グラデーション背景の上
class WatermarkService {
  WatermarkService._();

  static const double _watermarkHeight = 48.0;
  static const double _fontSize = 12.0;
  static const double _letterSpacing = 1.5;

  /// 画像に透かしを合成し、テンポラリPNGのパスを返す。
  ///
  /// [imagePath] — 元画像パス
  /// [username]  — ユーザー名 (空文字可、その場合は `ZOOSMAP` のみ)
  /// [locationName] — 動物園名 (空文字可)
  /// 戻り値: 透かし合成済みPNGのパス
  static Future<String> apply({
    required String imagePath,
    required String username,
    required String locationName,
  }) async {
    // 1. 元画像を読み込む
    final imageBytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final imgW = srcImage.width.toDouble();
    final imgH = srcImage.height.toDouble();

    // 2. キャンバスに元画像を描画
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(srcImage, Offset.zero, Paint());

    // 3. 下部グラデーション (透かし可読性のため)
    const gradientHeight = _watermarkHeight * 2.5;
    final gradientRect = Rect.fromLTWH(
      0,
      imgH - gradientHeight,
      imgW,
      gradientHeight,
    );
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC000000)],
      stops: [0.0, 1.0],
    );
    canvas.drawRect(
      gradientRect,
      Paint()..shader = gradient.createShader(gradientRect),
    );

    // 4. 透かしテキスト組み立て
    final label = _buildLabel(username: username, locationName: locationName);

    // 5. テキスト描画 (右下)
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.right,
        maxLines: 1,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xCCFFFFFF),
        fontSize: _fontSize,
        letterSpacing: _letterSpacing,
        fontWeight: FontWeight.w300,
        shadows: const [
          ui.Shadow(color: Colors.black, blurRadius: 6),
        ],
      ))
      ..addText(label);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: imgW - 24));

    canvas.drawParagraph(
      paragraph,
      Offset(12, imgH - _watermarkHeight + (_watermarkHeight - _fontSize) / 2),
    );

    srcImage.dispose();

    // 6. PNG として保存
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

  /// 透かし文字列を組み立てる。
  /// username が空なら `動物園名 · ZOOSMAP`、
  /// locationName も空なら `ZOOSMAP` のみ。
  static String _buildLabel({
    required String username,
    required String locationName,
  }) {
    final parts = <String>[];
    if (username.isNotEmpty) {
      parts.add('@$username');
    }
    if (locationName.isNotEmpty) {
      parts.add(locationName);
    }
    parts.add('ZOOSMAP');
    return parts.join(' · ');
  }
}
