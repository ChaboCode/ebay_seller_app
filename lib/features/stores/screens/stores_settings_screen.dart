import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/seller_store.dart';
import '../providers/stores_provider.dart';
import '../widgets/store_form_dialog.dart';

class StoresSettingsScreen extends ConsumerWidget {
  const StoresSettingsScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SellerStore store,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: const Text('Delete store?'),
        content: Text(
          '@${store.username} and its cached listings will be removed from '
          'this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(storesProvider.notifier).remove(store.username);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Settings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => StoreFormDialog.show(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
        label: const Text('Add store'),
      ),
      body: state.stores.isEmpty
          ? const Center(
              child: Text(
                'No stores yet.\nTap “Add store” to add your first one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'STORES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    // Leave room for the FAB.
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: state.stores.length,
                    onReorderItem: (o, n) =>
                        ref.read(storesProvider.notifier).reorder(o, n),
                    itemBuilder: (context, i) {
                      final store = state.stores[i];
                      return _StoreTile(
                        key: ValueKey(store.username),
                        store: store,
                        index: i,
                        isSelected: store.username == state.selectedUsername,
                        onEdit: () =>
                            StoreFormDialog.show(context, editing: store),
                        onDelete: () => _confirmDelete(context, ref, store),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final SellerStore store;
  final int index;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StoreTile({
    super.key,
    required this.store,
    required this.index,
    required this.isSelected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlias = store.displayName != store.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 14, right: 4),
        title: Text(
          store.displayName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: hasAlias
            ? Text(
                '@${store.username}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppTheme.danger,
              ),
              tooltip: 'Delete',
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
