import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';

class ShareService {
  static Future<void> sharePhoto({
    required Photo photo,
    FilmSession? session,
  }) async {
    final subject = photo.subject ?? '';
    final memo = photo.memo ?? '';
    final location = session?.locationName ?? session?.title ?? '';

    final text = '''📷 ZootoCam
${subject.isNotEmpty ? subject : session?.title ?? ''}${location.isNotEmpty ? '\n$location' : ''}
${memo.isNotEmpty ? '\n$memo' : ''}

#ZootoCam''';

    final file = File(photo.imagePath);
    if (file.existsSync()) {
      await Share.shareXFiles(
        [XFile(photo.imagePath)],
        text: text,
      );
    } else {
      await Share.share(text);
    }
  }

  static Future<void> shareSession({
    required FilmSession session,
    required List<Photo> photos,
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

#ZootoCam''';

    final imagePaths = photos
        .where((p) => File(p.imagePath).existsSync())
        .take(4)
        .map((p) => XFile(p.imagePath))
        .toList();

    if (imagePaths.isNotEmpty) {
      await Share.shareXFiles(imagePaths, text: text);
    } else {
      await Share.share(text);
    }
  }
}
