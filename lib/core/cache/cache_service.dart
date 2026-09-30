import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../features/stores/models/seller_store.dart';
import '../models/listing.dart';

/// Manages local persistence of listings with TTL-based invalidation.
class CacheService {
  static const _listingsBoxName = 'listings_cache';
  static const _metaBoxName = 'cache_meta';
  static const _storesBoxName = 'stores';
  static const _storesListKey = 'list';
  static const _selectedStoreKey = 'selected';

  // Cache is considered fresh for 30 minutes
  static const cacheTTL = Duration(minutes: 30);

  static CacheService? _instance;
  static CacheService get instance {
    assert(
      _instance != null,
      'CacheService.init() must be called before using instance',
    );
    return _instance!;
  }

  late final Box<EbayListing> _listingsBox;
  late final Box<dynamic> _metaBox;
  late final Box<dynamic> _storesBox;

  CacheService._();

  static Future<CacheService> init() async {
    if (_instance != null) return _instance!;

    await Hive.initFlutter();
    Hive.registerAdapter(EbayListingAdapter());

    final service = CacheService._();
    service._listingsBox = await Hive.openBox<EbayListing>(_listingsBoxName);
    service._metaBox = await Hive.openBox<dynamic>(_metaBoxName);
    service._storesBox = await Hive.openBox<dynamic>(_storesBoxName);

    _instance = service;
    return service;
  }

  // ── Stores (configured sellers) ───────────────────────────────────────────

  List<SellerStore> getStores() {
    final raw = _storesBox.get(_storesListKey);
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) SellerStore.fromMap(e),
    ];
  }

  Future<void> saveStores(List<SellerStore> stores) =>
      _storesBox.put(_storesListKey, [for (final s in stores) s.toMap()]);

  String? getSelectedStore() => _storesBox.get(_selectedStoreKey) as String?;

  Future<void> setSelectedStore(String username) =>
      _storesBox.put(_selectedStoreKey, username);

  // ── Read ──────────────────────────────────────────────────────────────────

  List<EbayListing> getListings(String sellerUsername) {
    final key = _listingsKey(sellerUsername);
    return _listingsBox.values
        .where((l) => l.key.toString().startsWith(key))
        .toList();
  }

  bool isCacheFresh(String sellerUsername) {
    final lastFetch = _metaBox.get(_timestampKey(sellerUsername));
    if (lastFetch == null) return false;
    final fetchedAt = DateTime.tryParse(lastFetch.toString());
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < cacheTTL;
  }

  DateTime? lastFetchTime(String sellerUsername) {
    final lastFetch = _metaBox.get(_timestampKey(sellerUsername));
    if (lastFetch == null) return null;
    return DateTime.tryParse(lastFetch.toString());
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> saveListings(
    String sellerUsername,
    List<EbayListing> listings,
  ) async {
    final prefix = _listingsKey(sellerUsername);

    // Delete old entries for this seller
    final keysToDelete = _listingsBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    await _listingsBox.deleteAll(keysToDelete);

    // Write new entries
    final entries = {for (final l in listings) '$prefix${l.itemId}': l};
    await _listingsBox.putAll(entries);

    // Update timestamp
    await _metaBox.put(
      _timestampKey(sellerUsername),
      DateTime.now().toIso8601String(),
    );
  }

  // ── Invalidate ────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _listingsBox.clear();
    await _metaBox.clear();
  }

  Future<void> clearSeller(String sellerUsername) async {
    final prefix = _listingsKey(sellerUsername);
    final keysToDelete = _listingsBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    await _listingsBox.deleteAll(keysToDelete);
    await _metaBox.delete(_timestampKey(sellerUsername));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _listingsKey(String seller) => 'seller_${seller}_item_';
  String _timestampKey(String seller) => 'ts_$seller';
}
