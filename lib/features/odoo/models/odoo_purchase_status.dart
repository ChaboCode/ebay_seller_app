/// Where a figure is in Odoo's purchase flow.
enum OdooStage {
  /// Not in Odoo yet (or its purchase order was cancelled).
  none,

  /// Request for quotation, waiting to be confirmed in Odoo.
  rfq,

  /// Purchase order confirmed, not received yet.
  confirmed,

  /// Received: the figure is in stock.
  received,

  /// Purchase order locked in Odoo; its cost can no longer change.
  locked,
}

/// State of a figure in Odoo's Purchase module, as returned by the
/// backend's /odoo/purchases endpoints.
class OdooPurchaseStatus {
  /// eBay legacy item id (the numeric one).
  final String itemId;
  final bool inOdoo;
  final int? orderId;
  final String? orderName;

  /// Odoo purchase.order state: draft, sent, to approve, purchase, done.
  final String? state;

  /// Unit price of the purchase line.
  final double? cost;
  final String? currency;
  final double qtyReceived;
  final String? vendor;
  final bool editable;
  final String? odooUrl;
  final List<String> warnings;

  const OdooPurchaseStatus({
    required this.itemId,
    this.inOdoo = false,
    this.orderId,
    this.orderName,
    this.state,
    this.cost,
    this.currency,
    this.qtyReceived = 0,
    this.vendor,
    this.editable = true,
    this.odooUrl,
    this.warnings = const [],
  });

  factory OdooPurchaseStatus.fromJson(Map<String, dynamic> json) {
    return OdooPurchaseStatus(
      itemId: json['itemId']?.toString() ?? '',
      inOdoo: json['inOdoo'] == true,
      orderId: (json['orderId'] as num?)?.toInt(),
      orderName: json['orderName'] as String?,
      state: json['state'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      qtyReceived: (json['qtyReceived'] as num?)?.toDouble() ?? 0,
      vendor: json['vendor'] as String?,
      editable: json['inOdoo'] != true || json['editable'] == true,
      odooUrl: json['odooUrl'] as String?,
      warnings: [
        for (final w in (json['warnings'] as List?) ?? const []) w.toString(),
      ],
    );
  }

  OdooStage get stage {
    if (!inOdoo) return OdooStage.none;
    if (qtyReceived > 0) return OdooStage.received;
    return switch (state) {
      'purchase' => OdooStage.confirmed,
      'done' => OdooStage.locked,
      _ => OdooStage.rfq,
    };
  }

  /// Short label for the card button.
  String get shortLabel => switch (stage) {
    OdooStage.none => 'Odoo',
    OdooStage.rfq => 'RFQ',
    OdooStage.confirmed => 'PO',
    OdooStage.received => 'Stock',
    OdooStage.locked => 'Locked',
  };

  /// Longer description for the purchase sheet.
  String get description => switch (stage) {
    OdooStage.none => 'Not in Odoo',
    OdooStage.rfq => 'Request for quotation — confirm it in Odoo',
    OdooStage.confirmed => 'Purchase order confirmed — awaiting receipt',
    OdooStage.received => 'Received — in stock',
    OdooStage.locked => 'Purchase order locked',
  };
}
