import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';

class FilmSessionState {
  final List<FilmSession> sessions;
  final bool isLoading;

  const FilmSessionState({
    this.sessions = const [],
    this.isLoading = false,
  });

  FilmSessionState copyWith({
    List<FilmSession>? sessions,
    bool? isLoading,
  }) {
    return FilmSessionState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FilmSessionNotifier extends StateNotifier<FilmSessionState> {
  FilmSessionNotifier() : super(const FilmSessionState());

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true);
    final sessions = await DatabaseHelper.getAllFilmSessions();
    state = FilmSessionState(sessions: sessions, isLoading: false);
  }

  Future<FilmSession> createSession({
    required String title,
    String? locationName,
    double? lat,
    double? lng,
    String? zooId,
  }) async {
    final session = FilmSession(
      sessionId: const Uuid().v4(),
      title: title,
      locationName: locationName,
      lat: lat,
      lng: lng,
      zooId: zooId,
      date: DateTime.now(),
    );
    await DatabaseHelper.insertFilmSession(session);
    await loadSessions();
    return session;
  }

  Future<void> updateMemo(String sessionId, String memo) async {
    final session = await DatabaseHelper.getFilmSession(sessionId);
    if (session == null) return;
    final updated = session.copyWith(memo: memo);
    await DatabaseHelper.updateFilmSession(updated);
    await loadSessions();
  }

  Future<void> markDeveloped(String sessionId) async {
    final session = await DatabaseHelper.getFilmSession(sessionId);
    if (session == null) return;
    final updated = session.copyWith(status: FilmStatus.developed);
    await DatabaseHelper.updateFilmSession(updated);
    await loadSessions();
  }
}

final filmSessionProvider =
    StateNotifierProvider<FilmSessionNotifier, FilmSessionState>((ref) {
  return FilmSessionNotifier();
});
