import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/inventory_db.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final InventoryDB _db = InventoryDB.instance;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _minStock = TextEditingController(text: '1');
  final _expiryDays = TextEditingController(text: '5');
  final _unit = TextEditingController(text: 'pieza');
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  int? _productId;
  String _imagePath = '';
  bool _saving = false;
  bool _argumentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLoaded) return;
    _argumentsLoaded = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is Map) {
      final product = Map<String, dynamic>.from(argument);
      _productId = (product['id'] as num?)?.toInt();
      _name.text = product['name']?.toString() ?? '';
      _brand.text = product['brand']?.toString() ?? '';
      _minStock.text = ((product['min_stock'] as num?) ?? 1).toString();
      _expiryDays.text = ((product['expiry_alert_days'] as num?) ?? 5).toString();
      _unit.text = product['unit']?.toString() ?? 'pieza';
      _categoryId = (product['category_id'] as num?)?.toInt();
      _imagePath = product['image_path']?.toString() ?? '';
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _db.getCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _minStock.dispose();
    _expiryDays.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1400);
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory(p.join(directory.path, 'product_images'));
      if (!await imageDir.exists()) await imageDir.create(recursive: true);
      final filename = 'producto_${DateTime.now().microsecondsSinceEpoch}${p.extension(picked.path)}';
      final saved = await File(picked.path).copy(p.join(imageDir.path, filename));
      if (!mounted) return;
      setState(() => _imagePath = saved.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cargar la imagen: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || !_categories.any((c) => c['id'] == _categoryId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una categoría válida.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.saveProduct({
        'name': _name.text,
        'brand': _brand.text,
        'category_id': _categoryId,
        'unit': _unit.text.trim().isEmpty ? 'pieza' : _unit.text.trim(),
        'min_stock': double.parse(_minStock.text.replaceAll(',', '.')),
        'expiry_alert_days': int.parse(_expiryDays.text),
        'image_path': _imagePath,
      }, id: _productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_productId == null ? 'Artículo guardado. Ahora registra al menos un lote para controlar existencias.' : 'Artículo actualizado.'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el artículo. Revisa si el nombre ya existe o si la categoría sigue disponible. $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredText(String? value) => value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

  String? _validNonNegative(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 'Introduce un número igual o mayor que cero.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final editing = _productId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar artículo' : 'Nuevo artículo')),
      body: _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(
                        child: Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 145, height: 145, color: Colors.green.shade50,
                              child: _imagePath.isNotEmpty && File(_imagePath).existsSync()
                                  ? Image.file(File(_imagePath), fit: BoxFit.cover)
                                  : Icon(Icons.add_a_photo_outlined, size: 52, color: Colors.green.shade800),
                            ),
                          ),
                          Positioned(right: 0, bottom: 0, child: IconButton.filled(
                            onPressed: _pickImage, icon: const Icon(Icons.photo_camera_outlined), tooltip: 'Elegir imagen',
                          )),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre del artículo *', prefixIcon: Icon(Icons.shopping_basket_outlined)), validator: _requiredText, textCapitalization: TextCapitalization.sentences),
                      const SizedBox(height: 14),
                      TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Marca (opcional)', prefixIcon: Icon(Icons.sell_outlined))),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Categoría *', prefixIcon: Icon(Icons.category_outlined)),
                        items: _categories.map((category) => DropdownMenuItem<int>(
                          value: (category['id'] as num).toInt(), child: Text(category['name'].toString()),
                        )).toList(),
                        onChanged: (value) => setState(() => _categoryId = value),
                        validator: (value) => value == null ? 'Selecciona una categoría.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unidad (pieza, kg, L, paquete...)', prefixIcon: Icon(Icons.straighten)), validator: _requiredText),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _minStock,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Stock mínimo para alerta *', prefixIcon: Icon(Icons.inventory_2_outlined)),
                        validator: _validNonNegative,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _expiryDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Avisar cuántos días antes de caducar *', prefixIcon: Icon(Icons.notifications_active_outlined)),
                        validator: (value) {
                          final days = int.tryParse(value ?? '');
                          if (days == null || days < 0 || days > 365) return 'Introduce un entero entre 0 y 365.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Guardando...' : 'Guardar artículo'),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}
