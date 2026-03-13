import 'package:flutter_test/flutter_test.dart';
import 'package:smap_cam/core/models/film_session.dart';
import 'package:smap_cam/core/models/photo.dart';

void main() {
  group('FilmSession', () {
    test('maxPhotos is 27', () {
      expect(FilmSession.maxPhotos, 27);
    });

    test('remainingShots decrements correctly', () {
      final session = FilmSession(
        sessionId: 'test-id',
        title: 'Test',
        date: DateTime.now(),
        photoCount: 5,
      );
      expect(session.remainingShots, 22);
    });

    test('isFull when photoCount == 27', () {
      final session = FilmSession(
        sessionId: 'test-id',
        title: 'Test',
        date: DateTime.now(),
        photoCount: 27,
      );
      expect(session.isFull, true);
    });

    test('toMap / fromMap roundtrip', () {
      final original = FilmSession(
        sessionId: 'abc',
        title: '上野動物園',
        locationName: '東京都',
        lat: 35.71,
        lng: 139.77,
        date: DateTime(2024, 6, 1),
        memo: 'テスト',
        status: FilmStatus.developed,
        photoCount: 27,
      );
      final map = original.toMap();
      final restored = FilmSession.fromMap(map);

      expect(restored.sessionId, original.sessionId);
      expect(restored.title, original.title);
      expect(restored.status, FilmStatus.developed);
      expect(restored.photoCount, 27);
    });
  });

  group('Photo', () {
    test('toMap / fromMap roundtrip', () {
      final original = Photo(
        photoId: 'photo-1',
        sessionId: 'session-1',
        imagePath: '/path/to/image.jpg',
        timestamp: DateTime(2024, 6, 1, 12, 0),
        subject: 'レッサーパンダ',
        memo: '木の上で寝ていた',
      );
      final map = original.toMap();
      final restored = Photo.fromMap(map);

      expect(restored.photoId, original.photoId);
      expect(restored.subject, original.subject);
      expect(restored.memo, original.memo);
    });
  });
}
