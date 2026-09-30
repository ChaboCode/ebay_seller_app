import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/selectable_pill.dart';
import '../../stores/providers/stores_provider.dart';
import '../../stores/widgets/store_form_dialog.dart';

/// Horizontally scrollable row of pills, one per configured store.
class StorePills extends ConsumerStatefulWidget {
  const StorePills({super.key});

  @override
  ConsumerState<StorePills> createState() => _StorePillsState();
}

class _StorePillsState extends ConsumerState<StorePills> {
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
  }

  void _centerSelected() {
    if (!mounted) return;
    final selected = ref.read(storesProvider).selectedUsername;
    final ctx = _keys[selected]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      storesProvider.select((s) => s.selectedUsername),
      (_, _) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerSelected(),
      ),
    );

    final state = ref.watch(storesProvider);
    if (state.stores.isEmpty) return const SizedBox.shrink();

    _keys.removeWhere((k, _) => !state.stores.any((s) => s.username == k));

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            for (final store in state.stores)
              Padding(
                key: _keys.putIfAbsent(store.username, GlobalKey.new),
                padding: const EdgeInsets.only(right: 8),
                child: SelectablePill(
                  label: store.displayName,
                  isSelected: store.username == state.selectedUsername,
                  onTap: () =>
                      ref.read(storesProvider.notifier).select(store.username),
                ),
              ),
            SelectablePill(
              label: 'Add',
              icon: Icons.add_rounded,
              isSelected: false,
              onTap: () => StoreFormDialog.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
