import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';

// ── 書き出しフォーマット ──────────────────────────────────────

enum ContactSheetFormat {
  /// 正方形グリッド（デフォルト）
  square,

  /// 現像後のインデックスプリント
  indexSheet,

  /// 9:16 縦長 — Instagram Story / ショート動画カバー対応
  story,
}

class ContactSheetService {
  // ── Square フォーマット定数 ──────────────────────────────────
  static const _cols = 3;
  static const _photoSize = 300.0;
  static const _gap = 3.0;
  static const _sidePad = 20.0;
  static const _sprocketH = 52.0;
  static const _metaH = 72.0;

  // ── Story フォーマット定数 ───────────────────────────────────
  static const _storyWidth = 1080.0;
  static const _storyHeight = 1920.0;
  static const _storyPhotoH = 360.0;
  static const _storyPhotoGap = 4.0;
  static const _storySidePad = 32.0;
  static const _storySprocketH = 60.0;
  static const _storyMetaH = 100.0;

  static Future<String> generate({
    required FilmSession session,
    required List<Photo> photos,
    ContactSheetFormat format = ContactSheetFormat.square,
    bool persist = false,
  }) {
    switch (format) {
      case ContactSheetFormat.square:
        return _generateSquare(
            session: session, photos: photos, persist: persist);
      case ContactSheetFormat.indexSheet:
        return _generateIndexSheet(
            session: session, photos: photos, persist: persist);
      case ContactSheetFormat.story:
        return _generateStory(
            session: session, photos: photos, persist: persist);
    }
  }

  // ── Square ───────────────────────────────────────────────────

