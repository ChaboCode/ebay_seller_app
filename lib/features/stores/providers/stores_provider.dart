import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/utils/app_config.dart';
import '../models/seller_store.dart';

class StoresState {
  final List<SellerStore> stores;
  final String? selectedUsername;

  const StoresState({this.stores = const [], this.selectedUsername});

  SellerStore? get selected {
    for (final s in stores) {
      if (s.username == selectedUsername) return s;
    }
    return null;
  }
}

class StoresNotifier extends Notifier<StoresState> {
  CacheService get _cache => CacheService.instance;

  @override
  StoresState build() {
    var stores = _cache.getStores();

    // First run: seed with the seller from .env so existing installs keep
    // working exactly as before.
    if (stores.isEmpty && AppConfig.defaultSellerUsername.isNotEmpty) {
      stores = [SellerStore(username: AppConfig.defaultSellerUsername)];
      _cache.saveStores(stores);
    }

    final saved = _cache.getSelectedStore();
    final selected = stores.any((s) => s.username == saved)
        ? saved
        : (stores.isNotEmpty ? stores.first.username : null);

    return StoresState(stores: stores, selectedUsername: selected);
  }

  /// Returns an error message, or null if [username] is valid.
  /// [excluding] is the store being edited (allowed to keep its own name).
  String? validateUsername(String username, {String? excluding}) {
    final name = username.trim();
    if (name.isEmpty) return 'Username is required';
    if (RegExp(r'\s').hasMatch(name)) return 'Username cannot contain spaces';
    final lower = name.toLowerCase();
    final duplicate = state.stores.any(
      (s) =>
          s.username.toLowerCase() == lower &&
          s.username.toLowerCase() != excluding?.toLowerCase(),
    );
    if (duplicate) return 'This store is already added';
    return null;
  }

  Future<void> select(String username) async {
    if (state.selectedUsername == username) return;
    state = StoresState(stores: state.stores, selectedUsername: username);
    await _cache.setSelectedStore(username);
  }

  Future<void> add(SellerStore store) async {
    final stores = [...state.stores, store];
    state = StoresState(
      stores: stores,
      selectedUsername: state.selectedUsername ?? store.username,
    );
    await _cache.saveStores(stores);
    if (state.selectedUsername == store.username) {
      await _cache.setSelectedStore(store.username);
    }
  }

  Future<void> update(String oldUsername, SellerStore store) async {
    final stores = [
      for (final s in state.stores) s.username == oldUsername ? store : s,
    ];
    final renamed = oldUsername != store.username;
    final selected = state.selectedUsername == oldUsername
        ? store.username
        : state.selectedUsername;

    state = StoresState(stores: stores, selectedUsername: selected);
    await _cache.saveStores(stores);
    if (selected != null) await _cache.setSelectedStore(selected);
    if (renamed) await _cache.clearSeller(oldUsername);
  }

  Future<void> remove(String username) async {
    final stores = state.stores.where((s) => s.username != username).toList();
    final selected = state.selectedUsername == username
        ? (stores.isNotEmpty ? stores.first.username : null)
        : state.selectedUsername;

    state = StoresState(stores: stores, selectedUsername: selected);
    await _cache.saveStores(stores);
    if (selected != null) await _cache.setSelectedStore(selected);
    await _cache.clearSeller(username);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    // [newIndex] is already adjusted for the removed item (onReorderItem).
    final stores = [...state.stores];
    stores.insert(newIndex, stores.removeAt(oldIndex));
    state = StoresState(
      stores: stores,
      selectedUsername: state.selectedUsername,
    );
    await _cache.saveStores(stores);
  }
}

final storesProvider = NotifierProvider<StoresNotifier, StoresState>(
  StoresNotifier.new,
);
