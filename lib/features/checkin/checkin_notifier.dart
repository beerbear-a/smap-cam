import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/location/location_service.dart';
import '../../core/models/zoo.dart';

class CheckInState {
  final Zoo? checkedInZoo;
  final List<Zoo> nearbyZoos;
  final bool isLoading;
  final String? error;

  const CheckInState({
    this.checkedInZoo,
    this.nearbyZoos = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isCheckedIn => checkedInZoo != null;

  CheckInState copyWith({
    Zoo? checkedInZoo,
    bool clearZoo = false,
    List<Zoo>? nearbyZoos,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      CheckInState(
        checkedInZoo: clearZoo ? null : (checkedInZoo ?? this.checkedInZoo),
        nearbyZoos: nearbyZoos ?? this.nearbyZoos,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class CheckInNotifier extends StateNotifier<CheckInState> {
  CheckInNotifier() : super(const CheckInState());

  /// GPS で近くの動物園を検索
  Future<void> detectNearbyZoos() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        // 位置情報不可 → 全動物園リスト表示
        final all = await DatabaseHelper.getAllZoos();
        state = state.copyWith(nearbyZoos: all, isLoading: false);
        return;
      }
      final nearby = await DatabaseHelper.getZoosNear(
        position.latitude,
        position.longitude,
        radiusKm: 10.0,
      );
      if (nearby.isEmpty) {
        // 近くに動物園なし → 全リスト表示
        final all = await DatabaseHelper.getAllZoos();
        state = state.copyWith(nearbyZoos: all, isLoading: false);
      } else {
        state = state.copyWith(nearbyZoos: nearby, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void checkIn(Zoo zoo) {
    state = state.copyWith(checkedInZoo: zoo, clearError: true);
  }

  void checkOut() {
    state = state.copyWith(clearZoo: true);
  }
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  return CheckInNotifier();
});
