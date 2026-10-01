import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/models/listing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/theme/app_theme.dart';
import '../../listings/widgets/image_carousel.dart';
import '../../stores/providers/stores_provider.dart';
import '../models/odoo_purchase_status.dart';
import '../providers/odoo_purchases_provider.dart';
import 'odoo_purchase_button.dart';

/// Bottom sheet to manage a figure in Odoo's Purchase module: shows the
/// current eBay value and the Odoo state, and saves the cost (creating the
/// vendor, product and RFQ the first time).
class OdooPurchaseSheet extends ConsumerStatefulWidget {
  final EbayListing listing;

  const OdooPurchaseSheet({super.key, required this.listing});

  static Future<void> show(BuildContext context, EbayListing listing) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OdooPurchaseSheet(listing: listing),
    );
  }

  @override
  ConsumerState<OdooPurchaseSheet> createState() => _OdooPurchaseSheetState();
}

class _OdooPurchaseSheetState extends ConsumerState<OdooPurchaseSheet> {
  late final TextEditingController _cost;
  bool _loading = true;
  bool _saving = false;
  bool _costEdited = false;
  String? _error;

  EbayListing get _listing => widget.listing;
  String get _itemId => _listing.legacyItemId;

  @override
  void initState() {
    super.initState();
    final known = ref.read(odooPurchasesProvider).byItem[_itemId];
    _cost = TextEditingController(
      text: (known?.cost ?? _listing.price).toStringAsFixed(2),
    );
    _refresh();
  }

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  /// Fresh state from Odoo: the RFQ may have been confirmed or received
  /// since the batch lookup.
  Future<void> _refresh() async {
    try {
      final status = await ref
          .read(odooPurchasesProvider.notifier)
          .refreshItem(_itemId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (status.cost != null && !_costEdited) {
          _cost.text = status.cost!.toStringAsFixed(2);
        }
      });
    } on OdooApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  double? _parseCost() {
    final value = double.tryParse(_cost.text.trim().replaceAll(',', '.'));
    return (value == null || value < 0 || value.isNaN || value.isInfinite)
        ? null
        : value;
  }

  Future<void> _save(String? seller) async {
    final cost = _parseCost();
    if (cost == null) {
      setState(() => _error = 'Enter a valid cost');
      return;
    }
    if (seller == null) {
      setState(() => _error = 'No store selected');
      return;
    }

    final wasInOdoo =
        ref.read(odooPurchasesProvider).byItem[_itemId]?.inOdoo ?? false;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final status = await ref
          .read(odooPurchasesProvider.notifier)
          .save(_listing, seller: seller, cost: cost);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      final what = wasInOdoo
          ? 'Cost updated in ${status.orderName ?? 'Odoo'}'
          : 'Added to Odoo as ${status.orderName ?? 'an RFQ'}';
      messenger.showSnackBar(
        SnackBar(content: Text([what, ...status.warnings].join('\n'))),
      );
    } on OdooApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      odooPurchasesProvider.select((s) => s.byItem[_itemId]),
    );
    final seller = ref.watch(storesProvider.select((s) => s.selectedUsername));
    final inOdoo = status?.inOdoo ?? false;
    final editable = status?.editable ?? true;
    final canSave = !_loading && !_saving && editable;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Odoo · Purchases',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),

            // ── Figure ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ListingImageThumb(imageUrls: _listing.imageUrls),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (seller != null) '@$seller',
                          'eBay #$_itemId',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── eBay value ──────────────────────────────────────────────
            _InfoRow(
              label: _listing.isAuction ? 'Current bid' : 'eBay price',
              value: formatMoney(_listing.price, _listing.currency),
              valueColor: AppTheme.accentWarm,
              detail: [
                if (_listing.isAuction)
                  '${_listing.bidCount ?? 0} bid${_listing.bidCount == 1 ? '' : 's'}',
                'as of ${DateFormat.Hm().format(_listing.fetchedAt)}',
              ].join(' · '),
            ),
            const SizedBox(height: 10),

            // ── Odoo state ──────────────────────────────────────────────
            _InfoRow(
              label: 'In Odoo',
              value: _loading && status == null
                  ? 'Checking…'
                  : (status?.description ?? 'Not in Odoo'),
              valueColor: odooStageColor(status?.stage ?? OdooStage.none),
              detail: inOdoo
                  ? [?status!.orderName, ?status.vendor].join(' · ')
                  : null,
              trailing: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 18),

            // ── Cost ────────────────────────────────────────────────────
            TextField(
              controller: _cost,
              enabled: editable && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) {
                _costEdited = true;
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) {
                if (canSave) _save(seller);
              },
              decoration: InputDecoration(
                labelText: 'Cost (${_listing.currency})',
                prefixText: currencySymbol(_listing.currency),
                helperText: editable
                    ? 'Saved as the purchase price in Odoo'
                    : 'The purchase order is locked in Odoo',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppTheme.danger),
              ),
            ],
            const SizedBox(height: 18),

            // ── Actions ─────────────────────────────────────────────────
            Row(
              children: [
                if (status?.odooUrl != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(status!.odooUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open in Odoo'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canSave ? () => _save(seller) : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          inOdoo
                              ? Icons.save_outlined
                              : Icons.add_shopping_cart_rounded,
                          size: 18,
                        ),
                  label: Text(inOdoo ? 'Save cost' : 'Add to purchases'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String? detail;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.detail,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (detail != null && detail!.isNotEmpty)
                Text(
                  detail!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
