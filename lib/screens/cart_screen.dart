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
  String? _loadError;
  final Set<int> _busyProducts = {};
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await _db.getCartItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo cargar el carrito: $e';
      });
    }
  }

  Future<void> _change(Map<String, dynamic> item, double delta) async {
    final id = (item['product_id'] as num).toInt();
    if (_busyProducts.contains(id) || _clearing) return;
    setState(() => _busyProducts.add(id));
    try {
      final current = (item['quantity'] as num).toDouble();
      await _db.updateCartQuantity(id, current + delta);
      await _reload();
    } catch (e) {
      _message('No se pudo actualizar la lista: $e');
    } finally {
      if (mounted) setState(() => _busyProducts.remove(id));
    }
  }

  Future<void> _remove(int id) async {
    if (_busyProducts.contains(id) || _clearing) return;
    setState(() => _busyProducts.add(id));
    try {
      await _db.updateCartQuantity(id, 0);
      await _reload();
    } catch (e) {
      _message('No se pudo quitar el producto: $e');
    } finally {
      if (mounted) setState(() => _busyProducts.remove(id));
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clear() async {
    if (_clearing || _busyProducts.isNotEmpty) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Vaciar lista de compra'),
              content:
                  const Text('Se eliminarán todos los artículos del carrito.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Vaciar')),
              ],
            ));
    if (!mounted || yes != true) return;
    setState(() => _clearing = true);
    try {
      await _db.clearCart();
      await _reload();
    } catch (e) {
      _message('No se pudo vaciar el carrito: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Lista de compra'),
                actions: [
                  if (_items.isNotEmpty)
                    IconButton(
                        tooltip: 'Vaciar lista',
                        onPressed: _clearing ? null : _clear,
                        icon: const Icon(Icons.delete_sweep_outlined))
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      Icon(Icons.shopping_cart_checkout_outlined,
                          color: Colors.green.shade800, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${_items.length} productos diferentes',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const Text(
                                'Las cantidades se muestran según la unidad de cada producto.'),
                          ])),
                    ]),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()))
              else if (_loadError != null)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _reload,
                            child: const Text('Reintentar')),
                      ]),
                    )))
              else if (_items.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.remove_shopping_cart_outlined,
                            size: 64, color: Colors.grey.shade500),
                        const SizedBox(height: 12),
                        Text('Tu lista está vacía',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Desde el inventario, toca el carrito de un artículo para agregarlo.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Volver al inventario')),
                      ]),
                    )))
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 32),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _items[index];
                    final id = (item['product_id'] as num).toInt();
                    final quantity = (item['quantity'] as num).toDouble();
                    final stock = (item['stock_total'] as num).toDouble();
                    final available =
                        (item['stock_available'] as num?)?.toDouble() ?? stock;
                    final unit = item['unit']?.toString() ?? 'pieza';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          imagenProducto(item['image_path']?.toString(),
                              size: 64),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(item['name'].toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                Text(
                                    'En alacena: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit'),
                                if (available < stock)
                                  Text(
                                      'Vigente: ${available.toStringAsFixed(available % 1 == 0 ? 0 : 2)} $unit'),
                                const SizedBox(height: 6),
                                Row(children: [
                                  IconButton.filledTonal(
                                      onPressed: _busyProducts.contains(id) ||
                                              _clearing
                                          ? null
                                          : () => _change(item, -1),
                                      icon: const Icon(Icons.remove),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Restar una unidad'),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(
                                          '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} $unit',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  IconButton.filledTonal(
                                      onPressed: _busyProducts.contains(id) ||
                                              _clearing
                                          ? null
                                          : () => _change(item, 1),
                                      icon: const Icon(Icons.add),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Sumar una unidad'),
                                ]),
                              ])),
                          IconButton(
                              tooltip: 'Eliminar de la lista',
                              onPressed: _busyProducts.contains(id) || _clearing
                                  ? null
                                  : () => _remove(id),
                              icon: const Icon(Icons.close)),
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
