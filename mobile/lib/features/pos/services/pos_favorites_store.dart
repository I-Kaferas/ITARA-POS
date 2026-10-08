import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local favorites + quick-product pins for the POS terminal.
class PosFavoritesStore extends ChangeNotifier {
  PosFavoritesStore._();

  static final PosFavoritesStore instance = PosFavoritesStore._();

  static const _favoritesKey = 'pos_favorite_product_ids';
  static const _quickKey = 'pos_quick_product_ids';
  static const favoritesCategoryId = '__favorites__';
  static const quickCategoryId = '__quick__';

  final Set<String> _favorites = {};
  final List<String> _quick = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Set<String> get favorites => Set.unmodifiable(_favorites);

  List<String> get quickProductIds => List.unmodifiable(_quick);

  bool isFavorite(String productId) => _favorites.contains(productId);

  bool isQuick(String productId) => _quick.contains(productId);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _favorites
      ..clear()
      ..addAll(prefs.getStringList(_favoritesKey) ?? const []);
    _quick
      ..clear()
      ..addAll(prefs.getStringList(_quickKey) ?? const []);
    // Seed quick from favorites if empty.
    if (_quick.isEmpty && _favorites.isNotEmpty) {
      _quick.addAll(_favorites.take(12));
      await prefs.setStringList(_quickKey, _quick);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(String productId) async {
    await ensureLoaded();
    if (_favorites.contains(productId)) {
      _favorites.remove(productId);
      _quick.remove(productId);
    } else {
      _favorites.add(productId);
      if (!_quick.contains(productId) && _quick.length < 12) {
        _quick.add(productId);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleQuick(String productId) async {
    await ensureLoaded();
    if (_quick.contains(productId)) {
      _quick.remove(productId);
    } else {
      if (_quick.length >= 12) {
        _quick.removeAt(0);
      }
      _quick.add(productId);
      _favorites.add(productId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList());
    await prefs.setStringList(_quickKey, _quick);
  }
}
