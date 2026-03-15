import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final proAccessProvider = StateNotifierProvider<ProAccessNotifier, bool>((ref) {
  return ProAccessNotifier();
});

class ProAccessNotifier extends StateNotifier<bool> {
  ProAccessNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('pro_access_enabled') ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pro_access_enabled', value);
  }
}