  static Future<String> _generateSquare({
    required FilmSession session,
    required List<Photo> photos,
    required bool persist,
  }) async {
    final validPhotos =
        photos.where((p) => File(p.imagePath).existsSync()).toList();
    if (validPhotos.isEmpty) throw Exception('No photos available');

    final images =
        await Future.wait(validPhotos.map((p) => _loadImage(p.imagePath)));

    final rows = (images.length / _cols).ceil();
    const contentW = _cols * _photoSize + (_cols - 1) * _gap;
    const totalWidth = contentW + _sidePad * 2;
    final photoAreaH = rows * _photoSize + (rows - 1) * _gap;
    final totalHeight = _sprocketH + photoAreaH + _sprocketH + _metaH;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, totalWidth, totalHeight),
    );

    _fillBackground(
        canvas, totalWidth, totalHeight, const ui.Color(0xFF080808));
    _drawSprocketZone(canvas, 0, totalWidth, _sprocketH);

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

      final subject = validPhotos[i].subject;
      if (subject != null && subject.isNotEmpty) {
        _drawText(canvas, subject, x + 6, y + _photoSize - 18, 10,
            const ui.Color(0xEEFFFFFF),
            maxWidth: _photoSize - 12);
      }
    }

    final bottomSprocketY = _sprocketH + photoAreaH;
    _drawSprocketZone(canvas, bottomSprocketY, totalWidth, _sprocketH);

    final metaY = bottomSprocketY + _sprocketH;
    final location = session.locationName ?? session.title;
    final date = _formatDate(session.date);
    _drawText(canvas, '$location · $date', _sidePad, metaY + 26, 13,
        const ui.Color(0xFFBBBBBB),
        maxWidth: totalWidth * 0.7);
    _drawText(canvas, 'ZOOSMAP', totalWidth - _sidePad - 72, metaY + 26, 11,
        const ui.Color(0xFF555555),
        maxWidth: 80);

    return _saveCanvas(
      recorder: recorder,
      width: totalWidth.toInt(),
      height: totalHeight.toInt(),
      suffix: 'contact_${session.sessionId}',
      persist: persist,
    );
  }

  // ── Story (9:16) ─────────────────────────────────────────────

  static Future<String> _generateIndexSheet({
    required FilmSession session,
    required List<Photo> photos,
    required bool persist,
  }) async {
    final validPhotos =
        photos.where((p) => File(p.imagePath).existsSync()).toList();
    if (validPhotos.isEmpty) throw Exception('No photos available');

    // 9×3 = 27枚ちょうど収まるランドスケープ(3:2)レイアウト
    // 縦長セル(portrait)で縦位置写真のクロップを最小化
    const cols = 9;
    const rows = 3;
    const totalWidth = 900.0;
    const totalHeight = 600.0;
    const outerPad = 30.0;
    const topPad = 18.0;
    const headerH = 68.0;
    const footerH = 30.0;
    const bottomPad = 18.0;
    const gap = 8.0;

    // サムネイルサイズを動的計算
    const contentW = totalWidth - outerPad * 2;
    const thumbW = (contentW - (cols - 1) * gap) / cols; // ≈ 86.2
    const contentH = totalHeight - topPad - headerH - footerH - bottomPad; // 466
    const thumbH = (contentH - (rows - 1) * gap) / rows; // = 150

    final images =
        await Future.wait(validPhotos.map((p) => _loadImage(p.imagePath)));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const ui.Rect.fromLTWH(0, 0, totalWidth, totalHeight),
    );

    _fillBackground(
      canvas,
      totalWidth,
      totalHeight,
      const ui.Color(0xFFF7F2E8),
    );

    // ヘッダー: タイトル行
    _drawText(
      canvas,
      'INDEX PRINT',
      outerPad,
      topPad + 4,
      16,
      const ui.Color(0xFF2B2B2B),
      maxWidth: totalWidth * 0.45,
    );

    final location = session.locationName ?? session.title;
    final meta = [
      if (session.theme?.isNotEmpty == true) session.theme!,
      location,
      _formatDate(session.date),
      '${validPhotos.length} CUTS',
    ].join('  /  ');
    _drawText(
      canvas,
      meta,
      outerPad,
      topPad + 30,
      10,
      const ui.Color(0xFF5C5852),
      maxWidth: totalWidth - outerPad * 2,
    );

    // サムネイルグリッド
    for (int i = 0; i < images.length && i < cols * rows; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = outerPad + col * (thumbW + gap);
      final y = topPad + headerH + row * (thumbH + gap);
      final frame = ui.Rect.fromLTWH(x, y, thumbW, thumbH);

      // 外枠（乳白色）
      canvas.drawRect(
        frame.inflate(1.5),
        ui.Paint()..color = const ui.Color(0xFFE8E0D4),
      );
      // 黒背景
      canvas.drawRect(
        frame,
        ui.Paint()..color = const ui.Color(0xFF0F0F10),
      );

      // 写真（ラベル領域を除いた上部に配置）
      const labelH = 14.0;
      final photoRect = ui.Rect.fromLTWH(x, y, thumbW, thumbH - labelH);
      canvas.save();
      canvas.clipRect(photoRect);
      _drawImageCover(canvas, images[i], photoRect);
      canvas.restore();

      // フレーム番号
      _drawText(
        canvas,
        (i + 1).toString().padLeft(2, '0'),
        x + 3,
        y + thumbH - labelH + 2,
        7,
        const ui.Color(0xFFBBB3A8),
        maxWidth: thumbW - 6,
      );
    }

    // フッター: ブランド名
    _drawText(
      canvas,
      'ZOOSMAP',
      totalWidth - outerPad - 70,
      totalHeight - bottomPad - footerH + 8,
      10,
      const ui.Color(0xFF7E786E),
      maxWidth: 70,
    );

    return _saveCanvas(
      recorder: recorder,
      width: totalWidth.toInt(),
      height: totalHeight.toInt(),
      suffix: 'index_${session.sessionId}',
      persist: persist,
    );
  }

  static Future<String> _generateStory({
    required FilmSession session,
    required List<Photo> photos,
    required bool persist,
  }) async {
    final validPhotos =
        photos.where((p) => File(p.imagePath).existsSync()).toList();
    if (validPhotos.isEmpty) throw Exception('No photos available');

    // Story: 最大4枚縦並び
    final displayPhotos = validPhotos.take(4).toList();
    final images =
        await Future.wait(displayPhotos.map((p) => _loadImage(p.imagePath)));

    const totalWidth = _storyWidth;
    const totalHeight = _storyHeight;
    const photoW = totalWidth - _storySidePad * 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const ui.Rect.fromLTWH(0, 0, totalWidth, totalHeight),
    );

    // 背景
    _fillBackground(
        canvas, totalWidth, totalHeight, const ui.Color(0xFF060606));

    // 上スプロケット
    _drawSprocketZone(canvas, 0, totalWidth, _storySprocketH);

    // 写真縦並び（中央寄せ）
    final photoAreaH =
        images.length * _storyPhotoH + (images.length - 1) * _storyPhotoGap;
    final photoStartY =
        (_storyHeight - _storySprocketH * 2 - _storyMetaH - photoAreaH) / 2 +
            _storySprocketH;

    for (int i = 0; i < images.length; i++) {
      final y = photoStartY + i * (_storyPhotoH + _storyPhotoGap);
      final dst = ui.Rect.fromLTWH(_storySidePad, y, photoW, _storyPhotoH);

      canvas.save();
      canvas.clipRRect(
        ui.RRect.fromRectAndRadius(dst, const ui.Radius.circular(6)),
      );
      _drawImageCover(canvas, images[i], dst);
      _drawPhotoOverlay(canvas, dst);
      canvas.restore();

      final subject = displayPhotos[i].subject;
      if (subject != null && subject.isNotEmpty) {
        _drawText(
          canvas,
          subject,
          _storySidePad + 8,
          y + _storyPhotoH - 24,
          12,
          const ui.Color(0xEEFFFFFF),
          maxWidth: photoW - 16,
        );
      }
    }

    // 下スプロケット
    const bottomSprocketY = totalHeight - _storySprocketH - _storyMetaH;
    _drawSprocketZone(canvas, bottomSprocketY, totalWidth, _storySprocketH);

    // メタデータ
    const metaY = bottomSprocketY + _storySprocketH;
    final location = session.locationName ?? session.title;
    final date = _formatDate(session.date);
    _drawText(
      canvas,
      '$location · $date',
      _storySidePad,
      metaY + 32,
      16,
      const ui.Color(0xFFBBBBBB),
      maxWidth: totalWidth * 0.7,
    );
    _drawText(
      canvas,
      'ZOOSMAP',
      totalWidth - _storySidePad - 100,
      metaY + 32,
      14,
      const ui.Color(0xFF555555),
      maxWidth: 100,
    );

    return _saveCanvas(
      recorder: recorder,
      width: totalWidth.toInt(),
      height: totalHeight.toInt(),
      suffix: 'story_${session.sessionId}',
      persist: persist,
    );
  }

  // ── 共通ヘルパー ───────────────────────────────────────────

  static void _fillBackground(
    ui.Canvas canvas,
    double w,
    double h,
    ui.Color color,
  ) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = color,
    );
  }

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

  static void _drawPhotoOverlay(ui.Canvas canvas, ui.Rect dst) {
    final gradRect = ui.Rect.fromLTWH(dst.left, dst.bottom - 50, dst.width, 50);
    final gradient = ui.Gradient.linear(
      ui.Offset(dst.left, dst.bottom - 50),
      ui.Offset(dst.left, dst.bottom),
      [const ui.Color(0x00000000), const ui.Color(0xAA000000)],
    );
    canvas.drawRect(gradRect, ui.Paint()..shader = gradient);
  }

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

  static Future<String> _saveCanvas({
    required ui.PictureRecorder recorder,
    required int width,
    required int height,
    required String suffix,
    required bool persist,
  }) async {
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    final dir = persist
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();
    final baseDir = persist
        ? Directory('${dir.path}/zoosmap/index_sheets')
        : Directory(dir.path);
    await baseDir.create(recursive: true);
    final file = File('${baseDir.path}/zoosmap_$suffix.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file.path;
  }
}
