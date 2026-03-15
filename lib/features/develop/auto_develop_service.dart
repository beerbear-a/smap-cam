import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../share/contact_sheet_service.dart';

class AutoDevelopService {
  static const _pendingNotificationIdsKey =
      'pending_auto_developed_session_ids';

  static Future<List<FilmSession>> processExpiredFilms() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final pendingIds =
        prefs.getStringList(_pendingNotificationIdsKey)?.toList() ?? [];
    final sessions = await DatabaseHelper.getAllFilmSessions();

    for (final session
        in sessions.where((entry) => entry.shouldAutoDevelop(now: now))) {
      final developed = await _developSession(session);
      if (!pendingIds.contains(developed.sessionId)) {
        pendingIds.add(developed.sessionId);
      }
    }

    await prefs.setStringList(_pendingNotificationIdsKey, pendingIds);

    final pendingSessions = <FilmSession>[];
    for (final sessionId in pendingIds) {
      final session = await DatabaseHelper.getFilmSession(sessionId);
      if (session != null) {
        pendingSessions.add(session);
      }
    }
    return pendingSessions;
  }

  static Future<void> clearPendingNotifications(
      Iterable<String> sessionIds) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingIds =
        prefs.getStringList(_pendingNotificationIdsKey)?.toList() ?? [];
    pendingIds.removeWhere(sessionIds.contains);
    await prefs.setStringList(_pendingNotificationIdsKey, pendingIds);
  }

  static Future<FilmSession> _developSession(FilmSession session) async {
    final photos = await DatabaseHelper.getPhotosForSession(session.sessionId);
    var updated = session.copyWith(status: FilmStatus.developed);

    final shouldGenerateIndexSheet = session.isFilmMode &&
        photos.length >= FilmSession.maxPhotos &&
        (session.indexSheetPath?.isNotEmpty != true);

    if (shouldGenerateIndexSheet) {
      final path = await ContactSheetService.generate(
        session: updated,
        photos: photos,
        format: ContactSheetFormat.indexSheet,
        persist: true,
      );
      updated = updated.copyWith(indexSheetPath: path);
    }

    await DatabaseHelper.updateFilmSession(updated);
    return updated;
  }
}
