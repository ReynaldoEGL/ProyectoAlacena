import 'package:flutter/material.dart';

import '../database/inventory_db.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogos'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.category_outlined), text: 'Categorías'),
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Tiendas'),
          ]),
        ),
        body: const TabBarView(children: [CatalogManager(isStore: false), CatalogManager(isStore: true)]),
      ),
    );
  }
}

class CatalogManager extends StatefulWidget {
  const CatalogManager({super.key, required this.isStore});
  final bool isStore;

  @override
  State<CatalogManager> createState() => _CatalogManagerState();
}

class _CatalogManagerState extends State<CatalogManager> {
  final InventoryDB _db = InventoryDB.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CatalogManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStore != widget.isStore) _reload();
  }

  Future<void> _reload() async {
    final items = widget.isStore ? await _db.getStores() : await _db.getCategories();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final address = TextEditingController(text: item?['address']?.toString() ?? '');
    final phone = TextEditingController(text: item?['phone']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item == null ? 'Agregar' : 'Editar'} ${widget.isStore ? 'tienda' : 'categoría'}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, autofocus: false, textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.isStore ? 'Nombre de la tienda *' : 'Nombre de la categoría *'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Escribe un nombre.' : null),
            if (widget.isStore) ...[
              const SizedBox(height: 12),
              TextFormField(controller: address, decoration: const InputDecoration(labelText: 'Dirección (opcional)')),
              const SizedBox(height: 12),
              TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
            ],
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }
            FocusScope.of(ctx).unfocus();

            Navigator.of(ctx).pop(true);
          }, child: const Text('Guardar')),
        ],
      ),
    );
    if (result == true) {
      try {
        if (widget.isStore) {
          await _db.saveStore(id: (item?['id'] as num?)?.toInt(), name: name.text, address: address.text, phone: phone.text);
        } else {
          await _db.saveCategory(id: (item?['id'] as num?)?.toInt(), name: name.text);
        }
        await _reload();
        _message('Registro guardado.');
      } catch (e) {
        _message('No se pudo guardar. $e');
      }
    }
    name.dispose();
    address.dispose();
    phone.dispose();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar "${item['name']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (widget.isStore) {
        await _db.deleteStore((item['id'] as num).toInt());
      } else {
        await _db.deleteCategory((item['id'] as num).toInt());
      }
      await _reload();
      _message('Registro eliminado.');
    } catch (_) {
      _message(widget.isStore
          ? 'No puede eliminarse: hay lotes o compras que dependen de esta tienda. Conserva el registro para mantener la trazabilidad.'
          : 'No puede eliminarse: hay productos que pertenecen a esta categoría. Edita esos productos primero.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Todavía no hay registros.'))
                : CustomScrollView(slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                      sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                        final item = _items[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(widget.isStore ? Icons.storefront_outlined : Icons.category_outlined)),
                            title: Text(item['name'].toString()),
                            subtitle: widget.isStore && (item['address']?.toString() ?? '').isNotEmpty ? Text(item['address'].toString()) : null,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => value == 'edit' ? _edit(item: item) : _delete(item),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                              ],
                            ),
                          ),
                        );
                      }, childCount: _items.length)),
                    ),
                  ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(widget.isStore ? 'Nueva tienda' : 'Nueva categoría'),
      ),
    );
  }
}
