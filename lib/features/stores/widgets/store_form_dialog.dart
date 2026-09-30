import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/seller_store.dart';
import '../providers/stores_provider.dart';

/// Add / edit a store. Pass [editing] to edit an existing one.
class StoreFormDialog extends ConsumerStatefulWidget {
  final SellerStore? editing;

  const StoreFormDialog({super.key, this.editing});

  static Future<void> show(BuildContext context, {SellerStore? editing}) {
    return showDialog(
      context: context,
      builder: (_) => StoreFormDialog(editing: editing),
    );
  }

  @override
  ConsumerState<StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends ConsumerState<StoreFormDialog> {
  late final TextEditingController _username;
  late final TextEditingController _label;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.editing?.username ?? '');
    _label = TextEditingController(text: widget.editing?.label ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(storesProvider.notifier);
    final username = _username.text.trim();
    final error = notifier.validateUsername(
      username,
      excluding: widget.editing?.username,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final label = _label.text.trim();
    final store = SellerStore(
      username: username,
      label: label.isEmpty ? null : label,
    );

    if (_isEditing) {
      await notifier.update(widget.editing!.username, store);
    } else {
      await notifier.add(store);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceAlt,
      title: Text(
        _isEditing ? 'Edit store' : 'Add store',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _username,
            autofocus: !_isEditing,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'eBay username',
              prefixText: '@',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Name (optional)'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
