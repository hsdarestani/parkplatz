import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favoritesKey = 'freiraum_favorite_parking_ids';

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController() : super(<String>{}) {
    _restore();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = preferences.getStringList(_favoritesKey)?.toSet() ?? <String>{};
  }

  bool contains(String parkingId) => state.contains(parkingId);

  Future<void> toggle(String parkingId) async {
    final next = {...state};
    if (!next.add(parkingId)) {
      next.remove(parkingId);
    }
    state = next;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_favoritesKey, next.toList()..sort());
  }

  Future<void> remove(String parkingId) async {
    if (!state.contains(parkingId)) return;
    final next = {...state}..remove(parkingId);
    state = next;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_favoritesKey, next.toList()..sort());
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesController, Set<String>>(
  (_) => FavoritesController(),
);
