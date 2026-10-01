import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/models/listing.dart';
import '../../listings/providers/listings_provider.dart';
import '../models/odoo_purchase_status.dart';

final odooClientProvider = Provider<OdooApiClient>((ref) => OdooApiClient());

class OdooPurchasesState {
  /// Odoo state per legacy item id.
  final Map<String, OdooPurchaseStatus> byItem;
  final bool isLoading;
  final String? error;

  /// The backend has no Odoo configured (it answered 503).
  final bool notConfigured;

  const OdooPurchasesState({
    this.byItem = const {},
    this.isLoading = false,
    this.error,
    this.notConfigured = false,
  });
}

/// Odoo purchase state of the listings on screen. Re-fetched in one batch
/// whenever the set of listings changes (new store, new items).
class OdooPurchasesNotifier extends Notifier<OdooPurchasesState> {
  OdooApiClient get _api => ref.read(odooClientProvider);

  @override
  OdooPurchasesState build() {
    // A joined string, so a refresh with the same items doesn't rebuild.
    final key = ref.watch(
      listingsProvider.select(
        (s) => s.listings.map((l) => l.legacyItemId).join(','),
      ),
    );
    final previous = stateOrNull?.byItem ?? const {};
    if (key.isEmpty) return OdooPurchasesState(byItem: previous);

    Future.microtask(() => _lookup(key.split(',')));
    return OdooPurchasesState(byItem: previous, isLoading: true);
  }

  Future<void> _lookup(List<String> ids) async {
    try {
      final found = await _api.lookup(ids);
      if (!ref.mounted) return;
      state = OdooPurchasesState(byItem: {...state.byItem, ...found});
    } on OdooApiException catch (e) {
      if (!ref.mounted) return;
      state = OdooPurchasesState(
        byItem: state.byItem,
        error: e.message,
        notConfigured: e.notConfigured,
      );
    }
  }

  void _put(OdooPurchaseStatus status) {
    state = OdooPurchasesState(
      byItem: {...state.byItem, status.itemId: status},
      isLoading: state.isLoading,
      notConfigured: false,
    );
  }

  /// Re-reads one figure (it may have been confirmed or received in Odoo
  /// since the last lookup).
  Future<OdooPurchaseStatus> refreshItem(String itemId) async {
    final status = await _api.get(itemId);
    if (ref.mounted) _put(status);
    return status;
  }

  /// Adds [listing] to Odoo's purchases at [cost], or updates the cost of
  /// its existing purchase order. Throws [OdooApiException].
  Future<OdooPurchaseStatus> save(
    EbayListing listing, {
    required String seller,
    required double cost,
  }) async {
    final status = await _api.save(
      itemId: listing.legacyItemId,
      title: listing.title,
      seller: seller,
      cost: cost,
      currency: listing.currency,
      imageUrl: listing.imageUrls.isEmpty ? null : listing.imageUrls.first,
      auctionPrice: listing.price,
      listingUrl: listing.listingUrl,
    );
    if (ref.mounted) _put(status);
    return status;
  }
}

final odooPurchasesProvider =
    NotifierProvider<OdooPurchasesNotifier, OdooPurchasesState>(
      OdooPurchasesNotifier.new,
    );
