import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import 'watermark_service.dart';

class ShareService {
  /// 1枚の写真をシェア。透かしを合成してから渡す。
  static Future<void> sharePhoto({
    required Photo photo,
    FilmSession? session,
    String username = '',
  }) async {
    final subject = photo.subject ?? '';
    final memo = photo.memo ?? '';
    final location = session?.locationName ?? session?.title ?? '';

    final text = '''📷 ZootoCam
${subject.isNotEmpty ? subject : session?.title ?? ''}${location.isNotEmpty ? '\n$location' : ''}
${memo.isNotEmpty ? '\n$memo' : ''}

#ZootoCam #ZOOSMAP''';

    final file = File(photo.imagePath);
    if (file.existsSync()) {
      final watermarkedPath = await WatermarkService.apply(
        imagePath: photo.imagePath,
        username: username,
        locationName: location,
      );
      await Share.shareXFiles(
        [XFile(watermarkedPath)],
        text: text,
      );
    } else {
      await Share.share(text);
    }
  }

  /// セッション（複数写真）をシェア。先頭4枚に透かしを合成する。
  static Future<void> shareSession({
    required FilmSession session,
    required List<Photo> photos,
    String username = '',
  }) async {
    final location = session.locationName ?? session.title;
    final memo = session.memo ?? '';

    final subjects = photos
        .where((p) => p.subject != null && p.subject!.isNotEmpty)
        .map((p) => p.subject!)
        .toSet()
        .join(', ');

    final text = '''📷 ZootoCam
$location${subjects.isNotEmpty ? '\n$subjects' : ''}
${memo.isNotEmpty ? '\n$memo' : ''}

#ZootoCam #ZOOSMAP''';

    final existingPhotos =
        photos.where((p) => File(p.imagePath).existsSync()).take(4).toList();

    if (existingPhotos.isNotEmpty) {
      // 全写真に非同期で透かし合成
      final watermarkedPaths = await Future.wait(
        existingPhotos.map(
          (p) => WatermarkService.apply(
            imagePath: p.imagePath,
            username: username,
            locationName: location,
          ),
        ),
      );
      await Share.shareXFiles(
        watermarkedPaths.map((path) => XFile(path)).toList(),
        text: text,
      );
    } else {
      await Share.share(text);
    }
  }
}
