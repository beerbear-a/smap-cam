import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';

class MapNotifier extends StateNotifier<AsyncValue<List<FilmSession>>> {
  MapNotifier() : super(const AsyncValue.loading());

  Future<void> loadSessions() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await DatabaseHelper.getAllFilmSessions();
      // 地図には現像済みセッションのみ表示 (位置情報あり)
      final mapped = sessions
          .where((s) => s.isDeveloped && s.lat != null && s.lng != null)
          .toList();
      state = AsyncValue.data(mapped);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final mapProvider =
    StateNotifierProvider<MapNotifier, AsyncValue<List<FilmSession>>>((ref) {
  return MapNotifier();
});
