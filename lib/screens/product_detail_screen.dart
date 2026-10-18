import 'package:flutter/material.dart';

import '../components/app_utils.dart';
import '../database/inventory_db.dart';
import '../services/notification_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final InventoryDB _db = InventoryDB.instance;
  int? _productId;
  bool _argsLoaded = false;
  bool _loading = true;
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _purchaseHistory = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) _productId = args;
    if (args is num) _productId = args.toInt();
    _reload();
  }

  Future<void> _reload() async {
    final id = _productId;
    if (id == null) return;
    setState(() => _loading = true);
    final inventory = await _db.getInventory(activeOnly: false);
    Map<String, dynamic>? product;
    for (final row in inventory) {
      if ((row['id'] as num).toInt() == id) { product = row; break; }
    }
    final lots = await _db.getLots(id);
    final stores = await _db.getStoresForProduct(id);
    final history = await _db.getPurchaseHistory(productId: id);
    if (!mounted) return;
    setState(() {
      _product = product;
      _lots = lots;
      _stores = stores;
      _purchaseHistory = history;
      _loading = false;
    });
  }

  Future<void> _addLot({Map<String, dynamic>? lot}) async {
    final product = _product;
    if (product == null) return;
    await Navigator.pushNamed(context, '/lot-form', arguments: {
      'productId': _productId,
      'productName': product['name'],
      if (lot != null) 'lot': lot,
    });
    _reload();
  }

  Future<void> _consume() async {
    if (_product == null) return;
    final controller = TextEditingController(text: '1');
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar consumo FEFO'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Cantidad (${_product!['unit']})')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final q = double.tryParse(controller.text.replaceAll(',', '.'));
            if (q != null && q > 0) Navigator.pop(dialogContext, q);
          }, child: const Text('Registrar')),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null) return;
    try {
      await _db.consumeFefo(_productId!, quantity);
      await _reload();
      _message('Consumo registrado. Se descontó primero el lote con caducidad más próxima.');
    } catch (e) {
      _message('No se pudo consumir esa cantidad. $e');
    }
  }

  Future<void> _deleteLot(Map<String, dynamic> lot) async {
    final id = (lot['id'] as num).toInt();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar lote'),
        content: const Text('El lote dejará de formar parte del stock. La compra original se conservará en el historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar lote')),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifId = lot['notification_id'];
    if (notifId is num) await NotificationService.instance.cancel(notifId.toInt());
    await _db.deleteLot(id);
    await _reload();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (product == null) return Scaffold(appBar: AppBar(title: const Text('Artículo')), body: const Center(child: Text('No se encontró el artículo.')));
    final status = estadoProducto(product);
    final stock = (product['stock_total'] as num).toDouble();
    final unit = product['unit']?.toString() ?? 'pieza';
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 180,
          title: Text(product['name'].toString()),
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.only(top: 80, bottom: 14),
              child: Center(child: imagenProducto(product['image_path']?.toString(), size: 100)),
            ),
          ),
          actions: [
            IconButton(tooltip: 'Editar artículo', onPressed: () => Navigator.pushNamed(context, '/product-form', arguments: product).then((_) => _reload()), icon: const Icon(Icons.edit_outlined)),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(product['category_name'].toString(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.green.shade800)),
              const SizedBox(height: 4),
              Text(product['name'].toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if ((product['brand']?.toString() ?? '').isNotEmpty) Text(product['brand'].toString()),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(avatar: const Icon(Icons.inventory_2_outlined), label: Text('Stock: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit')),
                Chip(avatar: Icon(iconoEstado(status), color: colorEstado(status)), label: Text(status), side: BorderSide(color: colorEstado(status))),
                Chip(avatar: const Icon(Icons.notifications_active_outlined), label: Text('${product['expiry_alert_days']} días de anticipación')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => _addLot(), icon: const Icon(Icons.add_box_outlined), label: const Text('Registrar lote'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: _consume, icon: const Icon(Icons.remove_circle_outline), label: const Text('Consumir'))),
              ]),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('Lotes almacenados', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        ),
        if (_lots.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay lotes. Registra uno para que el artículo tenga existencias.')))
        else
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final lot = _lots[index];
            final expired = diasHasta(lot['expiration_date']) < 0 && (lot['quantity_current'] as num).toDouble() > 0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: expired ? Colors.red.shade100 : Colors.green.shade100, child: Icon(expired ? Icons.warning_amber : Icons.inventory_2_outlined, color: expired ? Colors.red.shade800 : Colors.green.shade800)),
                title: Text('Lote #${lot['id']} · ${((lot['quantity_current'] as num).toDouble()).toStringAsFixed(2)} $unit'),
                subtitle: Text('Caduca: ${fechaTexto(lot['expiration_date'])}\nCompra: ${fechaTexto(lot['purchase_date'])} · ${lot['store_name']}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? _addLot(lot: lot) : _deleteLot(lot),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar lote')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar lote')),
                  ],
                ),
              ),
            );
          }, childCount: _lots.length)),
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Text('Tiendas donde se ha comprado', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        ),
        if (_stores.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16), child: Text('Aún no hay compras registradas para este producto.')))
        else
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final store = _stores[index];
            return ListTile(leading: const Icon(Icons.storefront_outlined), title: Text(store['name'].toString()), subtitle: Text('Última compra: ${fechaTexto(store['last_purchase'])}'));
          }, childCount: _stores.length)),
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Text('Historial de compras', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        ),
        if (_purchaseHistory.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 28), child: Text('Sin compras registradas.')))
        else
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final purchase = _purchaseHistory[index];
            final total = ((purchase['quantity'] as num).toDouble()) * ((purchase['unit_cost'] as num).toDouble());
            return ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('${(purchase['quantity'] as num).toString()} $unit · ${monedaFormato.format(total)}'),
              subtitle: Text('${purchase['store_name']} · ${fechaTexto(purchase['purchased_at'])}'),
            );
          }, childCount: _purchaseHistory.length)),
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ]),
    );
  }
}
