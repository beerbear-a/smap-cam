import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';

class ContactSheetService {
  static const _cols = 3;
  static const _photoSize = 300.0;
  static const _gap = 3.0;
  static const _sidePad = 20.0;
  static const _sprocketH = 52.0;
  static const _metaH = 72.0;

  static Future<String> generate({
    required FilmSession session,
    required List<Photo> photos,
  }) async {
    final validPhotos =
        photos.where((p) => File(p.imagePath).existsSync()).toList();
    if (validPhotos.isEmpty) throw Exception('No photos available');

    final images =
        await Future.wait(validPhotos.map((p) => _loadImage(p.imagePath)));

    final rows = (images.length / _cols).ceil();
    final contentW = _cols * _photoSize + (_cols - 1) * _gap;
    final totalWidth = contentW + _sidePad * 2;
    final photoAreaH = rows * _photoSize + (rows - 1) * _gap;
    final totalHeight = _sprocketH + photoAreaH + _sprocketH + _metaH;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, totalWidth, totalHeight),
    );

    // ── 背景 ──────────────────────────────────────────
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, totalWidth, totalHeight),
      ui.Paint()..color = const ui.Color(0xFF080808),
    );

    // ── 上スプロケット ─────────────────────────────────
    _drawSprocketZone(canvas, 0, totalWidth, _sprocketH);

    // ── 写真グリッド ───────────────────────────────────
    for (int i = 0; i < images.length; i++) {
      final col = i % _cols;
      final row = i ~/ _cols;
      final x = _sidePad + col * (_photoSize + _gap);
      final y = _sprocketH + row * (_photoSize + _gap);
      final dst = ui.Rect.fromLTWH(x, y, _photoSize, _photoSize);

      canvas.save();
      canvas.clipRect(dst);
      _drawImageCover(canvas, images[i], dst);
      _drawPhotoOverlay(canvas, dst);
      canvas.restore();

      // 動物名ラベル
      final subject = validPhotos[i].subject;
      if (subject != null && subject.isNotEmpty) {
        _drawText(
          canvas,
          subject,
          x + 6,
          y + _photoSize - 18,
          10,
          const ui.Color(0xEEFFFFFF),
          maxWidth: _photoSize - 12,
        );
      }
    }

    // ── 下スプロケット ─────────────────────────────────
    final bottomSprocketY = _sprocketH + photoAreaH;
    _drawSprocketZone(canvas, bottomSprocketY, totalWidth, _sprocketH);

    // ── メタデータ ─────────────────────────────────────
    final metaY = bottomSprocketY + _sprocketH;
    final location = session.locationName ?? session.title;
    final date = _formatDate(session.createdAt);
    _drawText(
      canvas,
      '$location · $date',
      _sidePad,
      metaY + 26,
      13,
      const ui.Color(0xFFBBBBBB),
      maxWidth: totalWidth * 0.7,
    );
    _drawText(
      canvas,
      'ZOOSMAP',
      totalWidth - _sidePad - 72,
      metaY + 26,
      11,
      const ui.Color(0xFF555555),
      maxWidth: 80,
    );

    // ── PNG 書き出し ───────────────────────────────────
    final picture = recorder.endRecording();
    final img = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/zoosmap_contact_${session.sessionId}.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file.path;
  }

  // ── スプロケットゾーン描画 ──────────────────────────

  static void _drawSprocketZone(
    ui.Canvas canvas,
    double y,
    double totalWidth,
    double h,
  ) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, y, totalWidth, h),
      ui.Paint()..color = const ui.Color(0xFF181818),
    );

    const holeW = 14.0;
    const holeH = 9.0;
    const spacing = 22.0;
    final holeY = y + (h - holeH) / 2;
    final holePaint = ui.Paint()..color = const ui.Color(0xFF080808);

    var x = 14.0;
    while (x + holeW < totalWidth - 14) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, holeY, holeW, holeH),
          const ui.Radius.circular(2),
        ),
        holePaint,
      );
      x += spacing;
    }
  }

  // ── BoxFit.cover で画像を描画 ─────────────────────

  static void _drawImageCover(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect dst,
  ) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scale = math.max(dst.width / imgW, dst.height / imgH);
    final srcLeft = (imgW - dst.width / scale) / 2;
    final srcTop = (imgH - dst.height / scale) / 2;
    final src = ui.Rect.fromLTWH(
      srcLeft,
      srcTop,
      dst.width / scale,
      dst.height / scale,
    );
    canvas.drawImageRect(image, src, dst, ui.Paint());
  }

  // ── 写真下部グラデーション ────────────────────────

  static void _drawPhotoOverlay(ui.Canvas canvas, ui.Rect dst) {
    final gradRect =
        ui.Rect.fromLTWH(dst.left, dst.bottom - 50, dst.width, 50);
    final gradient = ui.Gradient.linear(
      ui.Offset(dst.left, dst.bottom - 50),
      ui.Offset(dst.left, dst.bottom),
      [const ui.Color(0x00000000), const ui.Color(0xAA000000)],
    );
    canvas.drawRect(gradRect, ui.Paint()..shader = gradient);
  }

  // ── テキスト描画 ───────────────────────────────────

  static void _drawText(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    ui.Color color, {
    double maxWidth = 400,
  }) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fontSize, maxLines: 1, ellipsis: '...'),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        letterSpacing: 0.5,
      ))
      ..addText(text);
    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  static Future<ui.Image> _loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
