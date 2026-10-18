import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

import '../components/app_utils.dart';
import '../components/product_card.dart';
import '../database/inventory_db.dart';
import '../services/notification_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryDB _db = InventoryDB.instance;
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  int _cartCount = 0;
  bool _loading = true;
  String _filter = 'Alertas';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final results = await Future.wait([_db.getInventory(), _db.getCartCount()]);
      if (!mounted) return;
      setState(() {
        _products = (results[0] as List<Map<String, dynamic>>);
        _cartCount = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('No se pudo cargar el inventario: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _search.text.trim().toLowerCase();
    return _products.where((product) {
      final status = estadoProducto(product);
      final matchesFilter = switch (_filter) {
        'Todos' => true,
        'Alertas' => esAlerta(status),
        _ => status == _filter,
      };
      final text = '${product['name']} ${product['brand']} ${product['category_name']}'.toLowerCase();
      return matchesFilter && text.contains(query);
    }).toList();
  }

  Future<void> _openProduct(Map<String, dynamic> product) async {
    await Navigator.pushNamed(context, '/product-detail', arguments: product['id']);
    _reload();
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    await Navigator.pushNamed(context, '/product-form', arguments: product);
    _reload();
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    await _db.addToCart((product['id'] as num).toInt());
    await _reload();
    _message('${product['name']} agregado a la lista de compra.');
  }

  Future<void> _consume(Map<String, dynamic> product) async {
    final controller = TextEditingController(text: '1');
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Consumir ${product['name']}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Cantidad (${product['unit']})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Consumir'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null) return;
    try {
      await _db.consumeFefo((product['id'] as num).toInt(), quantity);
      await _reload();
      _message('Consumo registrado aplicando FEFO.');
    } catch (e) {
      _message('No se pudo registrar el consumo. $e');
    }
  }

  Future<void> _archive(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archivar artículo'),
        content: Text('¿Deseas ocultar "${product['name']}" del inventario activo? Se conservará su historial de compras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Archivar')),
        ],
      ),
    );
    if (confirmed == true) {
      final productId = (product['id'] as num).toInt();
      final lots = await _db.getLots(productId);
      // Las alarmas de productos archivados no deben seguir apareciendo.
      for (final lot in lots) {
        final notificationId = lot['notification_id'];
        if (notificationId is num) {
          await NotificationService.instance.cancel(notificationId.toInt());
        }
      }
      await _db.archiveProduct(productId);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final alertCount = _products.where((p) => esAlerta(estadoProducto(p))).length;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              title: const Text('Mi Alacena'),
              actions: [
                IconButton(
                  tooltip: 'Calendario de alertas',
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/calendar');
                    _reload();
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                IconButton(
                  tooltip: 'Catálogos',
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/catalogs');
                    _reload();
                  },
                  icon: const Icon(Icons.tune_outlined),
                ),
                IconButton(
                  tooltip: 'Estadísticas',
                  onPressed: () => Navigator.pushNamed(context, '/stats'),
                  icon: const Icon(Icons.bar_chart_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: badges.Badge(
                    showBadge: _cartCount > 0,
                    position: badges.BadgePosition.topEnd(top: 2, end: 2),
                    badgeContent: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    child: IconButton(
                      tooltip: 'Lista de compra',
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/cart');
                        _reload();
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(colors: [Colors.green.shade900, Colors.green.shade600]),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tu alacena, bajo control', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('$alertCount artículo(s) requieren atención', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                        onPressed: () => Navigator.pushNamed(context, '/calendar'),
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('Ver calendario'),
                      ),
                    ])),
                    const SizedBox(width: 8),
                    const Icon(Icons.kitchen_outlined, color: Colors.white, size: 56),
                  ]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por producto, marca o categoría',
                    suffixIcon: _search.text.isEmpty ? null : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () { _search.clear(); setState(() {}); },
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  for (final filter in ['Alertas', 'Todos', 'Caducado', 'Sin existencia', 'Por caducar', 'Por agotarse', 'Disponible'])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(filter), selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Expanded(child: Text(_filter == 'Alertas' ? 'Requieren atención' : 'Artículos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                  Text('${filtered.length}', style: Theme.of(context).textTheme.titleMedium),
                ]),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade500),
                    const SizedBox(height: 12),
                    Text(_products.isEmpty ? 'Todavía no hay artículos' : 'No hay artículos para este filtro', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text('Registra un artículo y después agrega uno o varios lotes.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: () => Navigator.pushNamed(context, '/product-form').then((_) => _reload()), icon: const Icon(Icons.add), label: const Text('Agregar artículo')),
                  ]),
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 6, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = filtered[index];
                      return ProductCard(
                        product: product,
                        onTap: () => _openProduct(product),
                        onAddToCart: () => _addToCart(product),
                        onEdit: () => _editProduct(product),
                        onConsume: () => _consume(product),
                        onArchive: () => _archive(product),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/product-form').then((_) => _reload()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo artículo'),
      ),
    );
  }
}
