import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/listing.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/odoo_purchase_status.dart';
import '../providers/odoo_purchases_provider.dart';
import 'odoo_purchase_sheet.dart';

/// Small button over a listing's image: shows the figure's state in Odoo's
/// Purchase module and opens [OdooPurchaseSheet] to add it or edit its cost.
class OdooPurchaseButton extends ConsumerWidget {
  final EbayListing listing;

  const OdooPurchaseButton({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      odooPurchasesProvider.select((s) => s.byItem[listing.legacyItemId]),
    );
    final stage = status?.stage ?? OdooStage.none;
    final color = odooStageColor(stage);

    return Tooltip(
      message: status?.description ?? 'Add to Odoo purchases',
      child: GestureDetector(
        onTap: () => OdooPurchaseSheet.show(context, listing),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(odooStageIcon(stage), size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                status?.shortLabel ?? 'Odoo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color odooStageColor(OdooStage stage) => switch (stage) {
  OdooStage.none => Colors.white,
  OdooStage.rfq => AppTheme.accentWarm,
  OdooStage.confirmed => AppTheme.accent,
  OdooStage.received || OdooStage.locked => AppTheme.success,
};

IconData odooStageIcon(OdooStage stage) => switch (stage) {
  OdooStage.none => Icons.add_shopping_cart_rounded,
  OdooStage.rfq => Icons.request_quote_outlined,
  OdooStage.confirmed => Icons.local_shipping_outlined,
  OdooStage.received => Icons.inventory_2_outlined,
  OdooStage.locked => Icons.lock_outline_rounded,
};
