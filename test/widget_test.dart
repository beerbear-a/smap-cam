import 'package:flutter_test/flutter_test.dart';
import 'package:zootocam/core/models/film_session.dart';
import 'package:zootocam/core/models/photo.dart';

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
        captureMode: CaptureMode.film,
        photoCount: 27,
      );
      expect(session.isFull, true);
    });

    test('toMap / fromMap roundtrip', () {
      final lastRestoredAt = DateTime(2024, 6, 8, 9, 30);
      final developReadyAt = DateTime(2024, 6, 1, 13, 0);
      final original = FilmSession(
        sessionId: 'abc',
        title: '上野動物園',
        locationName: '東京都',
        lat: 35.71,
        lng: 139.77,
        date: DateTime(2024, 6, 1),
        theme: '春のレッサーパンダ',
        indexSheetPath: '/tmp/index.png',
        developReadyAt: developReadyAt,
        lastRestoredAt: lastRestoredAt,
        memo: 'テスト',
        status: FilmStatus.developed,
        captureMode: CaptureMode.film,
        photoCount: 27,
      );
      final map = original.toMap();
      final restored = FilmSession.fromMap(map);

      expect(restored.sessionId, original.sessionId);
      expect(restored.title, original.title);
      expect(restored.theme, original.theme);
      expect(restored.indexSheetPath, original.indexSheetPath);
      expect(restored.developReadyAt, developReadyAt);
      expect(restored.lastRestoredAt, lastRestoredAt);
      expect(restored.status, FilmStatus.developed);
      expect(restored.photoCount, 27);
    });

    test('canRestoreNow unlocks after 7 days', () {
      final lastRestoredAt = DateTime(2024, 6, 1, 12, 0);
      final session = FilmSession(
        sessionId: 'abc',
        title: '上野動物園',
        date: DateTime(2024, 6, 1),
        status: FilmStatus.shelved,
        lastRestoredAt: lastRestoredAt,
      );

      expect(
        session.canRestoreNow(now: DateTime(2024, 6, 8, 11, 59)),
        false,
      );
      expect(
        session.canRestoreNow(now: DateTime(2024, 6, 8, 12, 0)),
        true,
      );
    });

    test('shouldAutoDevelop after one year in developing state', () {
      final session = FilmSession(
        sessionId: 'film-1',
        title: '多摩動物公園',
        date: DateTime(2025, 3, 14, 9, 0),
        status: FilmStatus.developing,
        captureMode: CaptureMode.film,
        photoCount: 27,
      );

      expect(
        session.shouldAutoDevelop(now: DateTime(2026, 3, 14, 8, 59)),
        false,
      );
      expect(
        session.shouldAutoDevelop(now: DateTime(2026, 3, 14, 9, 0)),
        true,
      );
    });

    test('isDevelopReady unlocks after one hour', () {
      final session = FilmSession(
        sessionId: 'film-2',
        title: '井の頭自然文化園',
        date: DateTime(2026, 3, 14, 9, 0),
        status: FilmStatus.developing,
        developReadyAt: DateTime.now().add(const Duration(minutes: 59)),
      );
      final readySession = session.copyWith(
        developReadyAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(session.isDevelopReady, false);
      expect(readySession.isDevelopReady, true);
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
