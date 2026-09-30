import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ebay_api_client.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/models/listing.dart';
import '../../stores/providers/stores_provider.dart';

// ── API Client provider ───────────────────────────────────────────────────────

final ebayClientProvider = Provider<EbayApiClient>((ref) {
  return EbayApiClient();
});

// ── Sort provider ─────────────────────────────────────────────────────────────

class SortNotifier extends Notifier<ListingSort> {
  @override
  ListingSort build() => ListingSort.endingSoon;

  void setSort(ListingSort sort) => state = sort;
}

final sortProvider = NotifierProvider<SortNotifier, ListingSort>(
  SortNotifier.new,
);

// ── Listings state ────────────────────────────────────────────────────────────

class ListingsState {
  final List<EbayListing> listings;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastUpdated;
  final bool isOffline;

  const ListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
    this.isOffline = false,
  });

  ListingsState copyWith({
    List<EbayListing>? listings,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastUpdated,
    bool? isOffline,
    bool clearError = false,
  }) {
    return ListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ── Listings notifier ─────────────────────────────────────────────────────────

class ListingsNotifier extends Notifier<ListingsState> {
  EbayApiClient get _api => ref.read(ebayClientProvider);
  CacheService get _cache => CacheService.instance;

  /// Currently selected store. `build()` re-runs whenever it changes.
  String? sellerUsername;

  @override
  ListingsState build() {
    sellerUsername = ref.watch(
      storesProvider.select((s) => s.selectedUsername),
    );

    // No store configured: nothing to load.
    if (sellerUsername == null) return const ListingsState();

    Future.microtask(() => load(sort: ref.read(sortProvider)));

    return const ListingsState(isLoading: true);
  }

  /// Load listings: show cache immediately, then refresh if stale.
  Future<void> load({ListingSort sort = ListingSort.endingSoon}) async {
    final seller = sellerUsername;
    if (seller == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Show cached data immediately (offline-first)
    final cached = _cache.getListings(seller);
    if (cached.isNotEmpty) {
      final sorted = _sortLocally(cached, sort);
      state = state.copyWith(
        listings: sorted,
        isLoading: false,
        lastUpdated: _cache.lastFetchTime(seller),
      );
    }

    // 2. If cache is fresh, done
    if (_cache.isCacheFresh(seller) && cached.isNotEmpty) {
      return;
    }

    // 3. Fetch from API
    await _fetchFromApi(sort: sort, isRefresh: cached.isNotEmpty);
  }

  /// Force refresh from API regardless of cache freshness.
  Future<void> refresh({ListingSort sort = ListingSort.endingSoon}) async {
    if (sellerUsername == null) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    await _fetchFromApi(sort: sort, isRefresh: true);
  }

  /// Change sort order (locally instant, then refetch).
  Future<void> changeSort(ListingSort sort) async {
    if (state.listings.isNotEmpty) {
      state = state.copyWith(listings: _sortLocally(state.listings, sort));
    }
    await refresh(sort: sort);
  }

  Future<void> _fetchFromApi({
    required ListingSort sort,
    bool isRefresh = false,
  }) async {
    final seller = sellerUsername;
    if (seller == null) return;

    // The user may switch store while the request is in flight; a late
    // response must not overwrite the state of the newly selected store.
    bool isStale() => !ref.mounted || sellerUsername != seller;

    try {
      final listings = await _api.getAllSellerListings(
        sellerUsername: seller,
        sort: sort,
      );

      // eBay no ordena bien cuando mezclas subastas y "Buy It Now" en la
      // misma búsqueda, así que siempre ordenamos localmente para asegurar
      // que el filtro seleccionado se refleje en pantalla.
      final sorted = _sortLocally(listings, sort);

      // Still worth caching for the old store, unless it was deleted.
      if (ref.mounted &&
          ref.read(storesProvider).stores.any((s) => s.username == seller)) {
        await _cache.saveListings(seller, sorted);
      }
      if (isStale()) return;

      state = state.copyWith(
        listings: sorted,
        isLoading: false,
        isRefreshing: false,
        lastUpdated: DateTime.now(),
        isOffline: false,
        clearError: true,
      );
    } on EbayApiException catch (e) {
      if (isStale()) return;
      final isConnErr =
          e.message.contains('internet') || e.message.contains('timed out');

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: isConnErr ? null : e.message,
        isOffline: isConnErr,
      );
    } catch (e) {
      if (isStale()) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Unexpected error. Please try again.',
      );
    }
  }

  List<EbayListing> _sortLocally(List<EbayListing> items, ListingSort sort) {
    final copy = [...items];
    switch (sort) {
      case ListingSort.endingSoon:
        copy.sort((a, b) => a.timeRemaining.compareTo(b.timeRemaining));
      case ListingSort.endingLast:
        copy.sort((a, b) => b.timeRemaining.compareTo(a.timeRemaining));
      case ListingSort.priceAsc:
        copy.sort((a, b) => a.price.compareTo(b.price));
      case ListingSort.priceDesc:
        copy.sort((a, b) => b.price.compareTo(a.price));
    }
    return copy;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final listingsProvider = NotifierProvider<ListingsNotifier, ListingsState>(
  ListingsNotifier.new,
);

// ── Heat filter (Hot / Warm / Cold / Sleeper) ──────────────────────────────

enum HeatFilter {
  all('All'),
  hot('🔥 Hot'),
  warm('🟡 Warm'),
  cold('❄️ Cold');

  final String label;
  const HeatFilter(this.label);
}

class HeatFilterNotifier extends Notifier<HeatFilter> {
  @override
  HeatFilter build() => HeatFilter.all;

  void setFilter(HeatFilter filter) => state = filter;
}

final heatFilterProvider = NotifierProvider<HeatFilterNotifier, HeatFilter>(
  HeatFilterNotifier.new,
);
