import 'package:flutter/material.dart';

import '../components/app_utils.dart';
import '../database/inventory_db.dart';
import '../services/notification_service.dart';

class LotFormScreen extends StatefulWidget {
  const LotFormScreen({super.key});

  @override
  State<LotFormScreen> createState() => _LotFormScreenState();
}

class _LotFormScreenState extends State<LotFormScreen> {
  final InventoryDB _db = InventoryDB.instance;
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _unitCost = TextEditingController(text: '0');

  int? _productId;
  String _productName = 'Artículo';
  int? _lotId;
  int? _storeId;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  DateTime _purchaseDate = DateTime.now();
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  bool _saving = false;
  bool _argsLoaded = false;
  Map<String, dynamic>? _originalLot;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) {
      _productId = (arg['productId'] as num?)?.toInt();
      _productName = arg['productName']?.toString() ?? 'Artículo';
      final lotRaw = arg['lot'];
      if (lotRaw is Map) {
        _originalLot = Map<String, dynamic>.from(lotRaw);
        _lotId = (_originalLot!['id'] as num).toInt();
        _quantity.text = ((_originalLot!['quantity_current'] as num).toDouble()).toString();
        _unitCost.text = ((_originalLot!['unit_cost'] as num).toDouble()).toString();
        _expiryDate = DateTime.parse(_originalLot!['expiration_date'].toString());
        _purchaseDate = DateTime.parse(_originalLot!['purchase_date'].toString());
        _storeId = (_originalLot!['store_id'] as num).toInt();
      }
    }
  }

  Future<void> _loadStores() async {
    final stores = await _db.getStores();
    if (!mounted) return;
    setState(() { _stores = stores; _loading = false; });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    super.dispose();
  }

  Future<DateTime?> _chooseDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
        locale: const Locale('es', 'MX'),
      );

  String? _validQuantity(String? value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null || number < 0) return 'Introduce una cantidad válida, igual o mayor que cero.';
    if (_lotId == null && number <= 0) return 'Una compra nueva debe tener cantidad mayor que cero.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null || _storeId == null || !_stores.any((s) => s['id'] == _storeId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una tienda y un artículo válidos.')));
      return;
    }
    final cost = double.tryParse(_unitCost.text.replaceAll(',', '.'));
    final quantity = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (cost == null || cost < 0 || quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el costo y la cantidad.')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_lotId != null) await NotificationService.instance.cancel(_lotId!);
      final savedId = await _db.saveLot(
        lotId: _lotId,
        productId: _productId!,
        quantity: quantity,
        expiryDate: fechaIso(_expiryDate),
        purchaseDate: fechaIso(_purchaseDate),
        storeId: _storeId!,
        unitCost: cost,
      );
      final scheduled = quantity > 0 && await NotificationService.instance.scheduleExpiry(
        lotId: savedId,
        productName: _productName,
        expirationDate: _expiryDate,
      );
      if (quantity <= 0) await NotificationService.instance.cancel(savedId);
      await _db.setLotNotification(savedId, notificationId: savedId, scheduled: scheduled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_lotId == null
            ? (scheduled ? 'Lote y compra guardados; se programó la alarma local.' : 'Lote y compra guardados. La fecha ya pasó, no se programó una alarma futura.')
            : 'Lote actualizado y alarma revisada.'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el lote. Comprueba la tienda, cantidad y fechas. $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _lotId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar lote' : 'Registrar compra / lote')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.store_mall_directory_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text('Primero registra una tienda.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () async { await Navigator.pushNamed(context, '/catalogs'); await _loadStores(); }, child: const Text('Abrir tiendas')),
                  ]),
                ))
              : Form(
                  key: _formKey,
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(_productName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(editing ? 'Ajusta las existencias o la caducidad. La compra original permanecerá en el historial.' : 'Cada lote conserva su propia caducidad y tienda de compra.'),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _quantity,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Cantidad *', prefixIcon: Icon(Icons.numbers)),
                            validator: _validQuantity,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _unitCost,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Costo por unidad (MXN) *', prefixIcon: Icon(Icons.attach_money)),
                            validator: (value) {
                              final number = double.tryParse((value ?? '').replaceAll(',', '.'));
                              return number == null || number < 0 ? 'Introduce un costo válido.' : null;
                            },
                          ),
                          const SizedBox(height: 14),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade400)),
                            leading: const Icon(Icons.event_available_outlined),
                            title: const Text('Fecha de caducidad'),
                            subtitle: Text(fechaTexto(fechaIso(_expiryDate))),
                            trailing: const Icon(Icons.edit_calendar_outlined),
                            onTap: () async { final d = await _chooseDate(_expiryDate); if (d != null) setState(() => _expiryDate = d); },
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade400)),
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: const Text('Fecha de compra'),
                            subtitle: Text(fechaTexto(fechaIso(_purchaseDate))),
                            trailing: editing ? const Icon(Icons.lock_outline) : const Icon(Icons.edit_calendar_outlined),
                            onTap: editing ? null : () async { final d = await _chooseDate(_purchaseDate); if (d != null) setState(() => _purchaseDate = d); },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: _storeId,
                            decoration: InputDecoration(labelText: editing ? 'Tienda de la compra (no modificable)' : 'Tienda donde se compró *', prefixIcon: const Icon(Icons.storefront_outlined)),
                            items: _stores.map((store) => DropdownMenuItem<int>(value: (store['id'] as num).toInt(), child: Text(store['name'].toString()))).toList(),
                            onChanged: editing ? null : (value) => setState(() => _storeId = value),
                            validator: (value) => value == null ? 'Selecciona una tienda.' : null,
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Guardando...' : 'Guardar lote'),
                          ),
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ]),
                ),
    );
  }
}
