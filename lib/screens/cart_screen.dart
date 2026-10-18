import 'package:flutter/material.dart';

import '../components/app_utils.dart';
import '../database/inventory_db.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final InventoryDB _db = InventoryDB.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await _db.getCartItems();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _change(Map<String, dynamic> item, double delta) async {
    final id = (item['product_id'] as num).toInt();
    final current = (item['quantity'] as num).toDouble();
    await _db.updateCartQuantity(id, current + delta);
    _reload();
  }

  Future<void> _remove(int id) async {
    await _db.updateCartQuantity(id, 0);
    _reload();
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Vaciar lista de compra'),
      content: const Text('Se eliminarán todos los artículos del carrito.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vaciar')),
      ],
    ));
    if (yes == true) {
      await _db.clearCart();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = _items.fold<double>(0, (sum, item) => sum + (item['quantity'] as num).toDouble());
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Lista de compra'),
            actions: [if (_items.isNotEmpty) IconButton(tooltip: 'Vaciar lista', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Icon(Icons.shopping_cart_checkout_outlined, color: Colors.green.shade800, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_items.length} productos diferentes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Cantidad total: ${totalUnits.toStringAsFixed(totalUnits % 1 == 0 ? 0 : 2)} unidades'),
                  ])),
                ]),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey.shade500),
                const SizedBox(height: 12),
                Text('Tu lista está vacía', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Desde el inventario, toca el carrito de un artículo para agregarlo.'),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Volver al inventario')),
              ]),
            )))
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final item = _items[index];
                final id = (item['product_id'] as num).toInt();
                final quantity = (item['quantity'] as num).toDouble();
                final stock = (item['stock_total'] as num).toDouble();
                final unit = item['unit']?.toString() ?? 'pieza';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      imagenProducto(item['image_path']?.toString(), size: 64),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['name'].toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('En alacena: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit'),
                        const SizedBox(height: 6),
                        Row(children: [
                          IconButton.filledTonal(onPressed: () => _change(item, -1), icon: const Icon(Icons.remove), visualDensity: VisualDensity.compact, tooltip: 'Restar una unidad'),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} $unit', style: const TextStyle(fontWeight: FontWeight.bold))),
                          IconButton.filledTonal(onPressed: () => _change(item, 1), icon: const Icon(Icons.add), visualDensity: VisualDensity.compact, tooltip: 'Sumar una unidad'),
                        ]),
                      ])),
                      IconButton(tooltip: 'Eliminar de la lista', onPressed: () => _remove(id), icon: const Icon(Icons.close)),
                    ]),
                  ),
                );
              }, childCount: _items.length)),
            ),
        ]),
      ),
    );
  }
}
