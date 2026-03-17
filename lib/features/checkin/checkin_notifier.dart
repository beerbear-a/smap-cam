import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/animal_repository.dart';
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
  CheckInNotifier(this._animalRepository) : super(const CheckInState());

  final AnimalRepository _animalRepository;

  /// GPS で近くの場所を検索
  Future<void> detectNearbyZoos() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final nearby = await _animalRepository.getNearbyZoos(radiusKm: 10.0);
      state = state.copyWith(nearbyZoos: nearby, isLoading: false);
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
  return CheckInNotifier(ref.read(animalRepositoryProvider));
});
