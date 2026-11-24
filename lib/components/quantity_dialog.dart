import 'package:flutter/material.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({super.key, required this.productName, required this.unit});
  final String productName;
  final String unit;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _controller = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final number = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (number == null || !number.isFinite || number <= 0) {
      setState(() => _error = 'Introduce una cantidad mayor que cero.');
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(number);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Consumir ${widget.productName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              labelText: 'Cantidad (${widget.unit})',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Consumir')),
      ],
    );
  }
}
