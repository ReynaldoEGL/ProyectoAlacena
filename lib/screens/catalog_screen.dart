import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

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
        body: const TabBarView(children: [
          CatalogManager(isStore: false),
          CatalogManager(isStore: true),
        ]),
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
  String? _error;

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
    try {
      final items = widget.isStore ? await _db.getStores() : await _db.getCategories();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo consultar el catálogo: $e';
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CatalogEditDialog(
        isStore: widget.isStore,
        item: item,
        onSave: (name, address, phone) async {
          final id = (item?['id'] as num?)?.toInt();
          if (widget.isStore) {
            final changed = await _db.saveStore(
              id: id, name: name, address: address, phone: phone,
            );
            if (id != null && changed == 0) {
              throw StateError('La tienda ya no existe.');
            }
          } else {
            final changed = await _db.saveCategory(
              id: id,
              name: name,
              icon: item?['icon']?.toString() ?? 'category',
            );
            if (id != null && changed == 0) {
              throw StateError('La categoría ya no existe.');
            }
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    await _reload();
    _message(widget.isStore ? 'Tienda guardada.' : 'Categoría guardada.');
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
    if (!mounted || confirmed != true) return;
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
          ? 'No puede eliminarse: existen lotes o compras asociados a esta tienda.'
          : 'No puede eliminarse: existen productos asociados a esta categoría.');
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
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                )),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Todavía no hay registros.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _items[index];
                    final address = item['address']?.toString() ?? '';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(
                            widget.isStore ? Icons.storefront_outlined : Icons.category_outlined)),
                        title: Text(item['name'].toString()),
                        subtitle: widget.isStore && address.isNotEmpty ? Text(address) : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => value == 'edit'
                              ? _edit(item: item)
                              : _delete(item),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ),
                    );
                  }, childCount: _items.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(widget.isStore ? 'Nueva tienda' : 'Nueva categoría'),
      ),
    );
  }
}

// El diálogo es dueño de los TextEditingController: se liberan cuando la ruta
// termina su animación de salida, no inmediatamente después de Navigator.pop.
class _CatalogEditDialog extends StatefulWidget {
  const _CatalogEditDialog({
    required this.isStore,
    required this.item,
    required this.onSave,
  });

  final bool isStore;
  final Map<String, dynamic>? item;
  final Future<void> Function(String name, String address, String phone) onSave;

  @override
  State<_CatalogEditDialog> createState() => _CatalogEditDialogState();
}

class _CatalogEditDialogState extends State<_CatalogEditDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?['name']?.toString() ?? '');
    _address = TextEditingController(text: widget.item?['address']?.toString() ?? '');
    _phone = TextEditingController(text: widget.item?['phone']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text, _address.text, _phone.text);
      if (mounted) Navigator.of(context).pop(true);
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isUniqueConstraintError()
          ? 'Ya existe un registro con ese nombre.'
          : 'No fue posible guardar el registro.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No fue posible guardar el registro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text('${editing ? 'Editar' : 'Agregar'} ${widget.isStore ? 'tienda' : 'categoría'}'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _name,
                  autofocus: false,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: widget.isStore
                      ? 'Nombre de la tienda *' : 'Nombre de la categoría *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe un nombre.' : null,
                ),
                if (widget.isStore) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
