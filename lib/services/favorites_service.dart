import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'fav_cards';
  static Future<Set<String>> getFavorites() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? []).toSet();
  }

  static Future<void> toggle(String productId) async {
    final p = await SharedPreferences.getInstance();
    final list = (p.getStringList(_key) ?? []).toSet();
    if (list.contains(productId)) list.remove(productId); else list.add(productId);
    await p.setStringList(_key, list.toList());
  }

  static Future<bool> isFav(String productId) async {
    final favs = await getFavorites();
    return favs.contains(productId);
  }
}
