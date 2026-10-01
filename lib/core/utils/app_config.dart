import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central app configuration — reads from .env file.
/// Never hardcode credentials here.
class AppConfig {
  // ── Backend ───────────────────────────────────────────────────────────────
  /// URL of our own backend (ebay_seller_backend). Override at build/run time:
  ///   flutter run --dart-define=API_URL=https://your-backend.onrender.com/
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ebay-back.kaerdos.dev/',
  );

  /// Sent as `X-Api-Key` on the backend's /odoo/* routes when the backend
  /// sets ODOO_BRIDGE_TOKEN:
  ///   flutter run --dart-define=ODOO_BRIDGE_TOKEN=...
  /// It ends up inside the build (like everything else here), so it only
  /// keeps casual callers out; it is not a real secret.
  static const String odooBridgeToken = String.fromEnvironment(
    'ODOO_BRIDGE_TOKEN',
  );

  // ── Seller to track ───────────────────────────────────────────────────────
  static String get defaultSellerUsername =>
      dotenv.env['EBAY_SELLER_USERNAME'] ?? '';

  // ── Behaviour ─────────────────────────────────────────────────────────────
  /// Items per page for Browse API (max 200)
  static const int itemsPerPage = 200;

  /// Cache TTL
  static const Duration foregroundRefreshInterval = Duration(minutes: 15);
}
