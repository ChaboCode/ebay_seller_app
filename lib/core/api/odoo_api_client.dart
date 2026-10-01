import 'package:dio/dio.dart';
import '../../features/odoo/models/odoo_purchase_status.dart';
import '../utils/app_config.dart';

/// Client for the backend's /odoo/* routes, which register eBay figures in
/// Odoo's Purchase module. The app never talks to Odoo directly: the backend
/// holds the Odoo credentials.
class OdooApiClient {
  /// The backend accepts at most 1000 ids per lookup.
  static const _lookupChunk = 500;

  late final Dio _dio;

  OdooApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 10),
        // Creating a purchase also uploads the image to Odoo.
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          if (AppConfig.odooBridgeToken.isNotEmpty)
            'X-Api-Key': AppConfig.odooBridgeToken,
        },
      ),
    );
  }

  /// Odoo state of many figures, keyed by legacy item id. Figures not in
  /// Odoo come back with `inOdoo == false`.
  Future<Map<String, OdooPurchaseStatus>> lookup(List<String> itemIds) async {
    final result = <String, OdooPurchaseStatus>{};
    for (var i = 0; i < itemIds.length; i += _lookupChunk) {
      final chunk = itemIds.sublist(
        i,
        i + _lookupChunk > itemIds.length ? itemIds.length : i + _lookupChunk,
      );
      final data = await _request(
        () => _dio.post('/odoo/purchases/lookup', data: {'itemIds': chunk}),
      );
      final items = (data['items'] as Map?) ?? const {};
      items.forEach((id, json) {
        result[id.toString()] = OdooPurchaseStatus.fromJson(
          Map<String, dynamic>.from(json as Map),
        );
      });
    }
    return result;
  }

  Future<OdooPurchaseStatus> get(String itemId) async {
    final data = await _request(() => _dio.get('/odoo/purchases/$itemId'));
    return OdooPurchaseStatus.fromJson(data);
  }

  /// Registers the figure in Odoo (vendor + product + RFQ), or updates its
  /// cost if it already has a purchase order.
  Future<OdooPurchaseStatus> save({
    required String itemId,
    required String title,
    required String seller,
    required double cost,
    required String currency,
    String? imageUrl,
    double? auctionPrice,
    String? listingUrl,
  }) async {
    final data = await _request(
      () => _dio.put(
        '/odoo/purchases/$itemId',
        data: {
          'title': title,
          'seller': seller,
          'cost': cost,
          'currency': currency,
          'imageUrl': ?imageUrl,
          'auctionPrice': ?auctionPrice,
          'listingUrl': ?listingUrl,
        },
      ),
    );
    return OdooPurchaseStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const OdooApiException('Could not reach the server.');
      }
      final body = e.response?.data;
      final message = body is Map ? body['error']?.toString() : null;
      throw OdooApiException(
        message ?? 'Server error (${e.response?.statusCode ?? '?'})',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

class OdooApiException implements Exception {
  final String message;
  final int? statusCode;

  const OdooApiException(this.message, {this.statusCode});

  /// The backend has no Odoo credentials configured.
  bool get notConfigured => statusCode == 503;

  @override
  String toString() => 'OdooApiException: $message';
}
