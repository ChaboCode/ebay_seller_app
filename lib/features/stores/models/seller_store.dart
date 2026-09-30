/// A configured eBay seller store the user can switch between.
///
/// Persisted in Hive as a plain `Map` (no TypeAdapter), so it doesn't touch
/// the `EbayListing` adapter's typeId / field indices.
class SellerStore {
  /// eBay seller username. Unique identity (case-insensitive).
  final String username;

  /// Optional alias shown instead of the username.
  final String? label;

  const SellerStore({required this.username, this.label});

  String get displayName =>
      (label != null && label!.isNotEmpty) ? label! : username;

  Map<String, dynamic> toMap() => {'username': username, 'label': label};

  factory SellerStore.fromMap(Map<dynamic, dynamic> map) => SellerStore(
    username: map['username'] as String,
    label: map['label'] as String?,
  );
}
